
DROP FUNCTION IF EXISTS public.fn_report_inventory_hybrid_movements(
  timestamptz, date, date, uuid[], uuid[], integer[]
);

CREATE OR REPLACE FUNCTION public.fn_report_inventory_hybrid_movements(
  p_movement_to timestamptz,
  p_output_v2_from date DEFAULT NULL,
  p_income_v2_from date DEFAULT NULL,
  p_local_ids uuid[] DEFAULT NULL,
  p_warehouse_ids uuid[] DEFAULT NULL,
  p_product_ids integer[] DEFAULT NULL
) RETURNS TABLE (
  row_id uuid,
  movement_at timestamptz,
  local_id uuid,
  warehouse_id uuid,
  product_id integer,
  movement_type_id integer,
  document_number text,
  description text,
  quantity numeric,
  direction text,
  sale_id uuid,
  sale_operation_type integer,
  sale_document_type integer,
  cash_register_id uuid,
  cash_opening_at timestamptz,
  is_external boolean,
  created_by uuid,
  sort_key text,
  sort_order integer
)
LANGUAGE sql
STABLE
AS $$
WITH params AS (
  SELECT CASE
    WHEN p_output_v2_from IS NULL THEN NULL
    ELSE p_output_v2_from - 1
  END AS output_hybrid_date
),
default_warehouse AS (
  SELECT DISTINCT ON (pl.id_local, pl.product_id)
    pl.id_local,
    pl.product_id,
    pl.warehouse_id
  FROM public.product_local pl
  WHERE pl.state_audit = 1200001
    AND pl.warehouse_id IS NOT NULL
  ORDER BY pl.id_local, pl.product_id, pl.warehouse_id
),
legacy_raw AS (
  SELECT
    mp.id_movement_product AS row_id,
    COALESCE(mp.effective_at, mp.created_at) AS movement_at,
    mp.id_local AS local_id,
    COALESCE(mp.warehouse_id, dw.warehouse_id) AS warehouse_id,
    mp.id_product AS product_id,
    mp.type AS movement_type_id,
    COALESCE(mp.document_number, ii.document_number, ii.number, '-')::text
      AS document_number,
    COALESCE(mp.description, iid.note, ii.note, '-')::text AS description,
    CASE
      WHEN mp.type IN (1400002, 1400003)
        OR (mp.type IN (1400004, 1400005) AND mp.quantity > 0)
        THEN ABS(COALESCE(mp.quantity, 0))
      ELSE -ABS(COALESCE(mp.quantity, 0))
    END::numeric AS quantity,
    CASE
      WHEN mp.type IN (1400002, 1400003)
        OR (mp.type IN (1400004, 1400005) AND mp.quantity > 0)
        THEN 'IN'
      ELSE 'OUT'
    END::text AS direction,
    mp.id_sale AS sale_id,
    NULL::integer AS sale_operation_type,
    NULL::integer AS sale_document_type,
    NULL::uuid AS cash_register_id,
    NULL::timestamptz AS cash_opening_at,
    false AS is_external,
    mp.created_by,
    COALESCE(mp.id_income::text, mp.id_sale::text, mp.id_movement_product::text)
      AS sort_key,
    CASE WHEN mp.type IN (1400002, 1400006) THEN 1 ELSE 0 END AS sort_order,
    (COALESCE(mp.effective_at, mp.created_at) AT TIME ZONE 'America/Lima')::date
      AS movement_date,
    (
      CASE
        WHEN mp.sale_detail_id IS NOT NULL
          THEN 'SALE_DETAIL:' || mp.sale_detail_id::text
        WHEN mp.income_detail_id IS NOT NULL
          THEN 'INCOME_DETAIL:' || mp.income_detail_id::text
        WHEN mp.id_sale IS NOT NULL
          THEN 'SALE:' || mp.id_sale::text || ':' || mp.id_product::text
        WHEN mp.id_income IS NOT NULL
          THEN 'INCOME:' || mp.id_income::text || ':' || mp.id_product::text
        ELSE CONCAT_WS(
          ':',
          'FALLBACK',
          NULLIF(BTRIM(mp.document_number), ''),
          mp.id_local::text,
          COALESCE(mp.warehouse_id, dw.warehouse_id)::text,
          mp.id_product::text,
          ABS(COALESCE(mp.quantity, 0))::text,
          (COALESCE(mp.effective_at, mp.created_at) AT TIME ZONE 'America/Lima')::date::text
        )
      END
      || ':' ||
      CASE
        WHEN mp.type IN (1400002, 1400003)
          OR (mp.type IN (1400004, 1400005) AND mp.quantity > 0)
          THEN 'IN'
        ELSE 'OUT'
      END
    )::text AS match_key
  FROM public.movement_product mp
  LEFT JOIN default_warehouse dw
    ON dw.id_local = mp.id_local
   AND dw.product_id = mp.id_product
  LEFT JOIN public.inventory_income ii ON ii.id_inventory_income = mp.id_income
  LEFT JOIN public.inventory_income_detail iid
    ON iid.id_income_detail = mp.income_detail_id
  CROSS JOIN params
  WHERE mp.state_audit = 1200001
    AND COALESCE(mp.state, 1) = 1
    AND mp.id_product IS NOT NULL
    AND mp.type IN (1400001, 1400002, 1400003, 1400004, 1400005, 1400006)
    AND COALESCE(mp.effective_at, mp.created_at) <= p_movement_to
    AND (COALESCE(cardinality(p_local_ids), 0) = 0 OR mp.id_local = ANY(p_local_ids))
    AND (
      COALESCE(cardinality(p_warehouse_ids), 0) = 0
      OR COALESCE(mp.warehouse_id, dw.warehouse_id) = ANY(p_warehouse_ids)
    )
    AND (COALESCE(cardinality(p_product_ids), 0) = 0 OR mp.id_product = ANY(p_product_ids))
    AND (
      (
        (
          mp.type IN (1400002, 1400003)
          OR (mp.type IN (1400004, 1400005) AND mp.quantity > 0)
        )
        AND p_income_v2_from IS NOT NULL
        AND (COALESCE(mp.effective_at, mp.created_at) AT TIME ZONE 'America/Lima')::date
          < p_income_v2_from
      )
      OR (
        NOT (
          mp.type IN (1400002, 1400003)
          OR (mp.type IN (1400004, 1400005) AND mp.quantity > 0)
        )
        AND params.output_hybrid_date IS NOT NULL
        AND (COALESCE(mp.effective_at, mp.created_at) AT TIME ZONE 'America/Lima')::date
          <= params.output_hybrid_date
      )
    )
),
v2_raw AS (
  SELECT
    d.inventory_movement_detail_id AS row_id,
    m.movement_at,
    d.local_id,
    d.warehouse_id,
    d.product_id,
    COALESCE(d.movement_type_id, m.movement_type_id) AS movement_type_id,
    COALESCE(m.document_number, ii.document_number, ii.number, io.number, '-')::text
      AS document_number,
    COALESCE(d.note, m.description, m.reason, iod.note, io.note, '-')::text
      AS description,
    CASE
      WHEN d.direction = 'IN' THEN ABS(COALESCE(d.quantity, 0))
      ELSE -ABS(COALESCE(d.quantity, 0))
    END::numeric AS quantity,
    d.direction::text,
    COALESCE(sd.id_sale, m.sale_id) AS sale_id,
    NULL::integer AS sale_operation_type,
    NULL::integer AS sale_document_type,
    d.cash_register_id,
    NULL::timestamptz AS cash_opening_at,
    false AS is_external,
    COALESCE(d.created_by, m.created_by) AS created_by,
    m.inventory_movement_id::text AS sort_key,
    0 AS sort_order,
    (m.movement_at AT TIME ZONE 'America/Lima')::date AS movement_date,
    (
      CASE
        WHEN d.sale_detail_id IS NOT NULL
          THEN 'SALE_DETAIL:' || d.sale_detail_id::text
        WHEN d.income_detail_id IS NOT NULL
          THEN 'INCOME_DETAIL:' || d.income_detail_id::text
        WHEN m.sale_id IS NOT NULL
          THEN 'SALE:' || m.sale_id::text || ':' || d.product_id::text
        WHEN m.income_id IS NOT NULL
          THEN 'INCOME:' || m.income_id::text || ':' || d.product_id::text
        ELSE CONCAT_WS(
          ':',
          'FALLBACK',
          NULLIF(BTRIM(m.document_number), ''),
          d.local_id::text,
          d.warehouse_id::text,
          d.product_id::text,
          ABS(COALESCE(d.quantity, 0))::text,
          (m.movement_at AT TIME ZONE 'America/Lima')::date::text
        )
      END
      || ':' || d.direction
    )::text AS match_key
  FROM public.inventory_movement m
  JOIN public.inventory_movement_detail d
    ON d.inventory_movement_id = m.inventory_movement_id
   AND d.state_audit = 1200001
  LEFT JOIN public.sale_detail sd ON sd.id_sale_detail = d.sale_detail_id
  LEFT JOIN public.inventory_income ii ON ii.id_inventory_income = m.income_id
  LEFT JOIN public.inventory_output io
    ON io.id_inventory_output = m.inventory_output_id
  LEFT JOIN public.inventory_output_detail iod
    ON iod.id_inventory_output_detail = d.inventory_output_detail_id
  CROSS JOIN params
  WHERE m.state_audit = 1200001
    AND COALESCE(m.status_id, 40001) IN (40001, 40044)
    AND m.reversal_of_movement_id IS NULL
    AND d.reversal_of_detail_id IS NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.inventory_movement reversal
      WHERE reversal.reversal_of_movement_id = m.inventory_movement_id
        AND reversal.state_audit = 1200001
    )
    AND m.movement_at <= p_movement_to
    AND (COALESCE(cardinality(p_local_ids), 0) = 0 OR d.local_id = ANY(p_local_ids))
    AND (COALESCE(cardinality(p_warehouse_ids), 0) = 0 OR d.warehouse_id = ANY(p_warehouse_ids))
    AND (COALESCE(cardinality(p_product_ids), 0) = 0 OR d.product_id = ANY(p_product_ids))
    AND (
      (
        d.direction = 'IN'
        AND (
          p_income_v2_from IS NULL
          OR (m.movement_at AT TIME ZONE 'America/Lima')::date >= p_income_v2_from
        )
      )
      OR (
        d.direction = 'OUT'
        AND (
          params.output_hybrid_date IS NULL
          OR (m.movement_at AT TIME ZONE 'America/Lima')::date >= params.output_hybrid_date
        )
      )
    )
),
legacy_hybrid_ranked AS (
  SELECT
    legacy_raw.*,
    ROW_NUMBER() OVER (
      PARTITION BY legacy_raw.match_key
      ORDER BY legacy_raw.movement_at, legacy_raw.row_id
    ) AS occurrence
  FROM legacy_raw
  CROSS JOIN params
  WHERE legacy_raw.direction = 'OUT'
    AND legacy_raw.movement_date = params.output_hybrid_date
),
v2_hybrid_ranked AS (
  SELECT
    v2_raw.*,
    ROW_NUMBER() OVER (
      PARTITION BY v2_raw.match_key
      ORDER BY v2_raw.movement_at, v2_raw.row_id
    ) AS occurrence
  FROM v2_raw
  CROSS JOIN params
  WHERE v2_raw.direction = 'OUT'
    AND v2_raw.movement_date = params.output_hybrid_date
),
selected_legacy AS (
  SELECT legacy_raw.*
  FROM legacy_raw
  CROSS JOIN params
  WHERE (
      direction = 'IN'
      AND p_income_v2_from IS NOT NULL
      AND movement_date < p_income_v2_from
    )
    OR (
      direction = 'OUT'
      AND params.output_hybrid_date IS NOT NULL
      AND movement_date < params.output_hybrid_date
    )
  UNION ALL
  SELECT
    legacy.row_id,
    legacy.movement_at,
    legacy.local_id,
    legacy.warehouse_id,
    legacy.product_id,
    legacy.movement_type_id,
    legacy.document_number,
    legacy.description,
    legacy.quantity,
    legacy.direction,
    legacy.sale_id,
    legacy.sale_operation_type,
    legacy.sale_document_type,
    legacy.cash_register_id,
    legacy.cash_opening_at,
    legacy.is_external,
    legacy.created_by,
    legacy.sort_key,
    legacy.sort_order,
    legacy.movement_date,
    legacy.match_key
  FROM legacy_hybrid_ranked legacy
  WHERE NOT EXISTS (
    SELECT 1
    FROM v2_hybrid_ranked current
    WHERE current.match_key = legacy.match_key
      AND current.occurrence = legacy.occurrence
  )
),
selected_v2 AS (
  SELECT v2_raw.*
  FROM v2_raw
  CROSS JOIN params
  WHERE (
      direction = 'IN'
      AND (p_income_v2_from IS NULL OR movement_date >= p_income_v2_from)
    )
    OR (
      direction = 'OUT'
      AND (
        params.output_hybrid_date IS NULL
        OR movement_date >= params.output_hybrid_date
      )
    )
),
combined AS (
  SELECT * FROM selected_legacy
  UNION ALL
  SELECT * FROM selected_v2
)
SELECT
  row_id,
  movement_at,
  local_id,
  warehouse_id,
  product_id,
  movement_type_id,
  document_number,
  description,
  quantity,
  direction,
  sale_id,
  sale_operation_type,
  sale_document_type,
  cash_register_id,
  cash_opening_at,
  is_external,
  created_by,
  sort_key,
  sort_order
FROM combined;
$$;
