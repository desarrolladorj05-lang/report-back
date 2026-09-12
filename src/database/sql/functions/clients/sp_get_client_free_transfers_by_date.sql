CREATE OR REPLACE FUNCTION public.sp_get_client_free_transfers_by_date(
    p_id_local integer, 
    p_fecha_busqueda text
)
RETURNS TABLE (
    nro_documento_identidad text,
    nombre_cliente text,
    placa text,
    chofer text,
    nro_comprobante text,
    nombre_producto text,
    cantidad_galones numeric,
    importe numeric
) 
LANGUAGE plpgsql AS $function$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(pe.document_number, c.document_number, s.client_snapshot ->> 'documentNumber', '-')::text AS nro_documento_identidad,
        TRIM(CONCAT_WS(' ', 
            COALESCE(pe.first_name, c.first_name, s.client_snapshot ->> 'firstName', ''),
            COALESCE(pe.last_name, c.last_name, s.client_snapshot ->> 'lastName', '')
        ))::text AS nombre_cliente,
        COALESCE(v.vehicle_plate, s.vehicle_snapshot ->> 'plate', '-')::text AS placa,
        TRIM(CONCAT_WS(' ',
            COALESCE(d.first_name, s.driver_snapshot ->> 'firstName', ''),
            COALESCE(d.last_name, s.driver_snapshot ->> 'lastName', '')
        ))::text AS chofer,
        COALESCE(s.document_number, CONCAT(s.serie, '-', LPAD(COALESCE(s.number, 0)::text, 8, '0')))::text AS nro_comprobante,
        COALESCE(p.description, sd.product_snapshot ->> 'description', 'PRODUCTO NO IDENTIF.')::text AS nombre_producto,
        COALESCE(sd.quantity, 0)::numeric AS cantidad_galones,
        COALESCE(sd.total_amount, 0)::numeric AS importe
    FROM public.sale_detail sd
    JOIN public.sale s ON s.id_sale = sd.id_sale
    LEFT JOIN public.product p ON p.product_id = sd.id_product
    LEFT JOIN public.client c ON c.id_client = s.id_client
    LEFT JOIN public.person pe ON pe.id_person = c.id_client
    LEFT JOIN public.vehicle v ON v.id_vehicle = s.id_vehicle
    LEFT JOIN public.driver d ON d.id_driver = s.id_driver
    WHERE s.id_cash_register = ANY(public.fn_get_cash_registers_by_date(p_id_local, p_fecha_busqueda))
      AND s.state = 40001           
      AND s.state_audit = 1200001   
      AND (s.id_sale_operation_type = 2 OR s.transferencia_gratuita > 0)
    ORDER BY s.created_at ASC;
END;
$function$;