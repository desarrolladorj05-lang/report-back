-- Creates or repairs the administrator profile for Reporte Gerencial.
-- It is safe to execute more than once.
DO $$
DECLARE
  v_module_id integer;
  v_profile_id integer;
BEGIN
  SELECT id_module
  INTO v_module_id
  FROM public.s_sem_module
  WHERE state_audit = 1200001
    AND is_active = true
    AND module_code IN ('report', 'MANAGEMENT_REPORT', 'M2')
  ORDER BY CASE module_code
    WHEN 'report' THEN 1
    WHEN 'MANAGEMENT_REPORT' THEN 2
    ELSE 3
  END
  LIMIT 1;

  IF v_module_id IS NULL THEN
    RAISE EXCEPTION 'No existe el modulo activo de Reporte Gerencial';
  END IF;

  SELECT id_profile
  INTO v_profile_id
  FROM public.s_sem_profile
  WHERE module_id = v_module_id
    AND profile_code = 'REPORT_ADMIN'
  ORDER BY id_profile
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    INSERT INTO public.s_sem_profile (
      profile_code,
      name,
      description,
      module_id,
      metadata,
      is_active,
      state_audit
    )
    VALUES (
      'REPORT_ADMIN',
      'Administrador de Reporte Gerencial',
      'Acceso completo a los reportes gerenciales',
      v_module_id,
      '{"system":"report","role":"admin"}'::jsonb,
      true,
      1200001
    )
    RETURNING id_profile INTO v_profile_id;
  ELSE
    UPDATE public.s_sem_profile
    SET name = 'Administrador de Reporte Gerencial',
        description = 'Acceso completo a los reportes gerenciales',
        metadata = '{"system":"report","role":"admin"}'::jsonb,
        is_active = true,
        state_audit = 1200001,
        updated_at = now()
    WHERE id_profile = v_profile_id;
  END IF;

  INSERT INTO public.s_sem_profile_access (
    profile_id,
    access_id,
    is_active,
    state_audit
  )
  SELECT
    v_profile_id,
    access.id_access,
    true,
    1200001
  FROM public.s_sem_access AS access
  INNER JOIN public.s_sem_menu AS menu
    ON menu.id_menu = access.menu_id
   AND menu.module_id = v_module_id
   AND menu.is_active = true
   AND menu.state_audit = 1200001
  WHERE access.state_audit = 1200001
  ON CONFLICT (profile_id, access_id) DO UPDATE SET
    is_active = true,
    state_audit = 1200001,
    updated_at = now();
END
$$;

-- Verify the profile and its effective accesses.
SELECT
  profile.id_profile,
  profile.profile_code,
  profile.name,
  module.module_code,
  COUNT(profile_access.access_id)::integer AS access_count
FROM public.s_sem_profile AS profile
INNER JOIN public.s_sem_module AS module
  ON module.id_module = profile.module_id
LEFT JOIN public.s_sem_profile_access AS profile_access
  ON profile_access.profile_id = profile.id_profile
 AND profile_access.is_active = true
 AND profile_access.state_audit = 1200001
WHERE profile.profile_code = 'REPORT_ADMIN'
GROUP BY
  profile.id_profile,
  profile.profile_code,
  profile.name,
  module.module_code;
