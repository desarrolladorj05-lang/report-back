CREATE OR REPLACE VIEW public.vw_reporte_pagos_detalle AS
SELECT
  payment.id_sale,
  payment.amount,
  method.name AS metodo_nombre,
  payment.id_payment_method,
  payment.state AS payment_state
FROM public.payment payment
INNER JOIN public.payment_method method
  ON method.id_payment_method = payment.id_payment_method;
