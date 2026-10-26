CREATE OR REPLACE FUNCTION public.fn_get_cash_registers_by_date(
  p_id_local integer,
  p_fecha_busqueda text
) RETURNS uuid[]
LANGUAGE sql
STABLE
AS $function$
SELECT COALESCE(array_agg(cr.id_cash_register), '{}'::uuid[])
FROM public.cash_register cr
INNER JOIN public.local loc ON loc.id_local = cr.id_local
INNER JOIN public.work_shift ws ON ws.id_work_shift = cr.id_work_shift
WHERE loc.local_number = p_id_local
  AND cr.state_audit = 1200001
  AND cr.opennig_date >= (
    (to_date(p_fecha_busqueda, 'DD/MM/YYYY') - interval '1 day')::timestamp
    AT TIME ZONE 'America/Lima'
  )
  AND cr.opennig_date < (
    (to_date(p_fecha_busqueda, 'DD/MM/YYYY') + interval '2 days')::timestamp
    AT TIME ZONE 'America/Lima'
  )
  AND public.fn_business_date(
    cr.opennig_date,
    ws.start_time,
    ws.end_time
  ) = to_date(p_fecha_busqueda, 'DD/MM/YYYY');
$function$;
