-- Stored Procedure: sp_dashboard_ventas_full
-- Descripción: Obtiene las ventas completas para el dashboard en formato JSONB
-- Parámetros:
--   p_local: ID del local
--   p_desde: Fecha de inicio (YYYY-MM-DD)
--   p_hasta: Fecha de fin (YYYY-MM-DD)

CREATE OR REPLACE FUNCTION sp_dashboard_ventas_full(
    p_local integer,
    p_desde date,
    p_hasta date
)
RETURNS JSONB AS $$
DECLARE
    v_summary JSONB;
    v_details JSONB;
BEGIN
    -- 1. Resumen
    SELECT jsonb_build_object(
        'totalVentas', COUNT(DISTINCT v.id_unico),
        'montoTotal', COALESCE(SUM(v.monto), 0)
    ) INTO v_summary
    FROM vw_mat_reporte_ventas v
    WHERE v.idlocal = p_local
      AND to_date(v.fecha_proceso, 'DD/MM/YYYY') BETWEEN p_desde AND p_hasta;

    -- 2. Detalle
    SELECT jsonb_agg(t) INTO v_details
    FROM (
        SELECT 
            v.fecha_proceso AS fecha,
            v.dsturno AS turno,
            v.dsproducto AS producto,
            SUM(v.monto) AS monto,
            SUM(v.cantidad) AS cantidad
        FROM vw_mat_reporte_ventas v
        WHERE v.idlocal = p_local
          AND to_date(v.fecha_proceso, 'DD/MM/YYYY') BETWEEN p_desde AND p_hasta
        GROUP BY v.fecha_proceso, v.dsturno, v.dsproducto
        ORDER BY v.fecha_proceso
    ) t;

    RETURN jsonb_build_object(
        'summary', COALESCE(v_summary, jsonb_build_object('totalVentas', 0, 'montoTotal', 0)),
        'details', COALESCE(v_details, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql;
