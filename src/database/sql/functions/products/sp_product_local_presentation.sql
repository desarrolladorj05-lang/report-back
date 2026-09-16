CREATE OR REPLACE FUNCTION public.sp_product_local_presentation(
  p_local_ids uuid[]
) RETURNS TABLE (
  id_local uuid,
  color_hex text,
  sort_order integer
)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    loc.id_local,
    COALESCE(ordering.color_hex, '#94A3B8')::text AS color_hex,
    COALESCE(ordering.sort_order, 999)::integer AS sort_order
  FROM public.local AS loc
  LEFT JOIN public.order_locals AS ordering
    ON ordering.local_number = loc.local_number
  WHERE loc.id_local = ANY(p_local_ids)
    AND loc.state_audit = 1200001;
$function$;

