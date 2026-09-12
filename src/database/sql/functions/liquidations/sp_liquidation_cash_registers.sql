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
