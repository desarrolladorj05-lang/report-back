CREATE OR REPLACE FUNCTION public.sp_reporte_combustibles_by_sede (
    p_id_local integer DEFAULT NULL,
    p_fecha_busqueda text DEFAULT NULL
) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
BEGIN
    RETURN QUERY
    WITH ventas_filtradas AS (
        SELECT 
            vb.local_number,
            -- Obtenemos el nombre del local aquí para no perderlo en la agrupación
            COALESCE((SELECT l.name FROM local l WHERE l.local_number = vb.local_number LIMIT 1), 'SEDE ' || vb.local_number) as nombre_sede_real,
            vb.nombre_turno,
            sd.product_snapshot->>'description' as producto,
            sd.quantity,
            (CASE 
                WHEN vb.id_sale_operation_type IN (3, 4) THEN 0
                WHEN COALESCE(vb.transferencia_gratuita, 0) > 0 THEN 0
                ELSE sd.total_amount 
             END)::numeric(12,2) as subtotal_item
        FROM vw_reporte_ventas_base vb
        INNER JOIN sale_detail sd ON vb.id_sale = sd.id_sale
        WHERE vb.state = 40001 
          AND (p_id_local IS NULL OR vb.local_number = p_id_local)
          AND vb.fecha_negocio = p_fecha_busqueda
          AND (sd.product_snapshot->>'groupProductId')::INT = 20006
    ),
    metricas_agrupadas AS (
        SELECT 
            nombre_sede_real,
            COALESCE(nombre_turno, 'TOTAL GENERAL') as grupo_turno,
            producto,
            SUM(quantity)::numeric(12,3) as cantidad,
            SUM(subtotal_item)::numeric(12,2) as monto
        FROM ventas_filtradas
        -- Ahora agrupamos PRIMERO por sede, y luego hacemos el CUBE de turnos/productos
        GROUP BY nombre_sede_real, CUBE(nombre_turno, producto)
        HAVING (nombre_turno IS NOT NULL OR producto IS NOT NULL) 
            OR (nombre_turno IS NULL AND producto IS NULL)
    ),
    formateo_turnos AS (
        SELECT 
            nombre_sede_real,
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
        GROUP BY nombre_sede_real, grupo_turno
    ),
    sedes_compiladas AS (
        SELECT 
            nombre_sede_real,
            jsonb_build_object(
                'nombre_sede', nombre_sede_real,
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
            ) as reporte_sede
        FROM formateo_turnos
        GROUP BY nombre_sede_real
    )
    -- FINAL: Si se pidió una sede, devolvemos el objeto. Si no, devolvemos el array.
    SELECT 
        CASE 
            WHEN p_id_local IS NOT NULL THEN (SELECT reporte_sede FROM sedes_compiladas LIMIT 1)
            ELSE jsonb_agg(reporte_sede)
        END
    FROM sedes_compiladas;
END;
$function$;