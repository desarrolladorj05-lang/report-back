-- Lightweight comparison query. The dashboard only needs these totals for the
-- previous period, so this avoids calculating methods, deposits and rankings twice.
CREATE OR REPLACE FUNCTION public.sp_liquidation_period_totals(
  p_date_from text,
  p_date_to text,
  p_local_number integer
) RETURNS TABLE (
  total_to_render double precision,
  total_collected double precision,
  difference double precision,
  liquidation_count integer,
  compliant_count integer,
  pending_count integer
)
LANGUAGE sql
STABLE
AS $function$
WITH scope AS MATERIALIZED (
  SELECT
    cr.id_cash_register,
    CASE
      WHEN UPPER(TRIM(ws.shift_name)) = 'MAÑANA'
        THEN (cr.opennig_date AT TIME ZONE 'America/Lima')::date
      WHEN (cr.opennig_date AT TIME ZONE 'America/Lima')::time
        < COALESCE(ws_ref.start_time, '07:30:00'::time)
        THEN ((cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day')::date
      ELSE (cr.opennig_date AT TIME ZONE 'America/Lima')::date
    END AS business_date
  FROM public.cash_register cr
  INNER JOIN public.local loc ON loc.id_local = cr.id_local
  LEFT JOIN public.work_shift ws ON ws.id_work_shift = cr.id_work_shift
  LEFT JOIN LATERAL (
    SELECT morning.start_time
    FROM public.work_shift morning
    WHERE morning.id_local = loc.id_local
      AND UPPER(TRIM(morning.shift_name)) = 'MAÑANA'
    ORDER BY morning.start_time
    LIMIT 1
  ) ws_ref ON TRUE
  WHERE cr.state_audit = 1200001
    AND cr.opennig_date >= (
      (p_date_from::date - interval '1 day')::timestamp AT TIME ZONE 'America/Lima'
    )
    AND cr.opennig_date < (
      (p_date_to::date + interval '2 days')::timestamp AT TIME ZONE 'America/Lima'
    )
    AND CASE
      WHEN UPPER(TRIM(ws.shift_name)) = 'MAÑANA'
        THEN (cr.opennig_date AT TIME ZONE 'America/Lima')::date
      WHEN (cr.opennig_date AT TIME ZONE 'America/Lima')::time
        < COALESCE(ws_ref.start_time, '07:30:00'::time)
        THEN ((cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day')::date
      ELSE (cr.opennig_date AT TIME ZONE 'America/Lima')::date
    END BETWEEN p_date_from::date AND p_date_to::date
    AND (p_local_number IS NULL OR loc.local_number = p_local_number)
),
valid_payment_methods AS MATERIALIZED (
  SELECT id_payment_method
  FROM public.payment_method
  WHERE is_active = TRUE
    AND state_audit = 1200001
    AND id_payment_method NOT IN (4, 7, 8, 9, 10)
),
scoped_sales AS MATERIALIZED (
  SELECT s.id_sale, s.id_cash_register
  FROM scope sc
  INNER JOIN public.sale s ON s.id_cash_register = sc.id_cash_register
    AND s.state = 40001 AND s.state_audit = 1200001
    AND COALESCE(s.id_sale_operation_type, 0) <> 4
    AND NOT (COALESCE(s.id_sale_operation_type, 0) = 6
      AND COALESCE(s.id_sale_document_type, 0) IN (1, 2))
),
payments_by_cash AS MATERIALIZED (
  SELECT ss.id_cash_register, p.amount, p.id_payment_method
  FROM scoped_sales ss
  INNER JOIN public.payment p ON p.id_sale = ss.id_sale
    AND p.state = 40001 AND p.state_audit = 1200001
    AND p.id_payment_method NOT IN (4, 7, 8, 9, 10)
),
sales_by_cash AS (
  SELECT p.id_cash_register, COALESCE(SUM(p.amount), 0)::numeric AS total_sales
  FROM payments_by_cash p
  INNER JOIN valid_payment_methods pm
    ON pm.id_payment_method = p.id_payment_method
  GROUP BY p.id_cash_register
),
other_income_by_cash AS (
  SELECT sc.id_cash_register, COALESCE(SUM(d.total_amount), 0)::numeric AS other_income
  FROM scope sc
  INNER JOIN public.deposit d ON d.id_cash_register = sc.id_cash_register
    AND d.state = 40001 AND d.state_audit = 1200001
    AND d.code_deposit_type = '0004'
  GROUP BY sc.id_cash_register
),
collected_by_cash AS (
  SELECT
    sc.id_cash_register,
    COALESCE(SUM(lg.total_collected), 0)::numeric AS total_collected
  FROM scope sc
  INNER JOIN public.liquidation liq ON liq.id_cash_register = sc.id_cash_register
    AND liq.state_audit = 1200001
  INNER JOIN public.liquidation_group lg ON lg.id_liquidation = liq.id_liquidation
    AND lg.state_audit = 1200001
  GROUP BY sc.id_cash_register
),
per_cash AS (
  SELECT
    COALESCE(s.total_sales, 0) + COALESCE(oi.other_income, 0) AS total_to_render,
    c.total_collected,
    c.total_collected - (COALESCE(s.total_sales, 0) + COALESCE(oi.other_income, 0)) AS difference
  FROM scope sc
  INNER JOIN collected_by_cash c ON c.id_cash_register = sc.id_cash_register
  LEFT JOIN sales_by_cash s ON s.id_cash_register = sc.id_cash_register
  LEFT JOIN other_income_by_cash oi ON oi.id_cash_register = sc.id_cash_register
)
SELECT
  COALESCE(SUM(total_to_render), 0)::float,
  COALESCE(SUM(total_collected), 0)::float,
  COALESCE(SUM(difference), 0)::float,
  COUNT(*)::int,
  COUNT(*) FILTER (WHERE ROUND(ABS(difference), 2) = 0)::int,
  COUNT(*) FILTER (WHERE ROUND(ABS(difference), 2) > 0)::int
FROM per_cash;
$function$;
