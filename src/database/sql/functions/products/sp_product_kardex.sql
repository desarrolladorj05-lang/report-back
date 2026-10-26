DROP FUNCTION IF EXISTS public.sp_product_kardex(text, text, integer);
DROP FUNCTION IF EXISTS public.sp_product_kardex(
  text, text, integer, integer, integer
);
DROP FUNCTION IF EXISTS public.sp_product_kardex(
  text, text, integer, integer, integer, date, date
);

CREATE OR REPLACE FUNCTION public.sp_product_kardex(
  p_date_from text,
  p_date_to text,
  p_product_id integer,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 100,
  p_output_v2_from date DEFAULT NULL,
  p_income_v2_from date DEFAULT NULL
) RETURNS TABLE (resultado jsonb)
LANGUAGE sql
STABLE
AS $function$
WITH normalized AS MATERIALIZED (
  SELECT
    movement.row_id AS id_movement_product,
    movement.movement_at,
    movement.document_number,
    movement.description,
    movement.local_id AS id_local,
    movement.warehouse_id,
    movement.product_id AS id_product,
    movement.movement_type_id,
    movement.sort_key,
    movement.sort_order,
    CASE
      WHEN movement.direction = 'IN' THEN ABS(movement.quantity)
      ELSE 0::numeric
    END AS entry_quantity,
    CASE
      WHEN movement.direction = 'OUT' THEN ABS(movement.quantity)
      ELSE 0::numeric
    END AS exit_quantity
  FROM public.fn_report_inventory_hybrid_movements(
    ((p_date_to::date + 1)::timestamp AT TIME ZONE 'America/Lima')
      - interval '1 microsecond',
    p_output_v2_from,
    p_income_v2_from,
    NULL,
    NULL,
    ARRAY[p_product_id]
  ) movement
  WHERE movement.product_id = p_product_id
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
