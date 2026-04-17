CREATE OR 
REPLACE FUNCTION public.sp_cash_petty_first_by_local (
    p_fecha_inicio TEXT,
    p_fecha_fin TEXT
)
RETURNS TABLE (resultado JSON)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha_inicio_date DATE;
    v_fecha_fin_date DATE;
BEGIN
    -- 1. Preparación de fechas
    v_fecha_inicio_date := to_date(p_fecha_inicio, 'DD/MM/YYYY');
    v_fecha_fin_date := to_date(p_fecha_fin, 'DD/MM/YYYY');

    RETURN QUERY
    WITH cajas_filtradas AS (
        SELECT 
            cpf.*,
            ROW_NUMBER() OVER (
                PARTITION BY cpf.local_id 
                ORDER BY cpf.created_at DESC
            ) AS rn
        FROM cash_petty_fund cpf
        WHERE cpf.created_at >= v_fecha_inicio_date
        AND cpf.created_at < (v_fecha_fin_date + INTERVAL '1 day')
    ),
    primeras_cajas AS (
        SELECT *
        FROM cajas_filtradas
        WHERE rn = 1
    ),
    data_enriquecida AS (
        SELECT 
            cpf.local_id,

            cpf.id,
            cpf.code,
            cpf.period,
            cpf.open_date,
            cpf.close_date,
            cpf.opening_amount,
            cpf.total_incomes,
            cpf.total_expenses,
            cpf.current_balance,
            cpf.status_id,

            e.id_employee,
            COALESCE(p.first_name, '') AS first_name,
            COALESCE(p.last_name, '') AS last_name

        FROM primeras_cajas cpf
        LEFT JOIN employee e ON e.id_employee = cpf.responsible_employee_id
        LEFT JOIN person p ON p.id_person = e.id_employee
    ),
    sedes_base AS (
        SELECT 
            l.id_local,
            COALESCE(l.name, l.local_name, 'SIN NOMBRE') AS local_nombre,
            COALESCE(ol.sort_order, 999) AS prioridad,
            COALESCE(ol.color_hex, '#94a3b8') AS color
            FROM local l
            LEFT JOIN order_locals ol 
                ON ol.local_number = l.local_number
            WHERE COALESCE(l.local_code, '') <> 'SY01'
            AND l.is_active = TRUE
    ),
    json_por_sede AS (
        SELECT 
            s.id_local,
            s.local_nombre,
            s.prioridad,
            s.color,
            json_agg(
                json_build_object(
                    'id', d.id,
                    'code', d.code,
                    'periodo', d.period,
                    'fecha_apertura', d.open_date,
                    'fecha_cierre', d.close_date,
                    'responsable', json_build_object(
                        'id', d.id_employee,
                        'first_name', d.first_name,
                        'last_name', d.last_name,
                        'full_name', trim(d.first_name || ' ' || d.last_name)
                    ),
                    'monto_apertura', d.opening_amount,
                    'total_ingresos', d.total_incomes,
                    'total_egresos', d.total_expenses,
                    'saldo', d.current_balance,
                    'estado', d.status_id
                )
            ) FILTER (WHERE d.id IS NOT NULL) AS cajas

        FROM sedes_base s
        LEFT JOIN data_enriquecida d ON d.local_id = s.id_local
        GROUP BY s.id_local, s.local_nombre, s.prioridad, s.color
    )

    SELECT json_build_object(
        'fecha_inicio', p_fecha_inicio,
        'fecha_fin', p_fecha_fin,
        'sedes',
        json_agg(
            json_build_object(
                'idlocal', j.id_local,
                'local_nombre', j.local_nombre,
                'color', j.color,
                'cajas', COALESCE(j.cajas, '[]'::json)
            )
            ORDER BY j.prioridad ASC
        )
    )
    FROM json_por_sede j;

END;
$function$;