CREATE
OR REPLACE FUNCTION public.sp_reporte_ventas_by_sede (p_id_local integer, p_fecha_busqueda text) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_ayer TEXT;
BEGIN
    -- Calcular fecha de ayer
    v_fecha_ayer := to_char(to_date(p_fecha_busqueda, 'DD/MM/YYYY') - interval '1 day', 'DD/MM/YYYY');

    RETURN QUERY
    WITH base_ventas_unificadas AS (
        SELECT * FROM vw_reporte_ventas_base
        WHERE state = 40001 
          AND local_number = p_id_local
          AND fecha_negocio = p_fecha_busqueda
    ),
    ventas_ayer AS (
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
                vpd.metodo_nombre, 
                SUM(vpd.amount - bv.total_discount)::numeric(10,2) as monto_neto_pago 
            FROM base_ventas_unificadas bv
            INNER JOIN vw_reporte_pagos_detalle vpd ON bv.id_sale = vpd.id_sale
            WHERE bv.id_sale_operation_type NOT IN (3,4) 
              AND bv.transferencia_gratuita = 0
              AND vpd.id_payment_method IN (1, 2, 6)
              AND vpd.payment_state = 40001
            GROUP BY ROLLUP(bv.nombre_turno), vpd.metodo_nombre
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
$function$