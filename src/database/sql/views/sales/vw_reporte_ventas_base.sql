CREATE OR REPLACE VIEW public.vw_reporte_ventas_base AS
SELECT
  sale.id_sale,
  sale.state,
  sale.total_amount,
  sale.total_discount,
  sale.transferencia_gratuita,
  sale.outstanding_balance,
  sale.id_sale_operation_type,
  sale.id_sale_document_type,
  sale.id_cash_register,
  sale.created_at,
  local.local_number,
  COALESCE(local.local_name, local.name, 'SEDE ' || local.local_number) AS local_nombre_real,
  COALESCE(work_shift.shift_name, 'SIN TURNO') AS nombre_turno,
  to_char(
    CASE
      WHEN upper(COALESCE(work_shift.shift_name, '')) = 'MAÑANA'
        THEN cash_register.opennig_date AT TIME ZONE 'America/Lima'
      WHEN (cash_register.opennig_date AT TIME ZONE 'America/Lima')::time
           < COALESCE(morning_shift.start_time, '07:30:00'::time)
        THEN (cash_register.opennig_date AT TIME ZONE 'America/Lima') - interval '1 day'
      ELSE cash_register.opennig_date AT TIME ZONE 'America/Lima'
    END,
    'DD/MM/YYYY'
  ) AS fecha_negocio
FROM public.sale AS sale
INNER JOIN public.local AS local
  ON local.id_local = sale.id_local
LEFT JOIN public.cash_register AS cash_register
  ON cash_register.id_cash_register = sale.id_cash_register
LEFT JOIN public.work_shift AS work_shift
  ON work_shift.id_work_shift = cash_register.id_work_shift
LEFT JOIN LATERAL (
  SELECT reference.start_time
  FROM public.work_shift AS reference
  WHERE reference.id_local = local.id_local
    AND upper(reference.shift_name) = 'MAÑANA'
    AND reference.state_audit = 1200001
  ORDER BY reference.start_time
  LIMIT 1
) AS morning_shift ON true
WHERE sale.state_audit = 1200001
  AND local.state_audit = 1200001;

COMMENT ON VIEW public.vw_reporte_ventas_base IS
  'Base comun de ventas gerenciales con sede, turno y fecha operativa local.';
