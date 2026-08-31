CREATE OR REPLACE FUNCTION public.sp_product_stock_dashboard(
  p_date_from text,
  p_date_to text,
  p_local_number integer
) RETURNS TABLE (resultado jsonb)
LANGUAGE sql
STABLE
AS $function$
WITH movement_base AS MATERIALIZED (
  SELECT
    mp.id_movement_product,
    COALESCE(mp.effective_at, mp.created_at) AS movement_at,
    mp.id_product,
    mp.id_local,
    loc.local_number,
    mp.warehouse_id,
    mp.type AS movement_type_id,
    mp.document_number,
    COALESCE(mp.quantity, 0)::numeric AS quantity,
    mp.created_by
  FROM public.movement_product mp
  INNER JOIN public.local loc ON loc.id_local = mp.id_local
  WHERE mp.state_audit = 1200001
    AND COALESCE(mp.state, 1) = 1
    AND mp.type IN (1400001, 1400002, 1400003, 1400004, 1400005, 1400006)
    AND COALESCE(mp.effective_at, mp.created_at) < (p_date_to::date + 1)
    AND (p_local_number IS NULL OR loc.local_number = p_local_number)
),
normalized AS (
  SELECT *,
    CASE
      WHEN movement_type_id IN (1400002, 1400003) THEN ABS(quantity)
      WHEN movement_type_id IN (1400004, 1400005) AND quantity > 0 THEN quantity
      ELSE 0::numeric
    END AS income,
    CASE
      WHEN movement_type_id IN (1400001, 1400006) THEN ABS(quantity)
      WHEN movement_type_id IN (1400004, 1400005) AND quantity < 0 THEN ABS(quantity)
      ELSE 0::numeric
    END AS output
  FROM movement_base
),
period_rows AS MATERIALIZED (
  SELECT * FROM normalized
  WHERE movement_at >= p_date_from::date
),
stock_by_scope AS (
  SELECT
    id_local, local_number, warehouse_id, id_product,
    SUM(income - output) FILTER (WHERE movement_at < p_date_from::date) AS opening_stock,
    SUM(income) FILTER (WHERE movement_at >= p_date_from::date) AS incomes,
    SUM(output) FILTER (WHERE movement_at >= p_date_from::date) AS outputs,
    SUM(income - output) AS calculated_stock
  FROM normalized
  GROUP BY id_local, local_number, warehouse_id, id_product
),
daily_data AS (
  SELECT TO_CHAR(movement_at::date, 'YYYY-MM-DD') AS date,
    COUNT(*)::int AS movement_count,
    COALESCE(SUM(income), 0)::float AS incomes,
    COALESCE(SUM(output), 0)::float AS outputs
  FROM period_rows GROUP BY movement_at::date
),
product_agg AS (
  SELECT id_product,
    COUNT(*)::int AS movement_count,
    COALESCE(SUM(income), 0)::float AS incomes,
    COALESCE(SUM(output), 0)::float AS outputs
  FROM period_rows
  GROUP BY id_product
  ORDER BY SUM(income + output) DESC
  LIMIT 10
),
product_data AS (
  SELECT pa.id_product::int AS product_id, p.description AS product_name,
    COALESCE(p.measurement_unit, '') AS unit,
    pa.movement_count, pa.incomes, pa.outputs
  FROM product_agg pa
  INNER JOIN public.product p ON p.product_id = pa.id_product
  WHERE COALESCE(p.is_show, true) = true
  ORDER BY pa.incomes + pa.outputs DESC
),
location_agg AS (
  SELECT id_local, local_number, COUNT(*)::int AS movement_count,
    COUNT(DISTINCT id_product)::int AS product_count
  FROM period_rows
  GROUP BY id_local, local_number
),
location_data AS (
  SELECT la.local_number::int AS local_number,
    COALESCE(loc.local_name, loc.name) AS name,
    COALESCE(ol.color_hex, '#94a3b8') AS color,
    la.movement_count, la.product_count
  FROM location_agg la
  INNER JOIN public.local loc ON loc.id_local = la.id_local
  LEFT JOIN public.order_locals ol ON ol.local_number = la.local_number
),
stock_location_data AS (
  SELECT s.local_number::int AS local_number,
    COALESCE(loc.local_name, loc.name) AS local_name,
    COALESCE(ol.color_hex, '#94a3b8') AS local_color,
    COALESCE(w.name, 'Sin almacén') AS warehouse_name,
    s.id_product::int AS product_id, p.description AS product_name,
    COALESCE(p.measurement_unit, '') AS unit,
    COALESCE(s.opening_stock, 0)::float AS opening_stock,
    COALESCE(s.incomes, 0)::float AS incomes,
    COALESCE(s.outputs, 0)::float AS outputs,
    COALESCE(s.calculated_stock, 0)::float AS calculated_stock
  FROM stock_by_scope s
  INNER JOIN public.local loc ON loc.id_local = s.id_local
  INNER JOIN public.product p ON p.product_id = s.id_product
  LEFT JOIN public.warehouse w ON w.id_warehouse = s.warehouse_id
  LEFT JOIN public.order_locals ol ON ol.local_number = s.local_number
  WHERE COALESCE(p.is_show, true) = true
  ORDER BY COALESCE(loc.local_name, loc.name), p.description, w.name
  LIMIT 200
),
recent_rows AS MATERIALIZED (
  SELECT *
  FROM period_rows
  ORDER BY movement_at DESC, id_movement_product
  LIMIT 100
),
recent_data AS (
  SELECT rr.id_movement_product::text AS id,
    TO_CHAR(rr.movement_at, 'YYYY-MM-DD HH24:MI') AS date,
    p.description AS product_name, COALESCE(p.measurement_unit, '') AS unit,
    COALESCE(loc.local_name, loc.name) AS local_name,
    COALESCE(w.name, 'Sin almacén') AS warehouse_name,
    COALESCE(gp.description, 'Movimiento') AS movement_type,
    rr.document_number, rr.quantity::float AS quantity,
    COALESCE(NULLIF(TRIM(CONCAT_WS(' ', person.first_name, person.last_name)), ''),
      NULLIF(TRIM(ua.alias), ''), NULLIF(TRIM(ua.username), ''), 'Sin asignar') AS responsible
  FROM recent_rows rr
  INNER JOIN public.product p ON p.product_id = rr.id_product
  INNER JOIN public.local loc ON loc.id_local = rr.id_local
  LEFT JOIN public.warehouse w ON w.id_warehouse = rr.warehouse_id
  LEFT JOIN public.general_param gp ON gp.table_id = rr.movement_type_id
  LEFT JOIN public.user_auth ua ON ua.id_user = rr.created_by
  LEFT JOIN public.person person ON person.id_person = ua.id_person
)
SELECT jsonb_build_object(
  'totals', jsonb_build_object(
    'movementCount', (SELECT COUNT(*) FROM period_rows),
    'productCount', (SELECT COUNT(DISTINCT id_product) FROM period_rows),
    'warehouseCount', (SELECT COUNT(DISTINCT warehouse_id) FROM period_rows),
    'locationCount', (SELECT COUNT(DISTINCT id_local) FROM period_rows)
  ),
  'daily', COALESCE((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.date) FROM daily_data d), '[]'::jsonb),
  'products', COALESCE((SELECT jsonb_agg(to_jsonb(p)) FROM product_data p), '[]'::jsonb),
  'locations', COALESCE((SELECT jsonb_agg(to_jsonb(l) ORDER BY l.name) FROM location_data l), '[]'::jsonb),
  'stockByLocation', COALESCE((SELECT jsonb_agg(to_jsonb(r)) FROM stock_location_data r), '[]'::jsonb),
  'recentMovements', COALESCE((SELECT jsonb_agg(to_jsonb(m)) FROM recent_data m), '[]'::jsonb)
) AS resultado;
$function$;
