CREATE
OR REPLACE FUNCTION public.sp_managment_report_sales (p_fecha_busqueda text) RETURNS TABLE (resultado json) LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_ayer TEXT;
    v_fecha_inicio_mes TEXT;
    v_fecha_busqueda_date DATE;
BEGIN
    -- 1. Preparación de fechas
    v_fecha_busqueda_date := to_date(p_fecha_busqueda, 'DD/MM/YYYY');
    v_fecha_ayer := to_char(v_fecha_busqueda_date - INTERVAL '1 day', 'DD/MM/YYYY');
    
    -- CAMBIO SOLICITADO: Ahora resta 30 días calendario en lugar de truncar al inicio de mes
    v_fecha_inicio_mes := to_char(v_fecha_busqueda_date - INTERVAL '30 days', 'DD/MM/YYYY');

    RETURN QUERY
    WITH base_calculo_neta AS (
        -- 2. Traemos TODA la data desde hace 30 días hasta la fecha buscada
        SELECT 
            local_number as idlocal,
            local_nombre_real as local_nombre,
            fecha_negocio,
            nombre_turno as turno_nombre, 
            (SUM(total_amount) - 
             SUM(CASE WHEN id_sale_operation_type IN (3,4,5,6) THEN total_amount ELSE 0 END)
            )::NUMERIC(15,2) as monto_neta_real
        FROM vw_reporte_ventas_base
        WHERE state = 40001 
          AND to_date(fecha_negocio, 'DD/MM/YYYY') BETWEEN to_date(v_fecha_inicio_mes, 'DD/MM/YYYY') AND v_fecha_busqueda_date
        GROUP BY 1, 2, 3, 4
    ),
    sedes_totales_diarios AS (
        -- 3. Agrupamos totales por sede y día (para el histórico)
        SELECT 
            idlocal,
            local_nombre,
            fecha_negocio,
            SUM(monto_neta_real) as total_dia_sede
        FROM base_calculo_neta
        GROUP BY 1, 2, 3
    ),
    ventas_con_config AS (
        -- 4. JOIN con order_locals para prioridad y color
        SELECT 
            s.idlocal,
            s.local_nombre,
            s.fecha_negocio,
            s.total_dia_sede,
            COALESCE(ol.sort_order, 999) as prioridad,
            COALESCE(ol.color_hex, '#94a3b8') as color_local
        FROM sedes_totales_diarios s
        LEFT JOIN order_locals ol ON s.idlocal = ol.local_number
    ),
    analytics_final AS (
        -- 5. Construimos el bloque de Analytics agrupado por sede
        SELECT 
            v.idlocal,
            v.local_nombre,
            MAX(v.color_local) as color,
            SUM(v.total_dia_sede)::NUMERIC(15,2) as total_acumulado_mes,
            json_agg(
                json_build_object(
                    'fecha', v.fecha_negocio,
                    'venta', v.total_dia_sede::NUMERIC(15,2)
                ) ORDER BY to_date(v.fecha_negocio, 'DD/MM/YYYY') ASC
            ) as serie_historica
        FROM ventas_con_config v
        GROUP BY v.idlocal, v.local_nombre
    ),
    comparativa_global AS (
        -- 6. Totales globales (Hoy vs Ayer)
        SELECT 
            SUM(CASE WHEN fecha_negocio = p_fecha_busqueda THEN total_dia_sede ELSE 0 END) as total_hoy_global,
            SUM(CASE WHEN fecha_negocio = v_fecha_ayer THEN total_dia_sede ELSE 0 END) as total_ayer_global
        FROM sedes_totales_diarios
    )
    -- 7. Construcción del JSON FINAL
    SELECT json_build_object(
        'fecha_operativa', p_fecha_busqueda,
        'venta_total_todas_sedes', COALESCE((SELECT total_hoy_global::NUMERIC(15,2) FROM comparativa_global), 0),
        'variacion_total_global', (
            SELECT ROUND(((total_hoy_global - total_ayer_global) / NULLIF(total_ayer_global, 0)) * 100, 2)::NUMERIC(15,2) 
            FROM comparativa_global
        ),
        -- SECCIÓN 1: Data del día (Sedes y Turnos)
        'sedes', (
            SELECT json_agg(res_json ORDER BY prioridad ASC)
            FROM (
                SELECT 
                    v.idlocal,
                    v.local_nombre,
                    v.color_local as color,
                    v.total_dia_sede::NUMERIC(15,2) as monto_hoy,
                    (SELECT s2.total_dia_sede FROM sedes_totales_diarios s2 WHERE s2.idlocal = v.idlocal AND s2.fecha_negocio = v_fecha_ayer)::NUMERIC(15,2) as monto_ayer,
                    ROUND(((v.total_dia_sede - (SELECT s2.total_dia_sede FROM sedes_totales_diarios s2 WHERE s2.idlocal = v.idlocal AND s2.fecha_negocio = v_fecha_ayer)) / NULLIF((SELECT s2.total_dia_sede FROM sedes_totales_diarios s2 WHERE s2.idlocal = v.idlocal AND s2.fecha_negocio = v_fecha_ayer), 0)) * 100, 2)::NUMERIC(15,2) as porc_variacion_diaria,
                    (
                        SELECT json_agg(
                            json_build_object(
                                'turno', d.turno_nombre,
                                'monto', d.monto_neta_real::NUMERIC(15,2),
                                'porc_del_local', ROUND((d.monto_neta_real / NULLIF(v.total_dia_sede, 0)) * 100, 2)::NUMERIC(15,2)
                            )
                        )
                        FROM base_calculo_neta d 
                        WHERE d.idlocal = v.idlocal AND d.fecha_negocio = p_fecha_busqueda
                    ) as detalles_turnos,
                    v.prioridad
                FROM ventas_con_config v
                WHERE v.fecha_negocio = p_fecha_busqueda
            ) res_json
        ),
        -- SECCIÓN 2: Analytics (Historico del mes)
        'analytics', (SELECT json_agg(af) FROM analytics_final af)
    );
END;
$function$