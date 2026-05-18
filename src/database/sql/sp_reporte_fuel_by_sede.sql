CREATE OR REPLACE FUNCTION public.sp_reporte_combustibles_by_sede (
    p_id_local integer DEFAULT NULL::integer,
    p_fecha_busqueda text DEFAULT NULL::text
) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_busqueda_date DATE;
    v_timestamp_inicio TIMESTAMPTZ;
    v_timestamp_fin TIMESTAMPTZ;
BEGIN
    -- 1. PREPARACIÓN DE RANGOS
    v_fecha_busqueda_date := to_date(p_fecha_busqueda, 'DD/MM/YYYY');
    v_timestamp_inicio := (v_fecha_busqueda_date - INTERVAL '1 day')::TIMESTAMPTZ;
    v_timestamp_fin := (v_fecha_busqueda_date + INTERVAL '2 days')::TIMESTAMPTZ;

    RETURN QUERY
    WITH ventas_id_filtradas AS (
        SELECT s.id_sale, l.local_number -- Mantenemos el local_number para el join final
        FROM public.sale s
        INNER JOIN public.local l ON s.id_local = l.id_local
        WHERE s.created_at >= v_timestamp_inicio 
          AND s.created_at <= v_timestamp_fin
          AND (p_id_local IS NULL OR l.local_number = p_id_local)
          AND s.state = 40001
    ),
    ventas_filtradas AS (
        SELECT 
            vf.local_number,
            COALESCE((SELECT l.name FROM local l WHERE l.local_number = vf.local_number LIMIT 1), 'SEDE ' || vf.local_number) as nombre_sede_real,
            vb.nombre_turno,
            -- Asignación manual del ID de turno según su nombre
            CASE 
                WHEN UPPER(vb.nombre_turno) LIKE '%MAÑANA%' THEN 1
                WHEN UPPER(vb.nombre_turno) LIKE '%TARDE%' THEN 2
                WHEN UPPER(vb.nombre_turno) LIKE '%NOCHE%' THEN 3
                WHEN UPPER(vb.nombre_turno) LIKE '%MADRUGADA%' THEN 4
                ELSE 99 -- Para turnos no identificados o totales
            END AS id_turno,
            (sd.product_snapshot->>'productId')::INT as id_producto,
            sd.product_snapshot->>'description' as producto,
            (CASE WHEN vb.id_sale_operation_type = 4 THEN 0 ELSE sd.quantity END)::numeric(12,3) as quantity_filtrada,
            (CASE WHEN vb.id_sale_operation_type = 4 THEN sd.quantity ELSE 0 END)::numeric(12,3) as quantity_serafin_solo,
            (CASE 
                WHEN vb.id_sale_operation_type IN (3, 4) THEN 0
                WHEN COALESCE(vb.transferencia_gratuita, 0) > 0 THEN 0
                ELSE sd.total_amount 
             END)::numeric(12,2) as subtotal_item
        FROM ventas_id_filtradas vf
        INNER JOIN vw_reporte_ventas_base vb ON vf.id_sale = vb.id_sale
        INNER JOIN sale_detail sd ON vb.id_sale = sd.id_sale
        WHERE vb.fecha_negocio = p_fecha_busqueda
          AND (sd.product_snapshot->>'groupProductId')::INT = 20006
    ),
    metricas_agrupadas AS (
        SELECT 
            local_number,
            nombre_sede_real,
            id_turno, -- Añadido a las métricas para arrastrarlo al JSON
            COALESCE(nombre_turno, 'TOTAL GENERAL') as grupo_turno,
            id_producto,
            producto,
            SUM(quantity_filtrada)::numeric(12,3) as cantidad,
            SUM(quantity_serafin_solo)::numeric(12,3) as cantidad_serafin,
            SUM(subtotal_item)::numeric(12,2) as monto
        FROM ventas_filtradas
        -- Agrupamos id_turno junto con el nombre_turno para no romper la agregación jerárquica del CUBE
        GROUP BY local_number, nombre_sede_real, CUBE((id_turno, nombre_turno), (id_producto, producto))
        HAVING (nombre_turno IS NOT NULL OR producto IS NOT NULL) 
            OR (nombre_turno IS NULL AND producto IS NULL)
    ),
    formateo_turnos AS (
        SELECT 
            local_number,
            nombre_sede_real,
            -- En caso de ser el TOTAL GENERAL, le asignamos el ID 99 de forma explícita
            COALESCE(id_turno, 99) as id_turno_formateado,
            grupo_turno,
            jsonb_agg(
                jsonb_build_object(
                    'id_producto', id_producto,
                    'producto', producto,
                    'cantidad', cantidad,
                    'cantidad_serafin', cantidad_serafin,
                    'monto', TO_CHAR(monto, 'FM999999990.00')
                )
                ORDER BY producto ASC
            ) FILTER (WHERE producto IS NOT NULL) as detalle_productos,
            MAX(CASE WHEN producto IS NULL THEN monto ELSE 0 END) as total_monto_turno,
            MAX(CASE WHEN producto IS NULL THEN cantidad ELSE 0 END) as total_cantidad_turno,
            MAX(CASE WHEN producto IS NULL THEN cantidad_serafin ELSE 0 END) as total_cantidad_serafin_turno
        FROM metricas_agrupadas
        GROUP BY local_number, nombre_sede_real, id_turno, grupo_turno
    ),
    sedes_compiladas AS (
        SELECT 
            f.local_number,
            f.nombre_sede_real,
            ol.color_hex,
            jsonb_build_object(
                'nombre_sede', f.nombre_sede_real,
                'color_sede', ol.color_hex,
                'categoria', 'Combustibles',
                'reporte_por_turnos', jsonb_agg(
                    jsonb_build_object(
                        'id_turno', f.id_turno_formateado, -- Se inyecta el ID manual del turno aquí
                        'turno', f.grupo_turno,
                        'total_monto', TO_CHAR(f.total_monto_turno, 'FM999999990.00'),
                        'total_cantidad', f.total_cantidad_turno,
                        'total_cantidad_serafin', f.total_cantidad_serafin_turno,
                        'detalle_productos', COALESCE(f.detalle_productos, '[]'::jsonb)
                    )
                    -- Primero ordenamos para que el "TOTAL GENERAL" quede al final, luego ordenamos por id_turno
                    ORDER BY (f.grupo_turno = 'TOTAL GENERAL') ASC, f.id_turno_formateado ASC
                )
            ) as reporte_sede,
            ol.sort_order
        FROM formateo_turnos f
        LEFT JOIN public.order_locals ol ON f.local_number = ol.local_number
        GROUP BY f.local_number, f.nombre_sede_real, ol.sort_order, ol.color_hex
    )
    SELECT 
        CASE 
            WHEN p_id_local IS NOT NULL THEN (SELECT reporte_sede FROM sedes_compiladas LIMIT 1)
            ELSE jsonb_agg(reporte_sede ORDER BY COALESCE(sort_order, 999) ASC)
        END
    FROM sedes_compiladas;
END;
$function$