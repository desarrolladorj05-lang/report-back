CREATE OR REPLACE VIEW public.vw_reporte_ventas_base AS
SELECT
  s.id_sale,
  s.id_local,
  loc.id_local AS id_local_uuid,
  loc.local_number,
  loc.name AS local_nombre_real,
  ws.shift_name AS nombre_turno,
  s.total_amount,
  s.id_sale_operation_type,
  s.transferencia_gratuita,
  s.total_discount,
  s.outstanding_balance,
  s.applied_advance_amount,
  s.state,
  s.id_sale_document_type,
  to_char(
    public.fn_business_date(cr.opennig_date, ws.start_time, ws.end_time),
    'DD/MM/YYYY'
  ) AS fecha_negocio,
  ws."order" AS shift_order
FROM public.sale s
INNER JOIN public.local loc ON loc.id_local = s.id_local
INNER JOIN public.cash_register cr ON cr.id_cash_register = s.id_cash_register
INNER JOIN public.work_shift ws ON ws.id_work_shift = cr.id_work_shift;
