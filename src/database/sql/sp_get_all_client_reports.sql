CREATE
OR REPLACE FUNCTION public.sp_get_all_client_reports_by_date (
  p_id_local integer,
  p_fecha_busqueda text,
  p_id_concepto integer DEFAULT NULL::integer,
  p_id_turno integer DEFAULT NULL::integer
) RETURNS TABLE (resultado jsonb) LANGUAGE plpgsql AS $function$
DECLARE
    v_cash_registers UUID[];
    v_nombre_turno_busqueda TEXT;
BEGIN
    -- 1. Traducir el ID manual al nombre que entiende la base de datos
    v_nombre_turno_busqueda := CASE 
        WHEN p_id_turno = 1 THEN 'MAÑANA'
        WHEN p_id_turno = 2 THEN 'TARDE'
        WHEN p_id_turno = 3 THEN 'NOCHE'
        WHEN p_id_turno = 4 THEN 'MADRUGADA'
        ELSE NULL 
    END;

    -- 2. Obtener IDs de cajas filtrando por turno si corresponde
    -- Modificamos la lógica de obtención de cajas para que respete el turno
    SELECT array_agg(cr.id_cash_register) INTO v_cash_registers
    FROM public.cash_register cr
    JOIN public.local l ON cr.id_local = l.id_local
    JOIN public.work_shift ws ON cr.id_work_shift = ws.id_work_shift
    WHERE (p_id_local IS NULL OR l.local_number = p_id_local)
      AND cr.state_audit = 1200001
      AND to_char((cr.opennig_date AT TIME ZONE 'America/Lima'), 'DD/MM/YYYY') = p_fecha_busqueda
      -- Si v_nombre_turno_busqueda es NULL, trae todos los turnos
      AND (v_nombre_turno_busqueda IS NULL OR UPPER(TRIM(ws.shift_name)) = v_nombre_turno_busqueda);

    RETURN QUERY
    WITH base_datos AS (
        SELECT 
            s.id_sale_operation_type,
            s.created_at,
            jsonb_build_object(
                'nro_documento', COALESCE(pe.document_number, c.document_number, s.client_snapshot ->> 'documentNumber', '-'),
                'nombre_cliente', TRIM(CONCAT_WS(' ', COALESCE(pe.first_name, c.first_name, s.client_snapshot ->> 'firstName', ''), COALESCE(pe.last_name, c.last_name, s.client_snapshot ->> 'lastName', ''))),
                'placa', COALESCE(v.vehicle_plate, s.vehicle_snapshot ->> 'plate', '-'),
                'chofer', TRIM(CONCAT_WS(' ', COALESCE(d.first_name, s.driver_snapshot ->> 'firstName', ''), COALESCE(d.last_name, s.driver_snapshot ->> 'lastName', ''))),
                'nro_comprobante', COALESCE(s.document_number, CONCAT(s.serie, '-', LPAD(COALESCE(s.number, 0)::text, 8, '0'))),
                'producto', COALESCE(p.description, sd.product_snapshot ->> 'description', 'PRODUCTO'),
                'cantidad', TO_CHAR(COALESCE(sd.quantity, 0), 'FM9999990.00'),
                'importe', TO_CHAR(COALESCE(sd.total_amount, 0), 'FM9999990.00'),
                'monto_descuento', CASE WHEN sd.discount > 0 THEN TO_CHAR(sd.discount, 'FM9999990.00') ELSE NULL END
            ) as fila_data,
            (sd.discount > 0 OR sd.discount_id IS NOT NULL) as es_descuento,
            (s.id_sale_operation_type = 5 OR s.transferencia_gratuita > 0) as es_transferencia
        FROM public.sale_detail sd
        JOIN public.sale s ON s.id_sale = sd.id_sale
        LEFT JOIN public.product p ON p.product_id = sd.id_product
        LEFT JOIN public.client c ON c.id_client = s.id_client
        LEFT JOIN public.person pe ON pe.id_person = c.id_client
        LEFT JOIN public.vehicle v ON v.id_vehicle = s.id_vehicle
        LEFT JOIN public.driver d ON d.id_driver = s.id_driver
        WHERE s.id_cash_register = ANY(v_cash_registers)
          AND s.state = 40001 AND s.state_audit = 1200001
    ),
    seccion_descuentos AS (
        SELECT jsonb_agg(fila_data ORDER BY created_at) as lista 
        FROM base_datos WHERE es_descuento AND (p_id_concepto IS NULL OR p_id_concepto = 0)
    ),
    seccion_transferencias AS (
        SELECT jsonb_agg(fila_data - 'monto_descuento' ORDER BY created_at) as lista 
        FROM base_datos WHERE es_transferencia AND (p_id_concepto IS NULL OR p_id_concepto = 5)
    ),
    seccion_creditos AS (
        SELECT jsonb_agg(fila_data - 'monto_descuento' ORDER BY created_at) as lista 
        FROM base_datos WHERE id_sale_operation_type = 2 AND NOT es_transferencia AND (p_id_concepto IS NULL OR p_id_concepto = 2)
    ),
    seccion_adelantos AS (
        SELECT jsonb_agg(fila_data - 'monto_descuento' ORDER BY created_at) as lista 
        FROM base_datos WHERE id_sale_operation_type = 7 AND (p_id_concepto IS NULL OR p_id_concepto = 7)
    ),
    seccion_interno AS (
        SELECT jsonb_agg(fila_data - 'monto_descuento' ORDER BY created_at) as lista 
        FROM base_datos WHERE id_sale_operation_type = 3 AND (p_id_concepto IS NULL OR p_id_concepto = 3)
    ),
    seccion_canje AS (
        SELECT jsonb_agg(fila_data - 'monto_descuento' ORDER BY created_at) as lista 
        FROM base_datos WHERE id_sale_operation_type = 6 AND (p_id_concepto IS NULL OR p_id_concepto = 6)
    )
    SELECT jsonb_build_object(
        'descuentos', COALESCE((SELECT lista FROM seccion_descuentos), '[]'::jsonb),
        'transferencias', COALESCE((SELECT lista FROM seccion_transferencias), '[]'::jsonb),
        'creditos', COALESCE((SELECT lista FROM seccion_creditos), '[]'::jsonb),
        'adelantos', COALESCE((SELECT lista FROM seccion_adelantos), '[]'::jsonb),
        'consumo_interno', COALESCE((SELECT lista FROM seccion_interno), '[]'::jsonb),
        'canjes', COALESCE((SELECT lista FROM seccion_canje), '[]'::jsonb)
    );
END;
$function$