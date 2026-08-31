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

DROP FUNCTION IF EXISTS public.sp_product_kardex(text, text, integer);

CREATE OR REPLACE FUNCTION public.sp_product_kardex(
  p_date_from text,
  p_date_to text,
  p_product_id integer,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 100
) RETURNS TABLE (resultado jsonb)
LANGUAGE sql
STABLE
AS $function$
WITH normalized AS MATERIALIZED (
  SELECT
    mp.id_movement_product,
    COALESCE(mp.effective_at, mp.created_at) AS movement_at,
    mp.document_number,
    COALESCE(mp.description, '-') AS description,
    mp.id_local,
    mp.warehouse_id,
    mp.id_product,
    mp.type AS movement_type_id,
    COALESCE(mp.id_income::text, mp.id_sale::text, mp.id_movement_product::text) AS sort_key,
    CASE WHEN mp.type IN (1400002, 1400006) THEN 1 ELSE 0 END AS sort_order,
    CASE
      WHEN mp.type IN (1400002, 1400003) THEN ABS(mp.quantity)
      WHEN mp.type IN (1400004, 1400005) AND mp.quantity > 0 THEN mp.quantity
      ELSE 0::numeric
    END AS entry_quantity,
    CASE
      WHEN mp.type IN (1400001, 1400006) THEN ABS(mp.quantity)
      WHEN mp.type IN (1400004, 1400005) AND mp.quantity < 0 THEN ABS(mp.quantity)
      ELSE 0::numeric
    END AS exit_quantity
  FROM public.movement_product mp
  WHERE mp.state_audit = 1200001
    AND COALESCE(mp.state, 1) = 1
    AND mp.id_product = p_product_id
    AND mp.type IN (1400001, 1400002, 1400003, 1400004, 1400005, 1400006)
    AND COALESCE(mp.effective_at, mp.created_at) < (p_date_to::date + 1)
),
opening AS (
  SELECT warehouse_id,
    COALESCE(SUM(entry_quantity - exit_quantity), 0)::numeric AS opening_quantity
  FROM normalized
  WHERE movement_at < p_date_from::date
  GROUP BY warehouse_id
),
period_calculated AS (
  SELECT n.*,
    COALESCE(o.opening_quantity, 0)::numeric AS opening_quantity,
    COALESCE(o.opening_quantity, 0) + SUM(n.entry_quantity - n.exit_quantity) OVER (
      PARTITION BY n.warehouse_id
      ORDER BY n.movement_at, n.sort_key, n.sort_order, n.id_movement_product
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS balance_quantity
  FROM normalized n
  LEFT JOIN opening o ON o.warehouse_id IS NOT DISTINCT FROM n.warehouse_id
  WHERE n.movement_at >= p_date_from::date
),
page_rows AS MATERIALIZED (
  SELECT * FROM period_calculated
  ORDER BY movement_at, sort_key, sort_order, id_movement_product
  LIMIT LEAST(GREATEST(p_page_size, 1), 200)
  OFFSET (GREATEST(p_page, 1) - 1) * LEAST(GREATEST(p_page_size, 1), 200)
),
kardex_rows AS (
  SELECT
    l.id_movement_product::text AS movement_id,
    TO_CHAR(l.movement_at, 'YYYY-MM-DD HH24:MI') AS movement_at,
    COALESCE(l.document_number, '-') AS document_number,
    l.description,
    COALESCE(loc.local_name, loc.name, 'Sin sede') AS local_name,
    l.warehouse_id::text AS warehouse_id,
    COALESCE(w.name, 'Sin almacén') AS warehouse_name,
    l.id_product::int AS product_id,
    p.description AS product_name,
    COALESCE(p.measurement_unit, '') AS unit,
    COALESCE(gp.description, 'Movimiento') AS movement_type_name,
    l.opening_quantity::float AS opening_quantity,
    l.entry_quantity::float AS entry_quantity,
    l.exit_quantity::float AS exit_quantity,
    l.balance_quantity::float AS balance_quantity,
    l.movement_at AS sort_at,
    l.sort_key,
    l.sort_order
  FROM page_rows l
  INNER JOIN public.product p ON p.product_id = l.id_product
  LEFT JOIN public.local loc ON loc.id_local = l.id_local
  LEFT JOIN public.warehouse w ON w.id_warehouse = l.warehouse_id
  LEFT JOIN public.general_param gp ON gp.table_id = l.movement_type_id
)
SELECT jsonb_build_object(
  'page', GREATEST(p_page, 1),
  'pageSize', LEAST(GREATEST(p_page_size, 1), 200),
  'total', (SELECT COUNT(*) FROM period_calculated),
  'rows', COALESCE(jsonb_agg(
    to_jsonb(k) - 'sort_at' - 'sort_key' - 'sort_order'
    ORDER BY k.sort_at, k.sort_key, k.sort_order, k.movement_id
  ), '[]'::jsonb)
)
FROM kardex_rows k;
$function$;
