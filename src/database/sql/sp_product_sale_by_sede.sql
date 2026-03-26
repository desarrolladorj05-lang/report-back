CREATE OR REPLACE FUNCTION public.sp_reporte_combustibles_by_sede (p_id_local integer, p_fecha_busqueda text) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
BEGIN
    RETURN QUERY
    WITH ventas_filtradas AS (
        -- Filtramos ventas por sede, fecha de negocio y el grupo de combustible (20006)
        SELECT 
            vb.nombre_turno,
            sd.product_snapshot->>'description' as producto,
            sd.quantity,
            -- LÓGICA DE VENTA NETA: 
            -- Si la venta es Serafín (4), Consumo (3), Gratuita o tiene Descuento, el neto para el reporte es 0.
            -- De lo contrario, se toma el total_amount del item.
            (CASE 
                WHEN vb.id_sale_operation_type IN (3, 4) THEN 0
                WHEN COALESCE(vb.transferencia_gratuita, 0) > 0 THEN 0
                ELSE sd.total_amount 
             END)::numeric(12,2) as subtotal_item
        FROM vw_reporte_ventas_base vb
        INNER JOIN sale_detail sd ON vb.id_sale = sd.id_sale
        WHERE vb.state = 40001 
          AND vb.local_number = p_id_local
          AND vb.fecha_negocio = p_fecha_busqueda
          AND (sd.product_snapshot->>'groupProductId')::INT = 20006
    ),
    metricas_agrupadas AS (
        -- Generamos combinaciones de Turnos y Productos (CUBE para totales cruzados)
        SELECT 
            COALESCE(nombre_turno, 'TOTAL GENERAL') as grupo_turno,
            producto,
            SUM(quantity)::numeric(12,3) as cantidad,
            SUM(subtotal_item)::numeric(12,2) as monto
        FROM ventas_filtradas
        GROUP BY CUBE(nombre_turno, producto)
        HAVING (nombre_turno IS NOT NULL OR producto IS NOT NULL) 
           OR (nombre_turno IS NULL AND producto IS NULL)
    ),
    formateo_turnos AS (
        -- Agrupamos para crear los bloques por cada turno y el bloque general
        SELECT 
            grupo_turno,
            jsonb_agg(
                jsonb_build_object(
                    'producto', producto,
                    'cantidad', cantidad,
                    'monto', TO_CHAR(monto, 'FM999999990.00')
                )
                ORDER BY producto ASC
            ) FILTER (WHERE producto IS NOT NULL) as detalle_productos,
            MAX(CASE WHEN producto IS NULL THEN monto ELSE 0 END) as total_monto_turno,
            MAX(CASE WHEN producto IS NULL THEN cantidad ELSE 0 END) as total_cantidad_turno
        FROM metricas_agrupadas
        GROUP BY grupo_turno
    )
    SELECT jsonb_build_object(
        'nombre_sede', COALESCE((SELECT l.name FROM local l WHERE l.local_number = p_id_local LIMIT 1), 'SEDE NO ENCONTRADA'),
        'categoria', 'Combustibles',
        'reporte_por_turnos', jsonb_agg(
            jsonb_build_object(
                'turno', grupo_turno,
                'total_monto', TO_CHAR(total_monto_turno, 'FM999999990.00'),
                'total_cantidad', total_cantidad_turno,
                'detalle_productos', COALESCE(detalle_productos, '[]'::jsonb)
            )
            ORDER BY (grupo_turno <> 'TOTAL GENERAL'), grupo_turno
        )
    ) as resultado_json
    FROM formateo_turnos;
END;
$function$