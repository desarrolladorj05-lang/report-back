-- Run once per tenant database with autocommit enabled.
-- This is complementary to idx_movement_product_fuel_stock_active_local_product_effective:
-- that index starts with id_local; this one supports ranges across every location.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_movement_product_stock_dashboard_effective
  ON public.movement_product (
    (COALESCE(effective_at, created_at)),
    id_local,
    id_product,
    warehouse_id
  )
  INCLUDE (type, quantity)
  WHERE state_audit = 1200001
    AND COALESCE(state, 1) = 1
    AND id_product IS NOT NULL
    AND type IN (1400001, 1400002, 1400003, 1400004, 1400005, 1400006);
