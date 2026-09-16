-- Synchronizes the Reporte Gerencial catalog with the dashboard selector.
-- Inactive menus remain visible but cannot be opened.
DO $$
DECLARE
  v_module_id integer;
  v_menu record;
  v_menu_id integer;
  v_access_id integer;
  v_admin_profile_id integer;
BEGIN
  SELECT id_module
  INTO v_module_id
  FROM public.s_sem_module
  WHERE module_code IN ('report', 'MANAGEMENT_REPORT', 'M2')
    AND state_audit = 1200001
  ORDER BY CASE module_code WHEN 'report' THEN 1 ELSE 2 END
  LIMIT 1;

  IF v_module_id IS NULL THEN
    RAISE EXCEPTION 'No existe el modulo de Reporte Gerencial';
  END IF;

  FOR v_menu IN
    SELECT *
    FROM (VALUES
      ('report.sale.menu',        'REPORT_SALES',        'Ventas',               '/ventas',       'TrendingUp',  1, true,  'Resumen de ventas e indicadores comerciales'),
      ('report.pretty-cash.menu', 'REPORT_CASH_PETTY',   'Caja Chica',           '/caja',         'Wallet',      2, true,  'Movimientos y saldos de caja chica'),
      ('report.shifts.menu',      'REPORT_SHIFTS',       'Turnos',               '/turnos',       'Clock',       3, false, 'Analisis operativo por turnos'),
      ('report.products.menu',    'REPORT_PRODUCTS',     'Productos',            '/productos',    'Package',     4, true,  'Stock y control de combustibles'),
      ('report.credits.menu',     'REPORT_CREDITS',      'Creditos y Adelantos', '/creditos',     'CreditCard',  5, false, 'Cuentas por cobrar y adelantos'),
      ('report.sunat.menu',       'REPORT_SUNAT',        'SUNAT',                 '/sunat',         'FileText',    6, false, 'Cumplimiento y comprobantes electronicos'),
      ('report.pdf.menu',         'REPORT_PDF',          'Reportes PDF',          '/reportes',      'Receipt',     7, false, 'Reportes exportables e impresion'),
      ('report.liquidation.menu', 'REPORT_LIQUIDATIONS', 'Liquidaciones',         '/liquidaciones', 'DollarSign',  8, true,  'Cierres y conciliacion de liquidaciones')
    ) AS catalog(menu_code, menu_key, menu_name, path_key, icon, order_index, is_active, description)
  LOOP
    SELECT id_menu INTO v_menu_id
    FROM public.s_sem_menu
    WHERE menu_code = v_menu.menu_code
    LIMIT 1;

    IF v_menu_id IS NULL THEN
      INSERT INTO public.s_sem_menu (
        menu_code, menu_key, menu_name, level, column_index, parent_id,
        order_index, icon, path_key, description, metadata, module_id,
        is_active, state_audit
      ) VALUES (
        v_menu.menu_code, v_menu.menu_key, v_menu.menu_name, 1, 1, NULL,
        v_menu.order_index, v_menu.icon, v_menu.path_key, v_menu.description,
        jsonb_build_object('icon', v_menu.icon, 'dashboard', true),
        v_module_id, v_menu.is_active, 1200001
      ) RETURNING id_menu INTO v_menu_id;
    ELSE
      UPDATE public.s_sem_menu
      SET menu_key = v_menu.menu_key,
          menu_name = v_menu.menu_name,
          path_key = v_menu.path_key,
          icon = v_menu.icon,
          order_index = v_menu.order_index,
          description = v_menu.description,
          metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('icon', v_menu.icon, 'dashboard', true),
          module_id = v_module_id,
          state_audit = 1200001,
          updated_at = now()
      WHERE id_menu = v_menu_id;
    END IF;

    SELECT id_access INTO v_access_id
    FROM public.s_sem_access
    WHERE access_code = replace(v_menu.menu_code, '.menu', '-menu.read.all')
      AND state_audit = 1200001
    LIMIT 1;

    IF v_access_id IS NULL THEN
      INSERT INTO public.s_sem_access (
        access_code, name, description, resource_key, menu_id,
        accion_id, scope_id, metadata, state_audit
      ) VALUES (
        replace(v_menu.menu_code, '.menu', '-menu.read.all'),
        upper(v_menu.menu_name) || ' - VER',
        'Ver ' || v_menu.menu_name || ' en Reporte Gerencial',
        v_menu.menu_code, v_menu_id, 1910015, 2350007,
        '{"system":"report"}'::jsonb, 1200001
      ) RETURNING id_access INTO v_access_id;
    END IF;

    SELECT id_profile INTO v_admin_profile_id
    FROM public.s_sem_profile
    WHERE module_id = v_module_id
      AND profile_code = 'REPORT_ADMIN'
      AND state_audit = 1200001
    LIMIT 1;

    IF v_admin_profile_id IS NOT NULL THEN
      INSERT INTO public.s_sem_profile_access (
        profile_id, access_id, is_active, state_audit
      ) VALUES (
        v_admin_profile_id, v_access_id, true, 1200001
      )
      ON CONFLICT (profile_id, access_id) DO UPDATE SET
        is_active = true,
        state_audit = 1200001,
        updated_at = now();
    END IF;
  END LOOP;
END
$$;

SELECT menu_name, path_key, is_active, order_index
FROM public.s_sem_menu
WHERE module_id = (
  SELECT id_module
  FROM public.s_sem_module
  WHERE module_code IN ('report', 'MANAGEMENT_REPORT', 'M2')
  ORDER BY CASE module_code WHEN 'report' THEN 1 ELSE 2 END
  LIMIT 1
)
AND state_audit = 1200001
ORDER BY order_index;
