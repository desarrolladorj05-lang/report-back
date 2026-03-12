CREATE OR REPLACE FUNCTION sp_managment_report_sales(p_fecha_busqueda TEXT)
RETURNS TABLE(resultado JSON) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH ventas_diarias_sede AS (
        -- 1. Calculamos el total REAL de cada sede por cada día (Hoy y Ayer)
        -- Esto asegura que el comparativo sea Sede vs Sede, sin importar los turnos
        SELECT 
            fecha_proceso,
            idlocal,
            dslocal as local_nombre,
            SUM(monto) as total_dia_sede
        FROM vw_mat_reporte_ventas
        WHERE fecha_proceso IN (
            p_fecha_busqueda, 
            to_char(to_date(p_fecha_busqueda, 'DD/MM/YYYY') - INTERVAL '1 day', 'DD/MM/YYYY')
        )
        GROUP BY 1, 2, 3
    ),
    ventas_con_comparativa AS (
        -- 2. Obtenemos el "Monto Ayer" real usando LAG sobre el total de la sede
        SELECT 
            *,
            LAG(total_dia_sede) OVER(
                PARTITION BY idlocal 
                ORDER BY to_date(fecha_proceso, 'DD/MM/YYYY')
            ) as monto_ayer_real
        FROM ventas_diarias_sede
    ),
    detalle_turnos AS (
        -- 3. Traemos el desglose de turnos únicamente para el día consultado
        SELECT 
            fecha_proceso,
            idlocal,
            dsturno as turno_nombre,
            SUM(monto) as monto_turno
        FROM vw_mat_reporte_ventas
        WHERE fecha_proceso = p_fecha_busqueda
        GROUP BY 1, 2, 3
    ),
    monto_total_global AS (
        -- 4. Calculamos la suma de todas las sedes del día actual para el encabezado
        SELECT SUM(monto) as monto_hoy_global 
        FROM vw_mat_reporte_ventas 
        WHERE fecha_proceso = p_fecha_busqueda
    )
    -- 5. Construcción de la estructura JSON final
    SELECT json_build_object(
        'fecha_operativa', p_fecha_busqueda,
        'venta_total_todas_sedes', COALESCE((SELECT monto_hoy_global FROM monto_total_global), 0),
        'sedes', json_agg(res_json)
    )
    FROM (
        SELECT 
            v.local_nombre,
            v.total_dia_sede as monto_hoy,
            COALESCE(v.monto_ayer_real, 0) as monto_ayer,
            ROUND(
                ((v.total_dia_sede - v.monto_ayer_real) / NULLIF(v.monto_ayer_real, 0)) * 100, 
                2
            ) as porc_variacion_diaria,
            -- Generamos el array de turnos dentro de cada sede
            json_agg(
                json_build_object(
                    'turno', d.turno_nombre,
                    'monto', d.monto_turno,
                    'porc_del_local', ROUND((d.monto_turno / NULLIF(v.total_dia_sede, 0)) * 100, 2)
                )
            ) as detalles_turnos
        FROM ventas_con_comparativa v
        JOIN detalle_turnos d ON v.idlocal = d.idlocal AND v.fecha_proceso = d.fecha_proceso
        WHERE v.fecha_proceso = p_fecha_busqueda
        GROUP BY v.local_nombre, v.total_dia_sede, v.monto_ayer_real
    ) res_json;
END;
$$;








