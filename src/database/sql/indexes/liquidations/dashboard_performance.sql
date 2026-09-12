-- Run once per tenant database. These statements are transaction-compatible.
-- These partial indexes match the active rows and joins used by the management dashboards.
-- Existing Backoffice indexes intentionally reused (and therefore not duplicated):
-- idx_sale_fuel_stock_cash_register_local_active,
-- idx_sale_detail_fuel_stock_sale_product_active,
-- idx_liquidation_cash_register_latest_active and
-- idx_daily_report_detail_report.

CREATE INDEX IF NOT EXISTS idx_cash_register_dashboard_opening_active
  ON public.cash_register (opennig_date, id_local, id_cash_register)
  INCLUDE (id_work_shift, cash_register_code, id_user, cash_register_type)
  WHERE state_audit = 1200001;

CREATE INDEX IF NOT EXISTS idx_payment_dashboard_sale_active
  ON public.payment (id_sale)
  INCLUDE (amount, id_payment_method)
  WHERE state = 40001 AND state_audit = 1200001;

CREATE INDEX IF NOT EXISTS idx_deposit_dashboard_cash_active
  ON public.deposit (id_cash_register)
  INCLUDE (total_amount)
  WHERE state = 40001
    AND state_audit = 1200001
    AND code_deposit_type = '0004';

CREATE INDEX IF NOT EXISTS idx_liquidation_group_dashboard_active
  ON public.liquidation_group (id_liquidation)
  INCLUDE (total_collected, total_deposited, payment_method_id, group_id)
  WHERE state_audit = 1200001;

CREATE INDEX IF NOT EXISTS idx_daily_report_dashboard_period_active
  ON public.daily_report (period, id_local, id_daily_report)
  WHERE state_audit = 1200001;

CREATE INDEX IF NOT EXISTS idx_dipstick_dashboard_report_active
  ON public.dipstick (daily_report_id, tank_id)
  INCLUDE (initial_stick, inputs, theoretical_stick, final_stick, difference)
  WHERE state_audit = 1200001;

CREATE INDEX IF NOT EXISTS idx_bank_deposit_daily_report_dashboard
  ON public.bank_deposit_daily_report (daily_report_id, bank_deposit_id)
  INCLUDE (total_deposit_amount);
