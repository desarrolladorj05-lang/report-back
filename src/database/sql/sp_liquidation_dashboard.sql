CREATE OR REPLACE FUNCTION public.sp_liquidation_dashboard(
  p_date_from text,
  p_date_to text,
  p_local_number integer,
  p_include_details boolean DEFAULT false
) RETURNS TABLE (resultado jsonb)
LANGUAGE sql
STABLE
AS $function$
WITH scope AS MATERIALIZED (
  SELECT
    cr.id_cash_register,
    cr.cash_register_code,
    CASE
      WHEN UPPER(TRIM(ws.shift_name)) = 'MAÑANA'
        THEN (cr.opennig_date AT TIME ZONE 'America/Lima')::date
      WHEN (cr.opennig_date AT TIME ZONE 'America/Lima')::time
        < COALESCE(ws_ref.start_time, '07:30:00'::time)
        THEN ((cr.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day')::date
      ELSE (cr.opennig_date AT TIME ZONE 'America/Lima')::date
    END AS business_date,
    loc.local_number,
    COALESCE(loc.local_name, loc.name, 'Sede ' || loc.local_number) AS local_name,
    COALESCE(ol.color_hex, '#94a3b8') AS local_color,
    COALESCE(ol.sort_order, 999) AS local_sort_order,
    COALESCE(
      NULLIF(TRIM(CONCAT_WS(' ', person.first_name, person.last_name)), ''),
      NULLIF(TRIM(box_user.alias), ''),
      NULLIF(TRIM(box_user.username), ''),
      'Sin asignar'
    ) AS responsible
  FROM public.cash_register cr
  INNER JOIN public.local loc ON loc.id_local = cr.id_local
  LEFT JOIN public.order_locals ol ON ol.local_number = loc.local_number
  LEFT JOIN public.user_auth box_user
    ON box_user.id_user = cr.id_user AND box_user.state_audit = 1200001
  LEFT JOIN public.person person
    ON person.id_person = box_user.id_person AND person.state_audit = 1200001
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
    -- Pre-filter using the raw column so an index on opennig_date can be used.
    -- The extra day preserves overnight shifts whose business date is previous.
    AND cr.opennig_date >= (
      (p_date_from::date - interval '1 day')::timestamp
      AT TIME ZONE 'America/Lima'
    )
    AND cr.opennig_date < (
      (p_date_to::date + interval '2 days')::timestamp
      AT TIME ZONE 'America/Lima'
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
sales_by_cash AS (
  SELECT sc.id_cash_register, COALESCE(SUM(p.amount), 0)::numeric AS total_sales
  FROM scope sc
  INNER JOIN public.sale s ON s.id_cash_register = sc.id_cash_register
    AND s.state = 40001 AND s.state_audit = 1200001
    AND COALESCE(s.id_sale_operation_type, 0) <> 4
    AND NOT (COALESCE(s.id_sale_operation_type, 0) = 6
      AND COALESCE(s.id_sale_document_type, 0) IN (1, 2))
  INNER JOIN public.payment p ON p.id_sale = s.id_sale
    AND p.state = 40001 AND p.state_audit = 1200001
  INNER JOIN public.payment_method pm ON pm.id_payment_method = p.id_payment_method
    AND pm.is_active = TRUE AND pm.state_audit = 1200001
    AND pm.id_payment_method NOT IN (4, 7, 8, 9, 10)
  GROUP BY sc.id_cash_register
),
other_income_by_cash AS (
  SELECT sc.id_cash_register, COALESCE(SUM(d.total_amount), 0)::numeric AS other_income
  FROM scope sc
  INNER JOIN public.deposit d ON d.id_cash_register = sc.id_cash_register
    AND d.state = 40001 AND d.state_audit = 1200001
    AND d.code_deposit_type = '0004'
  GROUP BY sc.id_cash_register
),
liquidation_rows AS MATERIALIZED (
  SELECT
    sc.id_cash_register,
    liq.id_liquidation,
    lg.total_collected,
    lg.total_deposited,
    lg.payment_method_id,
    lg.group_id
  FROM scope sc
  INNER JOIN public.liquidation liq ON liq.id_cash_register = sc.id_cash_register
    AND liq.state_audit = 1200001
  INNER JOIN public.liquidation_group lg ON lg.id_liquidation = liq.id_liquidation
    AND lg.state_audit = 1200001
),
collected_by_cash AS (
  SELECT
    id_cash_register,
    COALESCE(SUM(total_collected), 0)::numeric AS total_collected
  FROM liquidation_rows
  GROUP BY id_cash_register
),
per_cash AS (
  SELECT
    sc.id_cash_register,
    sc.cash_register_code,
    sc.business_date,
    sc.local_number,
    sc.local_name,
    sc.local_color,
    sc.local_sort_order,
    sc.responsible,
    COALESCE(s.total_sales, 0) + COALESCE(oi.other_income, 0) AS total_to_render,
    c.total_collected,
    c.total_collected - (COALESCE(s.total_sales, 0) + COALESCE(oi.other_income, 0)) AS difference
  FROM scope sc
  INNER JOIN collected_by_cash c ON c.id_cash_register = sc.id_cash_register
  LEFT JOIN sales_by_cash s ON s.id_cash_register = sc.id_cash_register
  LEFT JOIN other_income_by_cash oi ON oi.id_cash_register = sc.id_cash_register
),
daily_data AS (
  SELECT
    TO_CHAR(business_date, 'YYYY-MM-DD') AS date,
    COALESCE(SUM(total_to_render), 0)::float AS total_to_render,
    COALESCE(SUM(total_collected), 0)::float AS total_collected,
    COALESCE(SUM(difference), 0)::float AS difference,
    COUNT(*)::int AS liquidation_count
  FROM per_cash
  GROUP BY business_date
),
method_data AS (
  SELECT
    COALESCE(pm.name, gp.description, 'OTROS') AS name,
    COALESCE(SUM(lr.total_collected), 0)::float AS collected,
    COALESCE(SUM(lr.total_deposited), 0)::float AS deposited,
    COALESCE(SUM(lr.total_collected - lr.total_deposited), 0)::float AS difference
  FROM liquidation_rows lr
  LEFT JOIN public.payment_method pm ON pm.id_payment_method = lr.payment_method_id
  LEFT JOIN public.general_param gp ON gp.table_id = lr.group_id
  GROUP BY 1
  HAVING COALESCE(SUM(lr.total_collected), 0) > 0
),
location_data AS (
  SELECT
    local_number::int AS local_number,
    local_name AS name,
    local_color AS color,
    local_sort_order AS sort_order,
    COALESCE(SUM(total_to_render), 0)::float AS total_to_render,
    COALESCE(SUM(total_collected), 0)::float AS total_collected,
    COALESCE(SUM(difference), 0)::float AS difference,
    COUNT(*)::int AS liquidation_count,
    COUNT(*) FILTER (WHERE ABS(difference) < 0.01)::int AS compliant_count,
    COUNT(*) FILTER (WHERE ABS(difference) >= 0.01)::int AS pending_count
  FROM per_cash
  GROUP BY local_number, local_name, local_color, local_sort_order
),
location_ranking_data AS (
  SELECT
    local_number::text AS key,
    local_name AS label,
    COUNT(*)::int AS count,
    COALESCE(SUM(ABS(difference)), 0)::float AS amount
  FROM per_cash
  WHERE ABS(difference) >= 0.01
  GROUP BY local_number, local_name
  ORDER BY amount DESC
  LIMIT 5
),
responsible_ranking_data AS (
  SELECT
    responsible AS key,
    responsible AS label,
    MIN(local_name) AS detail,
    COUNT(*)::int AS count,
    COALESCE(SUM(ABS(difference)), 0)::float AS amount
  FROM per_cash
  WHERE ABS(difference) >= 0.01
  GROUP BY responsible
  ORDER BY amount DESC
  LIMIT 5
),
cash_data AS (
  SELECT
    id_cash_register::text AS id,
    TO_CHAR(business_date, 'YYYY-MM-DD') AS date,
    local_number::int AS local_number,
    local_name AS location,
    cash_register_code::int AS cash_register_code,
    responsible,
    total_to_render::float AS total_to_render,
    total_collected::float AS total_collected,
    difference::float AS difference
  FROM per_cash
)
SELECT jsonb_build_object(
  'daily', CASE WHEN p_include_details THEN '[]'::jsonb ELSE
    COALESCE((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.date) FROM daily_data d), '[]'::jsonb) END,
  'methods', CASE WHEN p_include_details THEN '[]'::jsonb ELSE
    COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.collected DESC) FROM method_data m), '[]'::jsonb) END,
  'locations', CASE WHEN p_include_details THEN '[]'::jsonb ELSE
    COALESCE((SELECT jsonb_agg(to_jsonb(l) ORDER BY l.sort_order, l.name) FROM location_data l), '[]'::jsonb) END,
  'rankings', CASE WHEN p_include_details THEN '{}'::jsonb ELSE jsonb_build_object(
    'locations', COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.amount DESC) FROM location_ranking_data r), '[]'::jsonb),
    'responsibles', COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.amount DESC) FROM responsible_ranking_data r), '[]'::jsonb)
  ) END,
  'cashRegisters', CASE WHEN p_include_details THEN
    COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.date DESC, c.location, c.id) FROM cash_data c), '[]'::jsonb)
    ELSE '[]'::jsonb END
) AS resultado;
$function$;

CREATE OR REPLACE FUNCTION public.sp_liquidation_cash_registers(
  p_date_from text,
  p_date_to text,
  p_local_number integer
) RETURNS TABLE (resultado jsonb)
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object(
    'cashRegisters', COALESCE(d.resultado->'cashRegisters', '[]'::jsonb)
  )
  FROM public.sp_liquidation_dashboard(
    p_date_from,
    p_date_to,
    p_local_number,
    true
  ) d;
$function$;
