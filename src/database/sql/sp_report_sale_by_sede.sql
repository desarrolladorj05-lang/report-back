CREATE OR REPLACE FUNCTION sp_reporte_ventas_by_sede(
    p_id_local INT, 
    p_fecha_busqueda TEXT 
)
RETURNS TABLE(resultado JSONB) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_local_uuid UUID;
    v_fecha_ayer TEXT;
BEGIN
    SELECT id_local INTO v_id_local_uuid FROM local WHERE local_number = p_id_local LIMIT 1;
    
    -- Calcular fecha de ayer para la variación
    v_fecha_ayer := to_char(to_date(p_fecha_busqueda, 'DD/MM/YYYY') - interval '1 day', 'DD/MM/YYYY');

    RETURN QUERY
    WITH base_ventas_unificadas AS (
        SELECT 
            ws.shift_name as nombre_turno,
            s.id_sale,
            s.total_amount,
            s.id_sale_operation_type,
            s.transferencia_gratuita,
            s.total_discount,
            s.outstanding_balance,
            s.applied_advance_amount,
            l.name as local_nombre_real
        FROM sale s
        JOIN local l ON s.id_local = l.id_local
        JOIN cash_register cr ON s.id_cash_register = cr.id_cash_register
        JOIN work_shift ws ON cr.id_work_shift = ws.id_work_shift
        WHERE s.state = 40001 
          AND l.id_local = v_id_local_uuid
          AND (
            CASE
                WHEN ws.shift_name = 'MAÑANA' THEN to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
                WHEN ws.shift_name <> 'MAÑANA' AND EXTRACT(HOUR FROM (cr.opennig_date AT TIME ZONE 'America/Lima')) < 6
                THEN to_char((cr.opennig_date AT TIME ZONE 'America/Lima' - interval '1 day'), 'DD/MM/YYYY')
                ELSE to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
            END = p_fecha_busqueda
          )
    ),
    ventas_ayer AS (
        -- Obtenemos el total de ayer para comparar variaciones
        SELECT 
            dsturno as nombre_turno,
            SUM(monto)::numeric(10,2) as monto_ayer
        FROM vw_mat_reporte_ventas
        WHERE fecha_proceso = v_fecha_ayer 
          AND idlocal = p_id_local
        GROUP BY dsturno
    ),
    base_vista AS (
        SELECT 
            dsturno as nombre_turno,
            SUM(monto)::numeric(10,2) as monto_total_turno
        FROM vw_mat_reporte_ventas
        WHERE fecha_proceso = p_fecha_busqueda 
          AND idlocal = p_id_local
        GROUP BY dsturno
    ),
    metricas_agrupadas AS (
        SELECT
            COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo,
            COALESCE(SUM(DISTINCT v.monto_total_turno), 0) as bruto_vista,
            COUNT(DISTINCT bv.id_sale) as total_ventas_count,
            -- Cálculo de variación vs Ayer
            COALESCE(SUM(DISTINCT va.monto_ayer), 0) as total_ayer,
            SUM(CASE WHEN id_sale_operation_type = 4 THEN total_amount ELSE 0 END)::numeric(10,2) AS serafin,
            SUM(CASE WHEN id_sale_operation_type = 3 THEN total_amount ELSE 0 END)::numeric(10,2) AS consumo,
            SUM(transferencia_gratuita)::numeric(10,2) AS gratuita,
            SUM(total_discount)::numeric(10,2) AS descuentos,
            SUM(outstanding_balance)::numeric(10,2) AS credito,
            SUM(applied_advance_amount)::numeric(10,2) AS adelanto
        FROM base_ventas_unificadas bv
        LEFT JOIN base_vista v ON bv.nombre_turno = v.nombre_turno
        LEFT JOIN ventas_ayer va ON bv.nombre_turno = va.nombre_turno
        GROUP BY ROLLUP(bv.nombre_turno)
    ),
    metodos_pago_final AS (
        SELECT 
            t.grupo,
            jsonb_agg(jsonb_build_object('metodo', t.metodo_nombre, 'monto', TO_CHAR(t.monto_neto_pago, 'FM999999990.00'))) as pagos
        FROM (
            SELECT 
                COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo,
                pm.name as metodo_nombre, 
                SUM(p.amount - bv.total_discount)::numeric(10,2) as monto_neto_pago 
            FROM base_ventas_unificadas bv
            INNER JOIN payment p ON bv.id_sale = p.id_sale
            INNER JOIN payment_method pm ON p.id_payment_method = pm.id_payment_method
            WHERE bv.id_sale_operation_type NOT IN (3,4) 
              AND bv.transferencia_gratuita = 0
              AND p.id_payment_method IN (1, 2, 6)
              AND p.state = 40001
            GROUP BY ROLLUP(bv.nombre_turno), pm.name
        ) t
        WHERE t.metodo_nombre IS NOT NULL
        GROUP BY t.grupo
    )
    SELECT jsonb_build_object(
        'nombre_sede', COALESCE((SELECT MAX(local_nombre_real) FROM base_ventas_unificadas), 'SEDE NO ENCONTRADA'),
        'reporte', jsonb_agg(reporte_bloque ORDER BY (grupo <> 'TOTAL GENERAL'), grupo)
    )
    FROM (
        SELECT 
            m.grupo,
            jsonb_build_object(
                'nombre_bloque', m.grupo,
                -- Agregamos variación y promedio en la cabecera del bloque
                'total_operaciones', m.total_ventas_count,
                'ticket_promedio', TO_CHAR(CASE WHEN m.total_ventas_count > 0 THEN m.bruto_vista / m.total_ventas_count ELSE 0 END, 'FM999999990.00'),
                'variacion_vs_ayer', TO_CHAR(CASE WHEN m.total_ayer > 0 THEN ((m.bruto_vista - m.total_ayer) / m.total_ayer) * 100 ELSE 0 END, 'FM999999990.00'),
                'secciones', jsonb_build_array(
                    jsonb_build_object('titulo', 'VENTA GENERAL', 'total', TO_CHAR(m.bruto_vista, 'FM999999990.00')),
                    jsonb_build_object(
                        'titulo', 'VENTA BRUTA',
                        'total', TO_CHAR(m.bruto_vista, 'FM999999990.00'),
                        'detalle', jsonb_build_array(
                            jsonb_build_object('concepto', 'Serafin', 'monto', TO_CHAR(m.serafin, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'Consumo Interno', 'monto', TO_CHAR(m.consumo, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'Transferencia Gratuita', 'monto', TO_CHAR(m.gratuita, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'Descuentos', 'monto', TO_CHAR(m.descuentos, 'FM999999990.00'))
                        )
                    ),
                    jsonb_build_object(
                        'titulo', 'VENTA NETA',
                        'total', TO_CHAR(m.bruto_vista - (m.serafin + m.consumo + m.gratuita + m.descuentos), 'FM999999990.00'),
                        'detalle', jsonb_build_array(
                            jsonb_build_object('concepto', 'Ventas a Credito', 'monto', TO_CHAR(m.credito, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'Pago Adelantado', 'monto', TO_CHAR(m.adelanto, 'FM999999990.00'))
                        )
                    ),
                    jsonb_build_object(
                        'titulo', 'VENTA CONTADA',
                        'total', TO_CHAR((m.bruto_vista - (m.serafin + m.consumo + m.gratuita + m.descuentos)) - m.credito + m.adelanto, 'FM999999990.00'),
                        'detalle', COALESCE(mp.pagos, '[]'::jsonb)
                    )
                )
            ) as reporte_bloque
        FROM metricas_agrupadas m
        LEFT JOIN metodos_pago_final mp ON m.grupo = mp.grupo
        WHERE m.grupo IS NOT NULL
    ) sub;
END;
$$;