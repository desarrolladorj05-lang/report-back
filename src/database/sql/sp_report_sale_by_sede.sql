CREATE
OR REPLACE FUNCTION public.sp_reporte_ventas_by_sede (p_id_local integer, p_fecha_busqueda text) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_ayer_text TEXT;
    v_fecha_ayer_date DATE;
    v_cash_registers UUID[];
BEGIN
    -- 1. IDENTIFICACIÓN DE FECHAS
    v_fecha_ayer_date := (to_date(p_fecha_busqueda, 'DD/MM/YYYY') - interval '1 day')::date;
    v_fecha_ayer_text := to_char(v_fecha_ayer_date, 'DD/MM/YYYY');

    -- 2. IDENTIFICACIÓN DE CAJAS
    SELECT array_agg(cr.id_cash_register) INTO v_cash_registers
    FROM public.cash_register cr
    JOIN public.local l ON cr.id_local = l.id_local 
    JOIN public.work_shift ws ON cr.id_work_shift = ws.id_work_shift
    LEFT JOIN public.work_shift ws_ref ON l.id_local = ws_ref.id_local AND ws_ref.shift_name = 'MAÑANA'
    WHERE (p_id_local IS NULL OR l.local_number = p_id_local)
    AND cr.state_audit = 1200001
    AND (
        CASE
            WHEN ws.shift_name = 'MAÑANA' THEN 
                to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
            WHEN (cr.opennig_date AT TIME ZONE 'America/Lima')::time < COALESCE(ws_ref.start_time, '07:30:00'::time) THEN 
                to_char((cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day', 'DD/MM/YYYY')
            ELSE 
                to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
        END
    ) = p_fecha_busqueda;

    RETURN QUERY
    WITH base_ventas_unificadas AS (
        SELECT * FROM vw_reporte_ventas_base
        WHERE state = 40001 
        AND (p_id_local IS NULL OR local_number = p_id_local)
        AND fecha_negocio = p_fecha_busqueda
    ),
    -- CALCULO DE AYER USANDO LA MISMA VISTA Y FORMULA
    ayer_data_calculada AS (
        SELECT 
            local_number,
            COALESCE(nombre_turno, 'TOTAL GENERAL') as grupo_ayer,
            (SUM(total_amount) - 
            SUM(CASE WHEN id_sale_operation_type IN (3,4,5,6) THEN total_amount ELSE 0 END)
            )::numeric(15,2) as monto_ayer
        FROM vw_reporte_ventas_base
        WHERE state = 40001 
        AND (p_id_local IS NULL OR local_number = p_id_local)
        AND fecha_negocio = v_fecha_ayer_text
        GROUP BY local_number, ROLLUP(nombre_turno)
    ),
    metricas_agrupadas AS (
        SELECT
            bv.local_number, bv.local_nombre_real,
            MAX(CASE 
                WHEN UPPER(TRIM(bv.nombre_turno)) = 'MAÑANA'   THEN 1
                WHEN UPPER(TRIM(bv.nombre_turno)) = 'TARDE'    THEN 2
                WHEN UPPER(TRIM(bv.nombre_turno)) = 'NOCHE'    THEN 3
                WHEN UPPER(TRIM(bv.nombre_turno)) = 'MADRUGADA' THEN 4
                ELSE NULL 
            END) AS id_work_shift,
            COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo,
            (SUM(total_amount) - 
            SUM(CASE WHEN id_sale_operation_type IN (3,4,5,6) THEN total_amount ELSE 0 END)
            )::numeric(15,2) as venta_neta_real,
            SUM(CASE WHEN id_sale_operation_type = 4 THEN total_amount ELSE 0 END)::numeric(10,2) AS serafin,
            SUM(total_amount + COALESCE(total_discount, 0) + COALESCE(transferencia_gratuita, 0))::numeric(10,2) as bruto_vista,
            COUNT(DISTINCT bv.id_sale) as total_ventas_count,
            SUM(CASE WHEN id_sale_operation_type = 3 THEN total_amount ELSE 0 END)::numeric(10,2) AS consumo,
            SUM(transferencia_gratuita)::numeric(10,2) AS gratuita,
            SUM(total_discount)::numeric(10,2) AS descuentos,
            (SUM(CASE WHEN id_sale_document_type IN (1,2) AND id_sale_operation_type = 2 THEN outstanding_balance ELSE 0 END) + 
            SUM(CASE WHEN id_sale_document_type = 3 AND id_sale_operation_type = 2 THEN total_amount ELSE 0 END))::numeric(10,2) AS credito,
            (SUM(CASE WHEN id_sale_document_type = 3 AND id_sale_operation_type = 7 THEN total_amount ELSE 0 END) + 
            SUM(applied_advance_amount))::numeric(10,2) AS adelanto,
            (SUM(total_amount) 
            - SUM(CASE WHEN id_sale_operation_type IN (3,4) THEN total_amount ELSE 0 END) 
            - (SUM(CASE WHEN id_sale_document_type IN (1,2) AND id_sale_operation_type = 2 THEN outstanding_balance ELSE 0 END) + 
                SUM(CASE WHEN id_sale_document_type = 3 AND id_sale_operation_type = 2 THEN total_amount ELSE 0 END))
            - (SUM(CASE WHEN id_sale_document_type = 3 AND id_sale_operation_type = 7 THEN total_amount ELSE 0 END))
            )::numeric(10,2) as venta_contada_esperada
        FROM base_ventas_unificadas bv
        GROUP BY bv.local_number, bv.local_nombre_real, ROLLUP(bv.nombre_turno)
    ),
    recaudacion_data AS (
        SELECT 
            l.local_number, ws.shift_name as nombre_turno,
            COALESCE(pm.name, gp.description, 'OTROS') as concepto,
            SUM(lg.total_collected)::numeric(10,2) as monto_recaudado
        FROM public.liquidation_group lg
        INNER JOIN public.liquidation lq ON lg.id_liquidation = lq.id_liquidation
        INNER JOIN public.cash_register cr ON lq.id_cash_register = cr.id_cash_register
        INNER JOIN public.local l ON cr.id_local = l.id_local
        INNER JOIN public.work_shift ws ON cr.id_work_shift = ws.id_work_shift
        LEFT JOIN public.payment_method pm ON lg.payment_method_id = pm.id_payment_method
        LEFT JOIN public.general_param gp ON lg.group_id = gp.table_id
        WHERE lq.id_cash_register = ANY(v_cash_registers) AND lg.state_audit = 1200001
        GROUP BY 1, 2, 3
        UNION ALL
        SELECT l.local_number, 'TOTAL GENERAL', COALESCE(pm.name, gp.description, 'OTROS'), SUM(lg.total_collected)
        FROM public.liquidation_group lg
        INNER JOIN public.liquidation lq ON lg.id_liquidation = lq.id_liquidation
        INNER JOIN public.cash_register cr ON lq.id_cash_register = cr.id_cash_register
        INNER JOIN public.local l ON cr.id_local = l.id_local
        LEFT JOIN public.payment_method pm ON lg.payment_method_id = pm.id_payment_method
        LEFT JOIN public.general_param gp ON lg.group_id = gp.table_id
        WHERE lq.id_cash_register = ANY(v_cash_registers) AND lg.state_audit = 1200001
        GROUP BY 1, 2, 3
    ),
    json_recaudo_agrupado AS (
        SELECT local_number, nombre_turno, 
            jsonb_agg(jsonb_build_object('metodo', concepto, 'monto', TO_CHAR(monto_recaudado, 'FM999999990.00'))) as lista
        FROM recaudacion_data GROUP BY 1, 2
    ),
    pre_pagos_agrupados AS (
        SELECT bv.local_number, COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo_pago, vpd.metodo_nombre as metodo, SUM(vpd.amount) as monto_total
        FROM base_ventas_unificadas bv
        INNER JOIN vw_reporte_pagos_detalle vpd ON bv.id_sale = vpd.id_sale
        WHERE bv.id_sale_operation_type NOT IN (3,4) AND bv.transferencia_gratuita = 0 AND vpd.payment_state = 40001
        GROUP BY bv.local_number, ROLLUP(bv.nombre_turno), vpd.metodo_nombre
    ),
    metodos_pago_final AS (
        SELECT local_number, grupo_pago, jsonb_agg(jsonb_build_object('metodo', metodo, 'monto', TO_CHAR(monto_total, 'FM999999990.00'))) as pagos
        FROM pre_pagos_agrupados WHERE metodo IS NOT NULL GROUP BY 1, 2
    )
    SELECT jsonb_agg(jsonb_build_object(
        'nombre_sede', d.local_nombre_real, 
        'color_sede', d.color_hex,
        'reporte', d.bloques
    ))
    FROM (
        SELECT 
            ma.local_nombre_real,
            ol.color_hex,
            jsonb_agg(jsonb_build_object(
                'id_turno', ma.id_work_shift,
                'nombre_bloque', ma.grupo,
                'total_operaciones', ma.total_ventas_count,
                'variacion', COALESCE(ROUND(((ma.venta_neta_real - COALESCE(ad.monto_ayer, 0)) / NULLIF(COALESCE(ad.monto_ayer, 0), 0)) * 100, 2), 0),
                'secciones', jsonb_build_array(
                    jsonb_build_object('titulo', 'SERAFÍN', 'total', TO_CHAR(ma.serafin, 'FM999999990.00')),
                    jsonb_build_object('titulo', 'VENTA BRUTA', 'total', TO_CHAR(ma.bruto_vista - ma.serafin, 'FM999999990.00'),
                        'detalle', jsonb_build_array(
                            jsonb_build_object('id', 3, 'concepto', 'Consumo Interno', 'monto', TO_CHAR(ma.consumo, 'FM999999990.00')),
                            jsonb_build_object('id', 5, 'concepto', 'Transferencia Gratuita', 'monto', TO_CHAR(ma.gratuita, 'FM999999990.00')),
                            jsonb_build_object('id', 0,'concepto', 'Descuentos', 'monto', TO_CHAR(ma.descuentos, 'FM999999990.00'))
                        )
                    ),
                    jsonb_build_object('titulo', 'VENTA NETA', 'total', TO_CHAR(ma.venta_neta_real, 'FM999999990.00'),
                        'detalle', jsonb_build_array(
                            jsonb_build_object('id', 2, 'concepto', 'Ventas a Crédito', 'monto', TO_CHAR(ma.credito, 'FM999999990.00')),
                            jsonb_build_object('id', 7, 'concepto', 'Ventas Adelanto', 'monto', TO_CHAR(ma.adelanto, 'FM999999990.00'))
                        )
                    ),
                    jsonb_build_object('titulo', 'VENTA CONTADA', 'total', TO_CHAR(ma.venta_contada_esperada, 'FM999999990.00'),
                        'detalle', COALESCE(mpf.pagos, '[]'::jsonb),
                        'recaudado_fisico', COALESCE(jra.lista, '[]'::jsonb)
                    )
                )
            ) ORDER BY (ma.grupo = 'TOTAL GENERAL'), ma.id_work_shift) as bloques
        FROM metricas_agrupadas ma
        LEFT JOIN ayer_data_calculada ad ON ad.local_number = ma.local_number AND UPPER(TRIM(ad.grupo_ayer)) = UPPER(TRIM(ma.grupo))
        LEFT JOIN metodos_pago_final mpf ON mpf.local_number = ma.local_number AND mpf.grupo_pago = ma.grupo
        LEFT JOIN json_recaudo_agrupado jra ON jra.local_number = ma.local_number AND jra.nombre_turno = ma.grupo
        LEFT JOIN public.order_locals ol ON ma.local_number = ol.local_number 
        GROUP BY ma.local_nombre_real, ol.sort_order, ol.color_hex
        ORDER BY COALESCE(ol.sort_order, 999) ASC
    ) d;
END;
$function$