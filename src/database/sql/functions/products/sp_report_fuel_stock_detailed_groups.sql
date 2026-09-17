-- =============================================================================
-- sp_report_fuel_stock_detailed_groups
-- Reporte detallado de stock de combustible agrupado por local/producto.
--
-- IDs en duro usados:
--   state_audit = 1200001  → registro activo (auditoría)
--   state = 1              → tanque activo
--   group_product_id = 20006 → grupo de combustibles
--   sale.state = 40001     → venta confirmada
--   id_sale_document_type IN (1, 2) → factura/boleta
--   id_sale_operation_type = 3 → consumo interno
--   id_sale_operation_type = 4 → operación excluida de ventas
--   id_sale_operation_type = 6 → canje
--   cash_register_type = 1970002 → caja BACKOFFICE
--   movement_product.type:
--     1400001 = venta, 1400002 = reembolso venta, 1400003 = compra,
--     1400004 = ajuste, 1400005 = transferencia, 1400006 = reembolso compra
-- Reglas:
--   - Facturas/boletas CANJE no se consideran como ventas del reporte
-- =============================================================================
CREATE OR REPLACE FUNCTION public.sp_report_fuel_stock_detailed_groups(
  p_created_from timestamptz,
  p_created_to timestamptz,
  p_local_ids uuid[] DEFAULT NULL,
  p_warehouse_ids uuid[] DEFAULT NULL,
  p_product_ids int[] DEFAULT NULL
)
RETURNS TABLE(
  local_id text,
  local_name text,
  warehouse_id text,
  warehouse_name text,
  tank_name text,
  product_id int,
  product_name text,
  rows jsonb
)
LANGUAGE sql
STABLE
AS $$
WITH params AS NOT MATERIALIZED (
  SELECT
    p_created_from::date AS created_from,
    p_created_to::date AS created_to,
    CASE
      WHEN p_local_ids IS NULL OR array_length(p_local_ids, 1) = 0 THEN NULL
      ELSE p_local_ids
    END AS local_ids,
    CASE
      WHEN p_warehouse_ids IS NULL OR array_length(p_warehouse_ids, 1) = 0 THEN NULL
      ELSE p_warehouse_ids
    END AS warehouse_ids,
    CASE
      WHEN p_product_ids IS NULL OR array_length(p_product_ids, 1) = 0 THEN NULL
      ELSE p_product_ids
    END AS product_ids
),
-- Tanques activos filtrados por local/almacén/producto
selected_tanks AS (
  SELECT
    t.id AS tank_id,
    t.local_id,
    t.product_id,
    t.warehouse_id,
    COALESCE(NULLIF(l.local_name, ''), NULLIF(l.name, ''), l.id_local::text) AS local_name,
    COALESCE(NULLIF(p.foreign_name, ''), NULLIF(p.description, ''), p.product_id::text) AS product_name,
    COALESCE(NULLIF(w.name, ''), 'SIN ALMACEN') AS warehouse_name,
    COALESCE(NULLIF(t.name, ''), 'SIN TANQUE') AS tank_name
  FROM public.tank t
  JOIN public.product p
    ON p.product_id = t.product_id
   AND COALESCE(p.is_show, true) = true
  JOIN public.local l
    ON l.id_local = t.local_id
  LEFT JOIN public.warehouse w
    ON w.id_warehouse = t.warehouse_id
   AND COALESCE(w.state_audit, 1200001) = 1200001
   AND COALESCE(w.is_active, true) = true
  CROSS JOIN params pr
  WHERE t.state_audit = 1200001
    AND t.state = 1
    AND l.state_audit = 1200001
    AND COALESCE(l.is_active, true) = true
    AND p.state_audit = 1200001
    AND COALESCE(p.is_active, true) = true
    AND p.group_product_id = 20006
    AND (pr.local_ids IS NULL OR t.local_id = ANY(pr.local_ids))
    AND (pr.warehouse_ids IS NULL OR t.warehouse_id = ANY(pr.warehouse_ids))
    AND (pr.product_ids IS NULL OR t.product_id = ANY(pr.product_ids))
),
-- Metadata agrupada por local/producto (fusiona warehouse/tank cuando hay varios)
group_meta AS (
  SELECT
    st.local_id,
    st.local_name,
    st.product_id,
    st.product_name,
    CASE
      WHEN COUNT(DISTINCT COALESCE(st.warehouse_id::text, '__NULL__')) = 1
        THEN COALESCE(
          MAX(st.warehouse_id::text),
          'NO_WAREHOUSE:' || st.local_id::text || ':' || st.product_id::text
        )
      ELSE 'MULTI:' || st.local_id::text || ':' || st.product_id::text
    END AS warehouse_id,
    CASE
      WHEN COUNT(DISTINCT COALESCE(st.warehouse_id::text, '__NULL__')) = 1
        THEN MAX(st.warehouse_name)
      ELSE 'VARIOS'
    END AS warehouse_name,
    CASE
      WHEN COUNT(DISTINCT st.tank_id) = 1 THEN MAX(st.tank_name)
      ELSE 'VARIOS'
    END AS tank_name
  FROM selected_tanks st
  GROUP BY st.local_id, st.local_name, st.product_id, st.product_name
),
-- Productos seleccionados por local para consultar cada venta una sola vez
selected_products_by_local AS (
  SELECT
    gm.local_id,
    array_agg(gm.product_id ORDER BY gm.product_id) AS product_ids
  FROM group_meta gm
  GROUP BY gm.local_id
),
-- Reportes diarios dentro del rango
filtered_reports AS (
  SELECT
    dr.id_daily_report,
    dr.id_local,
    dr.period::date AS report_date
  FROM public.daily_report dr
  CROSS JOIN params p
  WHERE dr.state_audit = 1200001
    AND dr.period::date >= p.created_from
    AND dr.period::date <= p.created_to
    AND (p.local_ids IS NULL OR dr.id_local = ANY(p.local_ids))
),
-- Dipsticks del rango agrupados por reporte/local/producto
dipstick_daily AS (
  SELECT
    fr.id_daily_report,
    fr.report_date,
    st.local_id,
    st.product_id,
    SUM(COALESCE(d.initial_stick, 0))::numeric AS stock_initial,
    SUM(COALESCE(d.inputs, 0))::numeric AS income,
    SUM(COALESCE(d.theoretical_stick, 0))::numeric AS stock_theoretical,
    SUM(COALESCE(d.final_stick, 0))::numeric AS stock_physical,
    SUM(COALESCE(d.difference, 0))::numeric AS difference_day
  FROM filtered_reports fr
  JOIN public.dipstick d
    ON d.daily_report_id = fr.id_daily_report
   AND d.state_audit = 1200001
  JOIN selected_tanks st
    ON st.tank_id = d.tank_id
  GROUP BY fr.id_daily_report, fr.report_date, st.local_id, st.product_id
),
-- Ventas candidatas: cajas vinculadas al parte y cajas BACKOFFICE del mismo
-- local cuya fecha de apertura en Lima corresponde al periodo del parte.
report_sale_candidates AS (
  SELECT
    fr.id_daily_report,
    fr.id_local,
    s.id_sale,
    s.id_sale_operation_type,
    s.id_sale_document_type,
    (cr.cash_register_type = 1970002) AS is_external
  FROM filtered_reports fr
  JOIN public.daily_report_detail drd
    ON drd.daily_report_id = fr.id_daily_report
   AND drd.state_audit = 1200001
  JOIN public.sale s
    ON s.id_cash_register = drd.cash_register_id
   AND s.id_local = fr.id_local
   AND s.state = 40001
   AND s.state_audit = 1200001
  JOIN public.cash_register cr
    ON cr.id_cash_register = s.id_cash_register

  UNION

  SELECT
    fr.id_daily_report,
    fr.id_local,
    s.id_sale,
    s.id_sale_operation_type,
    s.id_sale_document_type,
    true AS is_external
  FROM filtered_reports fr
  JOIN public.cash_register cr
    ON cr.id_local = fr.id_local
   AND cr.cash_register_type = 1970002
   AND cr.opennig_date >= (fr.report_date::timestamp AT TIME ZONE 'America/Lima')
   AND cr.opennig_date < (
     (fr.report_date + 1)::timestamp AT TIME ZONE 'America/Lima'
   )
  JOIN public.sale s
    ON s.id_cash_register = cr.id_cash_register
   AND s.id_local = fr.id_local
   AND s.state = 40001
   AND s.state_audit = 1200001
),
report_sales AS (
  SELECT
    rsc.id_daily_report,
    rsc.id_local,
    rsc.id_sale,
    MAX(rsc.id_sale_operation_type) AS id_sale_operation_type,
    MAX(rsc.id_sale_document_type) AS id_sale_document_type,
    BOOL_OR(rsc.is_external) AS is_external
  FROM report_sale_candidates rsc
  GROUP BY rsc.id_daily_report, rsc.id_local, rsc.id_sale
),
-- Se materializa para que el agregado de ventas se calcule una sola vez y no
-- vuelva a recorrer sale_detail por cada lectura de tanque del período.
sales_daily AS MATERIALIZED (
  SELECT
    rs.id_daily_report,
    rs.id_local AS local_id,
    sd.id_product AS product_id,
    SUM(
      CASE
        WHEN COALESCE(rs.id_sale_operation_type, 0) = 3 THEN COALESCE(sd.quantity, 0)
        ELSE 0
      END
    )::numeric AS internal_consumption,
    SUM(CASE WHEN COALESCE(rs.id_sale_operation_type, 0) = 8 THEN COALESCE(sd.quantity, 0) ELSE 0 END)::numeric AS warehouse_transfer,
    SUM(
      CASE
        WHEN COALESCE(rs.id_sale_operation_type, 0) NOT IN(3, 4, 8)
         AND rs.is_external = false THEN COALESCE(sd.quantity, 0)
        ELSE 0
      END
    )::numeric AS sales,
    SUM(
      CASE
        WHEN COALESCE(rs.id_sale_operation_type, 0) NOT IN(3, 4, 8)
         AND rs.is_external = true THEN COALESCE(sd.quantity, 0)
        ELSE 0
      END
    )::numeric AS external_sales
  FROM report_sales rs
  JOIN selected_products_by_local selected_products
    ON selected_products.local_id = rs.id_local
  -- Join libre para que rangos amplios usen hash/merge en lugar de un lookup por venta
  JOIN public.sale_detail sd
    ON sd.id_sale = rs.id_sale
   AND sd.id_product = ANY(selected_products.product_ids)
   AND sd.state_audit = 1200001
  WHERE NOT (
      COALESCE(rs.id_sale_operation_type, 0) = 6
      AND COALESCE(rs.id_sale_document_type, 0) IN (1, 2)
    )
  GROUP BY rs.id_daily_report, rs.id_local, sd.id_product
),
-- Filas con daily_report (fuente principal)
daily_report_rows AS (
  SELECT
    gm.local_id,
    gm.local_name,
    gm.warehouse_id,
    gm.warehouse_name,
    gm.tank_name,
    gm.product_id,
    gm.product_name,
    dd.report_date,
    dd.stock_initial,
    dd.income,
    COALESCE(sd.internal_consumption, 0)::numeric AS internal_consumption,
    COALESCE(sd.warehouse_transfer, 0)::numeric AS warehouse_transfer,
    COALESCE(sd.sales, 0)::numeric AS sales,
    COALESCE(sd.external_sales, 0)::numeric AS external_sales,
    (
      dd.stock_initial
      + dd.income
      - COALESCE(sd.internal_consumption, 0)
      - COALESCE(sd.warehouse_transfer, 0)
      - COALESCE(sd.sales, 0)
      - COALESCE(sd.external_sales, 0)
    )::numeric AS stock_theoretical,
    dd.stock_physical,
    (
      dd.stock_physical
      - (
        dd.stock_initial
        + dd.income
        - COALESCE(sd.internal_consumption, 0)
        - COALESCE(sd.warehouse_transfer, 0)
        - COALESCE(sd.sales, 0)
        - COALESCE(sd.external_sales, 0)
      )
    )::numeric AS difference_day
  FROM dipstick_daily dd
  JOIN group_meta gm
    ON gm.local_id = dd.local_id
   AND gm.product_id = dd.product_id
  LEFT JOIN sales_daily sd
    ON sd.id_daily_report = dd.id_daily_report
   AND sd.local_id = dd.local_id
   AND sd.product_id = dd.product_id
),
-- Grupos que tienen al menos un día sin daily_report dentro del rango
fallback_windows AS MATERIALIZED (
  SELECT
    gm.local_id,
    gm.product_id,
    MIN(calendar.report_date)::date AS first_missing_date,
    MAX(calendar.report_date)::date AS last_missing_date
  FROM group_meta gm
  CROSS JOIN params p
  CROSS JOIN LATERAL generate_series(
    p.created_from::timestamp,
    p.created_to::timestamp,
    interval '1 day'
  ) AS calendar(report_date)
  WHERE NOT EXISTS (
    SELECT 1
    FROM daily_report_rows drr
    WHERE drr.local_id = gm.local_id
      AND drr.product_id = gm.product_id
      AND drr.report_date = calendar.report_date
  )
  GROUP BY gm.local_id, gm.product_id
),
-- Dipsticks históricos solo para grupos con fallback
historical_dipstick_daily AS MATERIALIZED (
  SELECT
    dr.id_local AS local_id,
    dr.period::date AS report_date,
    st.product_id,
    SUM(COALESCE(d.final_stick, 0))::numeric AS stock_physical
  FROM public.daily_report dr
  JOIN public.dipstick d
    ON d.daily_report_id = dr.id_daily_report
   AND d.state_audit = 1200001
  JOIN selected_tanks st
    ON st.tank_id = d.tank_id
  JOIN fallback_windows fw
    ON fw.local_id = dr.id_local
   AND fw.product_id = st.product_id
  CROSS JOIN params p
  WHERE dr.state_audit = 1200001
    AND dr.period::date >= (p.created_from - interval '90 days')
    AND dr.period::date <= fw.last_missing_date
  GROUP BY dr.id_local, dr.period::date, st.product_id
),
-- Primer dipstick que limita movimientos útiles para cualquier fecha faltante
fallback_bounds AS MATERIALIZED (
  SELECT
    fw.local_id,
    fw.product_id,
    fw.last_missing_date,
    (
      SELECT MAX(hdd.report_date)
      FROM historical_dipstick_daily hdd
      WHERE hdd.local_id = fw.local_id
        AND hdd.product_id = fw.product_id
        AND hdd.report_date < fw.first_missing_date
    ) AS first_anchor_date
  FROM fallback_windows fw
),
-- Ventas de cajas cuya opening_date cae dentro de cada ventana de fallback
fallback_cash_sales AS MATERIALIZED (
  SELECT
    fb.local_id,
    fb.product_id,
    cash_sale.id_sale,
    (selected_cash.opennig_date AT TIME ZONE 'America/Lima')::date AS movement_date,
    cash_sale.id_sale_operation_type AS sale_operation_type,
    cash_sale.id_sale_document_type AS sale_document_type,
    (selected_cash.cash_register_type = 1970002) AS is_external
  FROM fallback_bounds fb
  JOIN LATERAL (
    SELECT
      cr.id_cash_register,
      cr.opennig_date,
      cr.cash_register_type
    FROM public.cash_register cr
    WHERE cr.id_local = fb.local_id
      AND cr.opennig_date >= COALESCE(
        ((fb.first_anchor_date + 1)::timestamp AT TIME ZONE 'America/Lima'),
        '-infinity'::timestamptz
      )
      AND cr.opennig_date
        < ((fb.last_missing_date + 1)::timestamp AT TIME ZONE 'America/Lima')
    -- Mantiene la búsqueda de cajas como paso previo al acceso por id_sale
    OFFSET 0
  ) selected_cash ON true
  JOIN LATERAL (
    SELECT
      s.id_sale,
      s.id_sale_operation_type,
      s.id_sale_document_type
    FROM public.sale s
    WHERE s.id_cash_register = selected_cash.id_cash_register
    -- Evita recorrer movement_product antes de acotar las ventas por caja
    OFFSET 0
  ) cash_sale ON true
),
-- Movimientos cuya fecha efectiva aplica porque no tienen fecha de caja
movement_effective_base AS (
  SELECT
    mp.id_local AS local_id,
    mp.id_product AS product_id,
    (COALESCE(mp.effective_at, mp.created_at) AT TIME ZONE 'America/Lima')::date
      AS movement_date,
    mp.type AS movement_type,
    COALESCE(mp.quantity, 0)::numeric AS quantity,
    s.id_sale_operation_type AS sale_operation_type,
    s.id_sale_document_type AS sale_document_type,
    COALESCE(cr.cash_register_type = 1970002, false) AS is_external
  FROM fallback_bounds fb
  CROSS JOIN params p
  JOIN public.movement_product mp
    ON mp.id_local = fb.local_id
   AND mp.id_product = fb.product_id
   -- Rango exacto de la fecha efectiva, indexable y equivalente al corte por fecha Lima
   AND COALESCE(mp.effective_at, mp.created_at) >= COALESCE(
     ((fb.first_anchor_date + 1)::timestamp AT TIME ZONE 'America/Lima'),
     '-infinity'::timestamptz
   )
   AND COALESCE(mp.effective_at, mp.created_at)
     < ((fb.last_missing_date + 1)::timestamp AT TIME ZONE 'America/Lima')
  LEFT JOIN public.sale s
    ON s.id_sale = mp.id_sale
  LEFT JOIN public.cash_register cr
    ON cr.id_cash_register = s.id_cash_register
  WHERE mp.state_audit = 1200001
    AND mp.id_product IS NOT NULL
    AND mp.type IN (1400001, 1400002, 1400003, 1400004, 1400005, 1400006)
    -- Conserva la ventana histórica original basada en created_at
    AND mp.created_at >= ((p.created_from - interval '90 days') AT TIME ZONE 'America/Lima')
    AND mp.created_at < ((p.created_to + interval '2 days') AT TIME ZONE 'America/Lima')
    -- Si existe fecha de caja, la fila se resuelve por la rama siguiente
    AND cr.opennig_date IS NULL
),
-- Movimientos de ventas cuya fecha aplicable proviene de la apertura de caja
movement_cash_base AS (
  SELECT
    mp.id_local AS local_id,
    mp.id_product AS product_id,
    fcs.movement_date,
    mp.type AS movement_type,
    COALESCE(mp.quantity, 0)::numeric AS quantity,
    fcs.sale_operation_type,
    fcs.sale_document_type,
    fcs.is_external
  FROM fallback_cash_sales fcs
  CROSS JOIN params p
  JOIN LATERAL (
    SELECT
      sale_movement.id_local,
      sale_movement.id_product,
      sale_movement.type,
      sale_movement.quantity
    FROM public.movement_product sale_movement
    WHERE sale_movement.id_sale = fcs.id_sale
      AND sale_movement.id_local = fcs.local_id
      AND sale_movement.id_product = fcs.product_id
      AND sale_movement.state_audit = 1200001
      AND sale_movement.id_sale IS NOT NULL
      AND sale_movement.id_product IS NOT NULL
      AND sale_movement.type IN (1400001, 1400002, 1400003, 1400004, 1400005, 1400006)
      -- Conserva exactamente las cotas históricas originales de movement_product
      AND sale_movement.created_at
        >= ((p.created_from - interval '90 days') AT TIME ZONE 'America/Lima')
      AND sale_movement.created_at
        < ((p.created_to + interval '2 days') AT TIME ZONE 'America/Lima')
    -- Fuerza el lookup compuesto id_sale/local/producto después de acotar las cajas
    OFFSET 0
  ) mp ON true
),
-- Las ramas son excluyentes: opening_date no nulo usa siempre la fecha de caja
movement_base AS (
  SELECT * FROM movement_effective_base
  UNION ALL
  SELECT * FROM movement_cash_base
),
-- Se materializa porque el saldo de cada fecha faltante reutiliza este conjunto.
-- Así se evita reconstruir las ventas y movimientos para cada fila del reporte.
movement_daily AS MATERIALIZED (
  SELECT
    mb.local_id,
    mb.product_id,
    mb.movement_date,
    COALESCE(SUM(
      CASE
        WHEN mb.movement_type IN (1400002, 1400003) THEN ABS(mb.quantity)
        WHEN mb.movement_type IN (1400004, 1400005) AND mb.quantity > 0 THEN mb.quantity
        ELSE 0
      END
    ), 0)::numeric AS income,
    COALESCE(SUM(
      CASE
        WHEN mb.movement_type = 1400001
         AND COALESCE(mb.sale_operation_type, 0) = 3
          THEN ABS(mb.quantity)
        WHEN mb.movement_type = 1400006 THEN ABS(mb.quantity)
        WHEN mb.movement_type IN (1400004, 1400005) AND mb.quantity < 0
          THEN ABS(mb.quantity)
        ELSE 0
      END
    ), 0)::numeric AS internal_consumption,
    COALESCE(SUM(CASE
      WHEN mb.movement_type = 1400001 AND COALESCE(mb.sale_operation_type, 0) = 8
      THEN ABS(mb.quantity) ELSE 0 END
    ), 0)::numeric AS warehouse_transfer,
    COALESCE(SUM(
      CASE
        WHEN mb.movement_type = 1400001
         AND COALESCE(mb.sale_operation_type, 0) NOT IN (3, 4, 8)
         AND mb.is_external = false
         AND NOT (
           COALESCE(mb.sale_operation_type, 0) = 6
           AND COALESCE(mb.sale_document_type, 0) IN (1, 2)
         )
          THEN ABS(mb.quantity)
        ELSE 0
      END
    ), 0)::numeric AS sales,
    COALESCE(SUM(
      CASE
        WHEN mb.movement_type = 1400001
         AND COALESCE(mb.sale_operation_type, 0) NOT IN (3, 4, 8)
         AND mb.is_external = true
         AND NOT (
           COALESCE(mb.sale_operation_type, 0) = 6
           AND COALESCE(mb.sale_document_type, 0) IN (1, 2)
         )
          THEN ABS(mb.quantity)
        ELSE 0
      END
    ), 0)::numeric AS external_sales
  FROM movement_base mb
  GROUP BY mb.local_id, mb.product_id, mb.movement_date
),
-- Movimientos del rango con net_change y stock_initial calculado via window function
movement_range_with_initial AS (
  SELECT
    md.local_id,
    md.product_id,
    md.movement_date AS report_date,
    md.income,
    md.internal_consumption,
    md.warehouse_transfer,
    md.sales,
    md.external_sales,
    (
      md.income - md.internal_consumption - md.warehouse_transfer - md.sales - md.external_sales
    )::numeric AS net_change
  FROM movement_daily md
  CROSS JOIN params p
  WHERE md.movement_date BETWEEN p.created_from AND p.created_to
    AND NOT EXISTS (
      SELECT 1
      FROM daily_report_rows drr
      WHERE drr.local_id = md.local_id
        AND drr.product_id = md.product_id
        AND drr.report_date = md.movement_date
    )
),
-- Último dipstick antes de cada fecha de fallback
last_dipstick_lookup AS (
  SELECT
    mdr.local_id,
    mdr.product_id,
    mdr.report_date,
    last_dipstick.stock_physical AS last_dipstick_physical,
    last_dipstick.report_date AS last_dipstick_date
  FROM movement_range_with_initial mdr
  LEFT JOIN LATERAL (
    SELECT
      hdd.stock_physical,
      hdd.report_date
    FROM historical_dipstick_daily hdd
    WHERE hdd.local_id = mdr.local_id
      AND hdd.product_id = mdr.product_id
      AND hdd.report_date < mdr.report_date
    ORDER BY hdd.report_date DESC
    LIMIT 1
  ) last_dipstick ON true
),
-- Cambio neto acumulado entre el último dipstick y cada fecha
net_before_per_day AS MATERIALIZED (
  SELECT
    ldl.local_id,
    ldl.product_id,
    ldl.report_date,
    COALESCE(ldl.last_dipstick_physical, 0)::numeric AS dipstick_physical,
    COALESCE(
      SUM(
        md.income - md.internal_consumption - md.warehouse_transfer - md.sales - md.external_sales
      ),
      0
    )::numeric AS net_change_before
  FROM last_dipstick_lookup ldl
  LEFT JOIN movement_daily md
    ON md.local_id = ldl.local_id
   AND md.product_id = ldl.product_id
   AND md.movement_date < ldl.report_date
   AND (ldl.last_dipstick_date IS NULL OR md.movement_date > ldl.last_dipstick_date)
  GROUP BY ldl.local_id, ldl.product_id, ldl.report_date, ldl.last_dipstick_physical
),
-- Filas de fallback (días sin daily_report pero con movimientos)
fallback_rows AS (
  SELECT
    gm.local_id,
    gm.local_name,
    gm.warehouse_id,
    gm.warehouse_name,
    gm.tank_name,
    gm.product_id,
    gm.product_name,
    mdr.report_date,
    (COALESCE(nbp.dipstick_physical, 0) + COALESCE(nbp.net_change_before, 0))::numeric AS stock_initial,
    mdr.income,
    mdr.internal_consumption,
    mdr.warehouse_transfer,
    mdr.sales,
    mdr.external_sales,
    (COALESCE(nbp.dipstick_physical, 0) + COALESCE(nbp.net_change_before, 0) + mdr.net_change)::numeric AS stock_theoretical,
    (COALESCE(nbp.dipstick_physical, 0) + COALESCE(nbp.net_change_before, 0) + mdr.net_change)::numeric AS stock_physical,
    0::numeric AS difference_day
  FROM movement_range_with_initial mdr
  JOIN group_meta gm
    ON gm.local_id = mdr.local_id
   AND gm.product_id = mdr.product_id
  LEFT JOIN net_before_per_day nbp
    ON nbp.local_id = mdr.local_id
   AND nbp.product_id = mdr.product_id
   AND nbp.report_date = mdr.report_date
),
all_rows AS (
  SELECT * FROM daily_report_rows
  UNION ALL
  SELECT * FROM fallback_rows
)
SELECT
  ar.local_id::text AS local_id,
  ar.local_name,
  ar.warehouse_id,
  ar.warehouse_name,
  ar.tank_name,
  ar.product_id,
  ar.product_name,
  jsonb_agg(
    jsonb_build_object(
      'date', to_char(ar.report_date, 'YYYY-MM-DD'),
      'stockInitial', ar.stock_initial,
      'income', ar.income,
      'internalConsumption', ar.internal_consumption,
      'warehouseTransfer', ar.warehouse_transfer,
      'sales', ar.sales,
      'externalSales', ar.external_sales,
      'stockTheoretical', ar.stock_theoretical,
      'stockPhysical', ar.stock_physical,
      'differenceDay', ar.difference_day
    )
    ORDER BY ar.report_date
  ) AS rows
FROM all_rows ar
GROUP BY
  ar.local_id,
  ar.local_name,
  ar.warehouse_id,
  ar.warehouse_name,
  ar.tank_name,
  ar.product_id,
  ar.product_name
ORDER BY ar.local_name, ar.warehouse_name, ar.product_name;
$$;
