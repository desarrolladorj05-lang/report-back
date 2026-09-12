CREATE OR REPLACE FUNCTION public.sp_report_contometer_by_product(
        p_id_local integer,
        p_fecha_busqueda text,
        p_id_turno integer DEFAULT NULL,
        p_id_producto integer DEFAULT NULL
    ) RETURNS jsonb LANGUAGE plpgsql STABLE AS $function$
DECLARE v_shift_pattern text;
v_shift_name text;
v_cash_ids uuid [];
BEGIN v_shift_pattern := CASE
    p_id_turno
    WHEN 1 THEN 'MAÑANA'
    WHEN 2 THEN 'TARDE'
    WHEN 3 THEN 'NOCHE'
    WHEN 4 THEN 'MADRUGADA'
    ELSE NULL
END;
v_shift_name := COALESCE(v_shift_pattern, 'TODO EL DIA');
-- 1. Capturamos las cajas del día
SELECT ARRAY_AGG(DISTINCT cr.id_cash_register) INTO v_cash_ids
FROM public.cash_register cr
    JOIN public.local l ON cr.id_local = l.id_local
    JOIN public.work_shift ws ON cr.id_work_shift = ws.id_work_shift
    LEFT JOIN public.work_shift ws_ref ON l.id_local = ws_ref.id_local
    AND ws_ref.shift_name = 'MAÑANA'
