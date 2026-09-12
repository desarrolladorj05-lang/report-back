-- DROP FUNCTION IF EXISTS public.sp_cash_petty_first_by_local(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.sp_cash_petty_report_by_period (
    p_year INT,
    p_month INT
)
RETURNS TABLE (resultado JSON)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_period TEXT;
    v_current_year INT;
    v_current_month INT;
BEGIN

    IF p_month < 1 OR p_month > 12 THEN
        RAISE EXCEPTION 'Mes inválido. Debe estar entre 1 y 12';
    END IF;

    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
    v_current_month := EXTRACT(MONTH FROM CURRENT_DATE)::INT;

    IF p_year > v_current_year OR
       (p_year = v_current_year AND p_month > v_current_month) THEN
        RAISE EXCEPTION 'No se puede consultar periodos futuros';
    END IF;

    v_period := to_char(make_date(p_year, p_month, 1), 'YYYY-MM');

    RETURN QUERY

    WITH data_enriquecida AS (

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
            cpf.created_at,

            e.id_employee,

            COALESCE(p.first_name, '') AS first_name,
            COALESCE(p.last_name, '') AS last_name,

            TRIM(
                COALESCE(p.first_name, '') || ' ' ||
                COALESCE(p.last_name, '')
            ) AS full_name

        FROM cash_petty_fund cpf

        LEFT JOIN employee e
            ON e.id_employee = cpf.responsible_employee_id

        LEFT JOIN person p
            ON p.id_person = e.id_employee

        WHERE cpf.period = v_period
          AND cpf.status_id = 40033
    ),

    sedes_base AS (

        SELECT
            l.id_local,

            COALESCE(
                l.name,
                l.local_name,
                'SIN NOMBRE'
            ) AS local_nombre,

            COALESCE(ol.sort_order, 999) AS prioridad,

            COALESCE(
                ol.color_hex,
                '#94a3b8'
            ) AS color

        FROM local l

        LEFT JOIN order_locals ol
            ON ol.local_number = l.local_number

        WHERE l.is_active = TRUE
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
                        'full_name', d.full_name
                    ),

                    'monto_apertura', d.opening_amount,
                    'total_ingresos', d.total_incomes,
                    'total_egresos', d.total_expenses,
                    'saldo', d.current_balance,
                    'estado', d.status_id
                )

                ORDER BY
                    CASE
                        WHEN d.full_name = '' THEN 1
                        ELSE 0
                    END,
                    d.full_name ASC,
                    d.open_date DESC,
                    d.created_at DESC

            ) FILTER (WHERE d.id IS NOT NULL) AS cajas

        FROM sedes_base s

        LEFT JOIN data_enriquecida d
            ON d.local_id = s.id_local

        GROUP BY
            s.id_local,
            s.local_nombre,
            s.prioridad,
            s.color
    )

    SELECT json_build_object(

        'periodo', v_period,

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