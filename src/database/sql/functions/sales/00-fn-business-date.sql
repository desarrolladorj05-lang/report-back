CREATE OR REPLACE FUNCTION public.fn_business_date(
  p_opened_at timestamptz,
  p_shift_start time without time zone,
  p_shift_end time without time zone,
  p_timezone text DEFAULT 'America/Lima'
) RETURNS date
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $function$
  SELECT CASE
    WHEN p_opened_at IS NULL THEN NULL
    WHEN p_shift_start > p_shift_end
      AND (p_opened_at AT TIME ZONE p_timezone)::time < p_shift_end
      THEN ((p_opened_at AT TIME ZONE p_timezone) - interval '1 day')::date
    ELSE (p_opened_at AT TIME ZONE p_timezone)::date
  END;
$function$;
