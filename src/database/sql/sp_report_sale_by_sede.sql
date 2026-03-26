CREATE
OR REPLACE FUNCTION public.sp_reporte_ventas_by_sede (p_id_local integer, p_fecha_busqueda text) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_ayer TEXT;
    v_cash_registers UUID[];
BEGIN
    -- 1. IDENTIFICACIÓN DE CAJAS (Lógica de Fecha de Negocio ajustada a 07:30 AM)
    SELECT array_agg(cr.id_cash_register) INTO v_cash_registers
    FROM public.cash_register cr
    JOIN public.local l ON cr.id_local = l.id_local 
    JOIN public.work_shift ws ON cr.id_work_shift = ws.id_work_shift
    WHERE l.local_number = p_id_local 
      AND cr.state_audit = 1200001
      AND (
        CASE
            -- Si es Mañana, la fecha es la misma
            WHEN ws.shift_name::text = 'MAÑANA'::text THEN 
                to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
            
            -- CAMBIO AQUÍ: Si no es mañana y abrió antes de las 07:30 (7.5 horas), es del día anterior
            WHEN ws.shift_name::text <> 'MAÑANA'::text 
                 AND (EXTRACT(hour FROM (cr.opennig_date AT TIME ZONE 'America/Lima')) + EXTRACT(minute FROM (cr.opennig_date AT TIME ZONE 'America/Lima'))/60.0) < 7.5 THEN 
                to_char((cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day', 'DD/MM/YYYY')
            
            ELSE 
                to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY')
        END
      ) = p_fecha_busqueda;

    v_fecha_ayer := to_char(to_date(p_fecha_busqueda, 'DD/MM/YYYY') - interval '1 day', 'DD/MM/YYYY');

    -- El resto del proceso se mantiene igual ya que depende de v_cash_registers identificados arriba
    RETURN QUERY
    WITH base_ventas_unificadas AS (
        SELECT * FROM vw_reporte_ventas_base
        WHERE state = 40001 
          AND local_number = p_id_local
          AND fecha_negocio = p_fecha_busqueda
    ),
    recaudacion AS (
        SELECT 
            COALESCE(pm.name, gp.description, 'OTROS') as concepto,
            SUM(lg.total_collected)::numeric(10,2) as monto_recaudado
        FROM public.liquidation_group lg
        INNER JOIN public.liquidation lq ON lg.id_liquidation = lq.id_liquidation
        LEFT JOIN public.payment_method pm ON lg.payment_method_id = pm.id_payment_method
        LEFT JOIN public.general_param gp ON lg.group_id = gp.table_id
        WHERE lq.id_cash_register = ANY(v_cash_registers)
          AND lg.state_audit = 1200001
        GROUP BY 1
    ),
    ventas_ayer AS (
        SELECT dsturno as nombre_turno, SUM(monto)::numeric(10,2) as monto_ayer
        FROM vw_mat_reporte_ventas
        WHERE fecha_proceso = v_fecha_ayer AND idlocal = p_id_local
        GROUP BY dsturno
    ),
    metricas_agrupadas AS (
        SELECT
            COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo,
            SUM(total_amount + COALESCE(total_discount, 0) + COALESCE(transferencia_gratuita, 0))::numeric(10,2) as bruto_vista,
            COUNT(DISTINCT bv.id_sale) as total_ventas_count,
            COALESCE(SUM(DISTINCT va.monto_ayer), 0) as total_ayer,
            SUM(CASE WHEN id_sale_operation_type = 4 THEN total_amount ELSE 0 END)::numeric(10,2) AS serafin,
            SUM(CASE WHEN id_sale_operation_type = 3 THEN total_amount ELSE 0 END)::numeric(10,2) AS consumo,
            SUM(transferencia_gratuita)::numeric(10,2) AS gratuita,
            SUM(total_discount)::numeric(10,2) AS descuentos,
            (SUM(outstanding_balance) + 
             SUM(CASE WHEN id_sale_document_type = 3 AND id_sale_operation_type NOT IN (1, 6, 4, 3, 5) THEN total_amount ELSE 0 END)
            )::numeric(10,2) AS credito,
            SUM(applied_advance_amount)::numeric(10,2) AS adelanto,
            (SUM(total_amount) 
              - SUM(CASE WHEN id_sale_operation_type IN (3,4) THEN total_amount ELSE 0 END) 
              - SUM(outstanding_balance) 
              - SUM(CASE WHEN id_sale_document_type = 3 AND id_sale_operation_type NOT IN (1, 6, 4, 5, 3) THEN total_amount ELSE 0 END)
              + SUM(applied_advance_amount)
            )::numeric(10,2) as venta_contada_esperada
        FROM base_ventas_unificadas bv
        LEFT JOIN ventas_ayer va ON bv.nombre_turno = va.nombre_turno
        GROUP BY ROLLUP(bv.nombre_turno)
    ),
    pre_pagos AS (
        SELECT 
            COALESCE(bv.nombre_turno, 'TOTAL GENERAL') as grupo,
            COALESCE(vpd.metodo_nombre, 'OTROS PAGOS') as metodo,
            SUM(vpd.amount) as monto_total
        FROM base_ventas_unificadas bv
        INNER JOIN vw_reporte_pagos_detalle vpd ON bv.id_sale = vpd.id_sale
        WHERE bv.id_sale_operation_type NOT IN (3,4) 
          AND bv.transferencia_gratuita = 0 
          AND vpd.payment_state = 40001
        GROUP BY ROLLUP(bv.nombre_turno), vpd.metodo_nombre
    ),
    metodos_pago_final AS (
        SELECT 
            grupo,
            jsonb_agg(jsonb_build_object(
                'metodo', metodo, 
                'monto', TO_CHAR(monto_total, 'FM999999990.00')
            ) ORDER BY monto_total DESC) as pagos
        FROM pre_pagos
        WHERE metodo IS NOT NULL
        GROUP BY grupo
    ),
    json_recaudo AS (
        SELECT 
            jsonb_agg(jsonb_build_object(
                'metodo', concepto,
                'monto', TO_CHAR(monto_recaudado, 'FM999999990.00')
            )) as lista
        FROM recaudacion
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
                        'total', TO_CHAR(m.venta_contada_esperada, 'FM999999990.00'),
                        'detalle', COALESCE(mp.pagos, '[]'::jsonb),
                        'recaudado_fisico', CASE 
                                            WHEN m.grupo = 'TOTAL GENERAL' 
                                            THEN COALESCE((SELECT lista FROM json_recaudo), '[]'::jsonb)
                                            ELSE '[]'::jsonb END
                    )
                )
            ) as reporte_bloque
        FROM metricas_agrupadas m
        LEFT JOIN metodos_pago_final mp ON m.grupo = mp.grupo
        WHERE m.grupo IS NOT NULL
    ) sub;
END;
$function$