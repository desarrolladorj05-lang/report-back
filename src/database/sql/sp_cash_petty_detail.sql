CREATE 
OR REPLACE FUNCTION public.sp_cash_petty_detail (
    p_cash_petty_id UUID
)
RETURNS TABLE (resultado JSON)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY

    WITH caja AS (
        SELECT 
            cpf.id,
            cpf.local_id,
            l.name AS local_nombre,

            cpf.code,
            cpf.description,
            cpf.period,
            cpf.open_date,
            cpf.close_date,

            cpf.opening_amount,
            cpf.total_expenses,
            cpf.total_replenishments,
            cpf.total_incomes,
            cpf.current_balance,
            cpf.replenish_base_amount,
            cpf.replenish_difference,
            cpf.status_id,
            cpf.created_at,
            cpf.updated_at,
            cpf.created_by,

            e.id_employee,
            COALESCE(p.first_name,'') AS first_name,
            COALESCE(p.last_name,'') AS last_name

        FROM cash_petty_fund cpf
        INNER JOIN local l ON l.id_local = cpf.local_id
        LEFT JOIN employee e ON e.id_employee = cpf.responsible_employee_id
        LEFT JOIN person p ON p.id_person = e.id_employee
        WHERE cpf.id = p_cash_petty_id
    ),

    movimientos_base AS (

        -- 1. APERTURA (movimiento sintético)
        SELECT
            c.id,
            c.open_date AS date,
            c.created_at,
            c.updated_at,

            'INCOME' AS tipo_movimiento,
            'Apertura de caja' AS tipo,

            NULL::uuid AS supplier_id,
            NULL::uuid AS employee_id,
            c.created_by,

            NULL::integer AS document_type_id,
            NULL::varchar AS document_number,

            40001 AS status_id,

            c.opening_amount AS taxable_amount,
            0::numeric AS igv_amount,
            c.opening_amount AS total_amount,

            'Apertura de caja chica' AS observations

        FROM caja c

        UNION ALL

        -- 2. INGRESOS
        SELECT
            i.id,
            i.date,
            i.created_at,
            i.updated_at,

            'INCOME',
            gp.description,

            i.supplier_id,
            i.employee_id,
            i.created_by,

            i.document_type_id,
            i.document_number,

            i.status_id,

            i.taxable_amount,
            i.igv_amount,
            i.total_amount,

            i.observations

        FROM cash_petty_income i
        LEFT JOIN general_param gp ON gp.table_id = i.income_type_id
        WHERE i.petty_fund_id = p_cash_petty_id

        UNION ALL

        -- 3. EGRESOS
        SELECT
            e.id,
            e.date,
            e.created_at,
            e.updated_at,

            'EXPENSE',
            gp.description,

            e.supplier_id,
            e.employee_id,
            e.created_by,

            e.document_type_id,
            e.document_number,

            e.status_id,

            e.taxable_amount,
            e.igv_amount,
            e.total_amount,

            e.observations

        FROM cash_petty_expense e
        LEFT JOIN general_param gp ON gp.table_id = e.expense_type_id
        WHERE e.petty_fund_id = p_cash_petty_id
    ),

    movimientos_timeline AS (
        SELECT
            m.*,
            (m.date::timestamp + m.created_at::time) AS fecha_compuesta
        FROM movimientos_base m
    ),

    movimientos_con_saldo AS (
        SELECT
            m.*,

            SUM(
                CASE 
                    WHEN m.status_id <> 40001 THEN 0
                    WHEN m.tipo_movimiento = 'INCOME' THEN m.total_amount
                    ELSE -m.total_amount
                END
            ) OVER (ORDER BY m.fecha_compuesta ASC) AS balance_after

        FROM movimientos_timeline m
    ),

    movimientos_final AS (
        SELECT
            m.*,
            LAG(m.balance_after, 1, 0) 
                OVER (ORDER BY m.fecha_compuesta ASC) AS balance_before
        FROM movimientos_con_saldo m
    ),

    movimientos_enriquecidos AS (
        SELECT 
            m.*,

            COALESCE(emp.id_employee, sup.id_supplier, ua.id_user) AS entidad_id,

            CASE 
                WHEN m.employee_id IS NOT NULL THEN 'EMPLOYEE'
                WHEN m.supplier_id IS NOT NULL THEN 'SUPPLIER'
                ELSE 'USER'
            END AS entidad_tipo,

            TRIM(
                COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,'')
            ) AS entidad_nombre,

            sdt.name AS documento_tipo

        FROM movimientos_final m
        LEFT JOIN employee emp ON emp.id_employee = m.employee_id
        LEFT JOIN supplier sup ON sup.id_supplier = m.supplier_id
        LEFT JOIN user_auth ua ON ua.id_user = m.created_by
        LEFT JOIN person p 
            ON p.id_person = COALESCE(emp.id_employee, sup.id_supplier, ua.id_person)
        LEFT JOIN sale_document_type sdt 
            ON sdt.id_sale_document_type = m.document_type_id
    )

    SELECT json_build_object(

        -- SEDE
        'sede', json_build_object(
            'idlocal', c.local_id,
            'local_nombre', COALESCE(c.local_nombre, 'SIN NOMBRE')
        ),

        -- CAJA
        'caja', json_build_object(
            'id', c.id,
            'code', c.code,
            'descripcion', c.description,
            'periodo', c.period,
            'fecha_apertura', c.open_date,
            'fecha_cierre', c.close_date,

            'responsable', json_build_object(
                'id', c.id_employee,
                'first_name', c.first_name,
                'last_name', c.last_name,
                'full_name', TRIM(c.first_name || ' ' || c.last_name)
            ),

            'totales', json_build_object(
                'monto_apertura', c.opening_amount,
                'total_ingresos', c.total_incomes,
                'total_egresos', c.total_expenses,
                'total_reposiciones', c.total_replenishments,
                'saldo_actual', c.current_balance,
                'base_reposicion', c.replenish_base_amount,
                'diferencia_reposicion', c.replenish_difference
            ),

            'estado', c.status_id
        ),

        -- MOVIMIENTOS
        'movimientos',
        (
            SELECT json_agg(
                json_build_object(
                    'id', m.id,
                    'fecha', m.fecha_compuesta,
                    'created_at', m.created_at,
                    'updated_at', m.updated_at,
                    'status', m.status_id,
                    'tipo_movimiento', m.tipo_movimiento,
                    'tipo', m.tipo,

                    'entidad', CASE 
                        WHEN m.entidad_id IS NOT NULL THEN json_build_object(
                            'tipo', m.entidad_tipo,
                            'id', m.entidad_id,
                            'nombre', m.entidad_nombre
                        )
                        ELSE NULL
                    END,

                    'documento', CASE 
                        WHEN m.documento_tipo IS NOT NULL THEN json_build_object(
                            'tipo', m.documento_tipo,
                            'numero', m.document_number
                        )
                        ELSE NULL
                    END,

                    'monto', json_build_object(
                        'gravado', m.taxable_amount,
                        'igv', m.igv_amount,
                        'total', m.total_amount
                    ),

                    'observaciones', m.observations,

                    'balance', json_build_object(
                        'before', m.balance_before,
                        'after', m.balance_after
                    )
                )
                ORDER BY m.fecha_compuesta DESC
            )
            FROM movimientos_enriquecidos m
        )

    )
    FROM caja c;

END;
$function$;