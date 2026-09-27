CREATE OR REPLACE FUNCTION public.sp_commercial_sales_report(
  p_date_from date,
  p_date_to date,
  p_local_ids uuid[] DEFAULT NULL
) RETURNS TABLE (
  sale_date date,
  local_id uuid,
  local_number integer,
  local_name text,
  local_color text,
  local_order integer,
  product_id integer,
  product_name text,
  amount numeric,
  gallons numeric
) LANGUAGE sql STABLE AS $function$
WITH scoped_sales AS MATERIALIZED (
  SELECT
    s.id_sale,
    l.id_local,
    l.local_number,
    COALESCE(l.local_name, l.name, 'Sede ' || l.local_number) AS local_name,
    COALESCE(ol.color_hex, '#94A3B8') AS local_color,
    COALESCE(ol.sort_order, 999) AS local_order,
    s.id_sale_operation_type,
    s.transferencia_gratuita,
    CASE
      WHEN ws.shift_name = 'MAÑANA' THEN
        (cr.opennig_date AT TIME ZONE 'America/Lima')::date
      WHEN EXTRACT(hour FROM cr.opennig_date AT TIME ZONE 'America/Lima') < 7.5 THEN
        ((cr.opennig_date AT TIME ZONE 'America/Lima') - INTERVAL '1 day')::date
      ELSE (cr.opennig_date AT TIME ZONE 'America/Lima')::date
    END AS sale_date
  FROM public.sale s
  INNER JOIN public.local l ON l.id_local = s.id_local
  INNER JOIN public.cash_register cr ON cr.id_cash_register = s.id_cash_register
  INNER JOIN public.work_shift ws ON ws.id_work_shift = cr.id_work_shift
  LEFT JOIN public.order_locals ol ON ol.local_number = l.local_number
  WHERE s.created_at >= p_date_from::timestamptz - INTERVAL '1 day'
    AND s.created_at < (p_date_to + 2)::timestamptz
    AND s.state = 40001
    AND s.state_audit = 1200001
    AND (p_local_ids IS NULL OR l.id_local = ANY(p_local_ids))
),
fuel_sales AS (
  SELECT
    ss.sale_date,
    ss.id_local,
    ss.local_number,
    ss.local_name,
    ss.local_color,
    ss.local_order,
    sd.id_product AS product_id,
    COALESCE(p.foreign_name, sd.product_snapshot->>'description', 'Producto') AS product_name,
    CASE
      WHEN ss.id_sale_operation_type IN (3, 4)
        OR COALESCE(ss.transferencia_gratuita, 0) > 0 THEN 0
      ELSE COALESCE(sd.total_amount, 0)
    END AS amount,
    CASE
      WHEN ss.id_sale_operation_type = 4 THEN 0
      ELSE COALESCE(sd.quantity, 0)
    END AS gallons
  FROM scoped_sales ss
  INNER JOIN public.sale_detail sd ON sd.id_sale = ss.id_sale
  LEFT JOIN public.product p ON p.product_id = sd.id_product
  WHERE ss.sale_date BETWEEN p_date_from AND p_date_to
    AND (sd.product_snapshot->>'groupProductId')::integer = 20006
)
SELECT
  fs.sale_date,
  fs.id_local,
  fs.local_number,
  fs.local_name,
  fs.local_color,
  fs.local_order,
  fs.product_id,
  fs.product_name,
  SUM(fs.amount)::numeric(18, 2) AS amount,
  SUM(fs.gallons)::numeric(18, 3) AS gallons
FROM fuel_sales fs
GROUP BY
  fs.sale_date,
  fs.id_local,
  fs.local_number,
  fs.local_name,
  fs.local_color,
  fs.local_order,
  fs.product_id,
  fs.product_name
ORDER BY fs.sale_date, fs.local_order, fs.product_name;
$function$;
