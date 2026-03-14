CREATE OR REPLACE FUNCTION sp_reporte_ventas_by_sede(
    p_id_local INT, 
    p_fecha_busqueda TEXT
)
RETURNS TABLE(resultado JSONB) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH base_vista AS (
        -- 1. Montos oficiales desde la vista
        SELECT 
            dsturno as nombre_turno,
            SUM(monto)::numeric(10,2) as monto_total_turno
        FROM vw_mat_reporte_ventas
        WHERE fecha_proceso = p_fecha_busqueda 
          AND idlocal = p_id_local
        GROUP BY dsturno
    ),
    base_ventas_detallada AS (
        -- 2. Conceptos de la tabla sale (usamos el idlocal mapeado desde la tabla local)
        SELECT 
            ws.shift_name as nombre_turno,
            s.total_amount,
            s.id_sale_operation_type,
            s.transferencia_gratuita,
            s.total_discount,
            s.outstanding_balance,
            s.applied_advance_amount,
            pm.name as metodo_pago
        FROM sale s
        JOIN local l ON s.id_local = l.id_local
        JOIN cash_register cr ON s.id_cash_register = cr.id_cash_register
        JOIN work_shift ws ON cr.id_work_shift = ws.id_work_shift
        LEFT JOIN payment p ON s.id_sale = p.id_sale
        LEFT JOIN payment_method pm ON p.id_payment_method = pm.id_payment_method
        WHERE s.state = 40001 
          AND l.local_number = p_id_local -- Filtramos por el número de local (idlocal de la vista)
          AND (
            CASE
                WHEN ws.shift_name = 'MAÑANA' THEN to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
                WHEN ws.shift_name <> 'MAÑANA' AND EXTRACT(HOUR FROM (cr.opennig_date AT TIME ZONE 'America/Lima')) < 
                    (SELECT EXTRACT(HOUR FROM start_time) FROM work_shift WHERE shift_name = 'MAÑANA' LIMIT 1)
                THEN to_char((cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day', 'DD/MM/YYYY')
                ELSE to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
            END = p_fecha_busqueda
          )
    ),
    metricas_agrupadas AS (
        -- 3. Consolidación de métricas con ROLLUP
        SELECT
            COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo,
            SUM(DISTINCT v.monto_total_turno) as bruto_vista,
            SUM(CASE WHEN id_sale_operation_type = 4 THEN total_amount ELSE 0 END)::numeric(10,2) AS serafin,
            SUM(CASE WHEN id_sale_operation_type = 3 THEN total_amount ELSE 0 END)::numeric(10,2) AS consumo,
            SUM(transferencia_gratuita)::numeric(10,2) AS gratuita,
            SUM(total_discount)::numeric(10,2) AS descuentos,
            SUM(outstanding_balance)::numeric(10,2) AS credito,
            SUM(applied_advance_amount)::numeric(10,2) AS adelanto
        FROM base_ventas_detallada bv
        LEFT JOIN base_vista v ON bv.nombre_turno = v.nombre_turno
        GROUP BY ROLLUP(bv.nombre_turno)
    ),
    metodos_pago_final AS (
        -- 4. Métodos de pago agrupados
        SELECT 
            grupo,
            jsonb_agg(jsonb_build_object('metodo', metodo_nombre, 'monto', TO_CHAR(monto_pago, 'FM999999990.00'))) as pagos
        FROM (
            SELECT 
                COALESCE(nombre_turno, 'TOTAL GENERAL') as grupo,
                metodo_pago as metodo_nombre, 
                SUM(total_amount)::numeric(10,2) as monto_pago 
            FROM base_ventas_detallada 
            WHERE id_sale_operation_type NOT IN (3,4) AND transferencia_gratuita = 0
            GROUP BY ROLLUP(nombre_turno), metodo_pago
        ) t
        WHERE metodo_nombre IS NOT NULL
        GROUP BY grupo
    )
    -- 5. Construcción final
    SELECT jsonb_pretty(jsonb_agg(reporte_bloque ORDER BY (grupo <> 'TOTAL GENERAL'), grupo))::jsonb
    FROM (
        SELECT 
            m.grupo,
            jsonb_build_object(
                'nombre_bloque', m.grupo,
                'secciones', jsonb_build_array(
                    jsonb_build_object('titulo', 'VENTA GENERAL', 'total', TO_CHAR(m.bruto_vista, 'FM999999990.00')),
                    jsonb_build_object(
                        'titulo', 'VENTA BRUTA',
                        'total', TO_CHAR(m.bruto_vista, 'FM999999990.00'),
                        'detalle', jsonb_build_array(
                            jsonb_build_object('concepto', 'SERAFIN', 'monto', TO_CHAR(m.serafin, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'CONSUMO_INTERNO', 'monto', TO_CHAR(m.consumo, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'TRANSFERENCIA_GRATUITA', 'monto', TO_CHAR(m.gratuita, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'DESCUENTOS', 'monto', TO_CHAR(m.descuentos, 'FM999999990.00'))
                        )
                    ),
                    jsonb_build_object(
                        'titulo', 'VENTA NETA',
                        'total', TO_CHAR(m.bruto_vista - (m.serafin + m.consumo + m.gratuita + m.descuentos), 'FM999999990.00'),
                        'detalle', jsonb_build_array(
                            jsonb_build_object('concepto', 'VENTA_A_CREDITO_PENDIENTE', 'monto', TO_CHAR(m.credito, 'FM999999990.00')),
                            jsonb_build_object('concepto', 'PAGO_ADELANTADO_APLICADO', 'monto', TO_CHAR(m.adelanto, 'FM999999990.00'))
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
    ) sub;
END;
$$;