WHERE l.local_number = p_id_local
    AND cr.state_audit = 1200001 -- Registro Activo
    AND (
        v_shift_pattern IS NULL
        OR ws.shift_name = v_shift_pattern
    )
    AND (
        CASE
            WHEN ws.shift_name = 'MAÑANA' THEN to_char(
                (cr.opennig_date AT TIME ZONE 'America/Lima'),
                'DD/MM/YYYY'
            )
            WHEN (cr.opennig_date AT TIME ZONE 'America/Lima')::time < COALESCE(ws_ref.start_time, '07:30:00'::time) THEN to_char(
                (cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day',
                'DD/MM/YYYY'
            )
            ELSE to_char(
                (cr.opennig_date AT TIME ZONE 'America/Lima'),
                'DD/MM/YYYY'
            )
        END
    ) = p_fecha_busqueda;
-- Si no hay ninguna caja abierta o cerrada hoy, devolvemos estructura limpia en lugar de null
IF v_cash_ids IS NULL
OR array_length(v_cash_ids, 1) = 0 THEN RETURN jsonb_build_object(
    'id_turno',
    COALESCE(p_id_turno, 0),
    'turno',
    v_shift_name,
    'fecha',
    p_fecha_busqueda,
    'productos',
    '[]'::jsonb
);
END IF;
RETURN (
    WITH cr_filtradas AS (
        SELECT unnest(v_cash_ids) AS id_cash_register
    ),
    -- 2. Datos de contómetros (La tabla flow_meter no tiene precio de venta directo, se asocia por producto/manguera)
    fm AS (
        SELECT s.side_number,
            h.hose_position,
            s.name::text AS side_name,
            COALESCE(h.hose_name, '')::text AS hose_name,
            p.foreign_name::text AS product_name,
            p.product_id,
            f.side_id,
            f.hose_id,
            MIN(COALESCE(f.initial_cm_controller, 0))::numeric AS initial_contometer,
            MAX(COALESCE(f.final_cm_controller, 0))::numeric AS final_contometer,
            COALESCE(
                SUM(
                    COALESCE(f.final_cm_controller, 0) - COALESCE(f.initial_cm_controller, 0)
                ),
                0
            )::numeric AS volume_contometer
        FROM public.flow_meter f
            JOIN cr_filtradas cr ON f.id_cash_register = cr.id_cash_register
            JOIN public.side s ON s.id_side = f.side_id
            LEFT JOIN public.hose h ON h.id_hose = f.hose_id
            JOIN public.product p ON p.product_id = f.product_id
        WHERE (
                p_id_producto IS NULL
                OR p.product_id = p_id_producto
            )
        GROUP BY s.side_number,
            h.hose_position,
            s.name,
            h.hose_name,
            p.foreign_name,
            p.product_id,
            f.side_id,
            f.hose_id
    ),
    -- 3. Datos de ventas en vivo con separación por PRECIO UNITARIO
    sales AS (
        SELECT COALESCE(sd.id_side, tc.id_side) AS side_id,
            h.id_hose AS hose_id,
            sd.id_product AS product_id,
            p.foreign_name::text AS product_name,
            s.side_number AS side_number,
            h.hose_position AS hose_position,
            s.name::text AS side_name,
            COALESCE(h.hose_name, '')::text AS hose_name,
            COALESCE(sd.unit_price, 0)::numeric AS unit_price,
            SUM(
                CASE
                    WHEN COALESCE(s_op.id_sale_operation_type, 0) <> 4 THEN COALESCE(sd.quantity, 0)
                    ELSE 0
                END
            )::numeric AS volume_sales,
            SUM(
                CASE
                    WHEN COALESCE(s_op.id_sale_operation_type, 0) = 4 THEN COALESCE(sd.quantity, 0)
                    ELSE 0
                END
            )::numeric AS serafin_volume
        FROM public.sale_detail sd
            JOIN public.sale s_op ON s_op.id_sale = sd.id_sale
            JOIN cr_filtradas cr ON s_op.id_cash_register = cr.id_cash_register
            LEFT JOIN public.transaction_controller tc ON tc.id_transaction = sd.id_transaction
            LEFT JOIN public.side s ON s.id_side = COALESCE(sd.id_side, tc.id_side)
            LEFT JOIN public.hose h ON h.side_id = COALESCE(sd.id_side, tc.id_side)
            AND h.hose_position = tc.position_hose
            JOIN public.product p ON p.product_id = sd.id_product
        WHERE COALESCE(s_op.state, 40001) = 40001
            AND COALESCE(s_op.state_audit, 1200001) = 1200001
            AND sd.sale_type = 1300001
            AND (
                p_id_producto IS NULL
                OR sd.id_product = p_id_producto
            )
        GROUP BY COALESCE(sd.id_side, tc.id_side),
            h.id_hose,
            sd.id_product,
            p.foreign_name,
            s.side_number,
            s.name,
            h.hose_name,
            h.hose_position,
            sd.unit_price 
    ),
    -- 4. Combinación mediante FULL JOIN usando producto, manguera y precio
    detalle_completo AS (
        SELECT COALESCE(fm.product_name, sa.product_name) AS product_name,
            COALESCE(fm.product_id, sa.product_id) AS product_id,
            COALESCE(fm.side_name, sa.side_name) AS side_name,
            COALESCE(fm.hose_name, sa.hose_name) AS hose_name,
            COALESCE(fm.side_number, sa.side_number) AS side_number,
            COALESCE(fm.hose_position, sa.hose_position) AS hose_position,
            COALESCE(sa.unit_price, 0) AS unit_price,
            COALESCE(fm.initial_contometer, 0) AS initial_contometer,
            COALESCE(fm.final_contometer, 0) AS final_contometer,
            COALESCE(fm.volume_contometer, 0) AS volume_contometer,
            COALESCE(sa.volume_sales, 0) AS volume_sales,
            COALESCE(sa.serafin_volume, 0) AS serafin_volume,
            (
                COALESCE(sa.volume_sales, 0) + COALESCE(sa.serafin_volume, 0) - COALESCE(fm.volume_contometer, 0)
            ) AS difference_volume
        FROM fm
            FULL OUTER JOIN sales sa ON sa.product_id = fm.product_id
            AND sa.side_id = fm.side_id
            AND sa.hose_id = fm.hose_id
    ),
    por_producto AS (
        SELECT product_id,
            product_name,
            unit_price,
            jsonb_agg(
                jsonb_build_object(
                    'side_name',
                    side_name,
                    'hose_name',
                    hose_name,
                    'initial_contometer',
                    initial_contometer,
                    'final_contometer',
                    final_contometer,
                    'volume_contometer',
                    volume_contometer,
                    'volume_sales',
                    volume_sales,
                    'serafin_volume',
                    serafin_volume,
                    'difference_volume',
                    difference_volume
                )
                ORDER BY side_number ASC,
                    hose_position ASC
            ) AS detalle
        FROM detalle_completo
        WHERE product_id IS NOT NULL
        GROUP BY product_id,
            product_name,
            unit_price 
    )
    SELECT jsonb_build_object(
            'id_turno',
            COALESCE(p_id_turno, 0),
            'turno',
            v_shift_name,
            'fecha',
            p_fecha_busqueda,
            'productos',
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id_producto',
                        product_id,
                        'product_name',
                        product_name,
                        'price',
                        unit_price,
                        'detalle',
                        detalle
                    )
                    ORDER BY product_name ASC,
                        unit_price DESC
                ),
                '[]'::jsonb
            )
        )
    FROM por_producto
);
END;
$function$;