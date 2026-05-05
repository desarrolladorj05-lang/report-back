CREATE
OR REPLACE FUNCTION public.sp_managment_report_sales (p_fecha_busqueda text) RETURNS TABLE (resultado json) LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_ayer TEXT;
    v_fecha_inicio_mes_date DATE;
    v_fecha_busqueda_date DATE;
    v_timestamp_inicio TIMESTAMPTZ;
    v_timestamp_fin TIMESTAMPTZ;
BEGIN
    -- 1. Preparación de fechas
    v_fecha_busqueda_date := to_date(p_fecha_busqueda, 'DD/MM/YYYY');
    v_fecha_ayer := to_char(v_fecha_busqueda_date - INTERVAL '1 day', 'DD/MM/YYYY');
    v_fecha_inicio_mes_date := v_fecha_busqueda_date - INTERVAL '30 days';

    -- Ajuste de rango para filtros de índices (performance)
    v_timestamp_inicio := (v_fecha_busqueda_date - INTERVAL '32 days')::TIMESTAMPTZ;
    v_timestamp_fin := (v_fecha_busqueda_date + INTERVAL '2 days')::TIMESTAMPTZ;

    RETURN QUERY
    WITH maestro_config AS (
        -- Fuente de verdad de sedes (aunque no tengan ventas)
        SELECT 
            ol.local_number as idlocal, 
            ol.sort_order as prioridad,
            COALESCE(ol.color_hex, '#94a3b8') as color_local,
            COALESCE(l.local_name, 'Sede ' || ol.local_number) as nombre_oficial
        FROM public.order_locals ol
        LEFT JOIN public.local l ON ol.local_number = l.local_number
    ),
    ventas_filtradas AS (
        -- Filtro rápido por índice de tiempo
        SELECT id_sale FROM sale 
        WHERE created_at >= v_timestamp_inicio AND created_at <= v_timestamp_fin
        AND state = 40001
    ),
    base_calculo_neta AS (
        -- Detalle por turno y sede
        SELECT 
            v.local_number as idlocal,
            v.fecha_negocio,
            v.nombre_turno as turno_nombre, 
            (SUM(v.total_amount) - 
            SUM(CASE WHEN v.id_sale_operation_type IN (3,4,5,6) THEN v.total_amount ELSE 0 END)
            )::NUMERIC(15,2) as monto_neta_real
        FROM vw_reporte_ventas_base v
        INNER JOIN ventas_filtradas vf ON v.id_sale = vf.id_sale
        WHERE to_date(v.fecha_negocio, 'DD/MM/YYYY') BETWEEN v_fecha_inicio_mes_date AND v_fecha_busqueda_date
        GROUP BY 1, 2, 3
    ),
    sedes_totales_diarios AS (
        -- Total por sede y día
        SELECT idlocal, fecha_negocio, SUM(monto_neta_real) as total_dia_sede
        FROM base_calculo_neta
        GROUP BY 1, 2
    ),
    totales_globales_por_dia AS (
        -- Total de TODA la empresa por día
        SELECT 
            fecha_negocio,
            SUM(total_dia_sede)::NUMERIC(15,2) as venta_total_dia
        FROM sedes_totales_diarios
        GROUP BY fecha_negocio
    ),
    comparativa_global AS (
        -- Bloque para la variación total (Lo que pediste recuperar)
        SELECT 
            SUM(CASE WHEN fecha_negocio = p_fecha_busqueda THEN venta_total_dia ELSE 0 END) as total_hoy_global,
            SUM(CASE WHEN fecha_negocio = v_fecha_ayer THEN venta_total_dia ELSE 0 END) as total_ayer_global
        FROM totales_globales_por_dia
    ),
    analytics_final AS (
        -- Analítica por sede para los gráficos de área
        SELECT 
            mc.idlocal, 
            mc.nombre_oficial as local_nombre, 
            mc.color_local as color,
            COALESCE(SUM(v.total_dia_sede), 0)::NUMERIC(15,2) as total_acumulado_mes,
            json_agg(
                json_build_object(
                    'fecha', v.fecha_negocio,
                    'venta', v.total_dia_sede::NUMERIC(15,2)
                ) ORDER BY to_date(v.fecha_negocio, 'DD/MM/YYYY') ASC
            ) FILTER (WHERE v.fecha_negocio IS NOT NULL) as serie_historica
        FROM maestro_config mc
        LEFT JOIN sedes_totales_diarios v ON mc.idlocal = v.idlocal
        GROUP BY mc.idlocal, mc.nombre_oficial, mc.color_local
    )
    SELECT json_build_object(
        'fecha_operativa', p_fecha_busqueda,
        'venta_total_todas_sedes', COALESCE((SELECT total_hoy_global FROM comparativa_global), 0)::NUMERIC(15,2),
        'variacion_total_global', (
            SELECT ROUND(((total_hoy_global - total_ayer_global) / NULLIF(total_ayer_global, 0)) * 100, 2)::NUMERIC(15,2) 
            FROM comparativa_global
        ),
        'total_acumulado_global', COALESCE((SELECT SUM(venta_total_dia) FROM totales_globales_por_dia), 0)::NUMERIC(15,2),
        'analytics_general', (
            SELECT json_agg(
                json_build_object('fecha', fecha_negocio, 'venta', venta_total_dia) 
                ORDER BY to_date(fecha_negocio, 'DD/MM/YYYY') ASC
            ) FROM totales_globales_por_dia
        ),
        'sedes', (
            SELECT json_agg(res_json ORDER BY prioridad ASC)
            FROM (
                SELECT 
                    mc.idlocal, 
                    mc.nombre_oficial as local_nombre, 
                    mc.color_local as color,
                    COALESCE(v_hoy.total_dia_sede, 0)::NUMERIC(15,2) as monto_hoy,
                    COALESCE(v_ayer.total_dia_sede, 0)::NUMERIC(15,2) as monto_ayer,
                    ROUND(((COALESCE(v_hoy.total_dia_sede, 0) - COALESCE(v_ayer.total_dia_sede, 0)) / NULLIF(COALESCE(v_ayer.total_dia_sede, 0), 0)) * 100, 2)::NUMERIC(15,2) as porc_variacion_diaria,
                    (SELECT af.total_acumulado_mes FROM analytics_final af WHERE af.idlocal = mc.idlocal) as total_acumulado_sede,
                    (
                        SELECT json_agg(
                            json_build_object(
                                'turno', d.turno_nombre,
                                'monto', d.monto_neta_real::NUMERIC(15,2),
                                'porc_del_local', ROUND((d.monto_neta_real / NULLIF(v_hoy.total_dia_sede, 0)) * 100, 2)::NUMERIC(15,2)
                            )
                        )
                        FROM base_calculo_neta d 
                        WHERE d.idlocal = mc.idlocal AND d.fecha_negocio = p_fecha_busqueda
                    ) as detalles_turnos,
                    mc.prioridad
                FROM maestro_config mc
                LEFT JOIN sedes_totales_diarios v_hoy ON mc.idlocal = v_hoy.idlocal AND v_hoy.fecha_negocio = p_fecha_busqueda
                LEFT JOIN sedes_totales_diarios v_ayer ON mc.idlocal = v_ayer.idlocal AND v_ayer.fecha_negocio = v_fecha_ayer
            ) res_json
        ),
        'analytics', (SELECT json_agg(af) FROM analytics_final af)
    );
END;
$function$