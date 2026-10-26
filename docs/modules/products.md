# Dashboard de productos

## Endpoints

| Metodo | Ruta | Proposito |
|---|---|---|
| `GET` | `/api/report/products/dashboard` | Resumen de movimientos y stock. |
| `GET` | `/api/report/products/kardex` | Kardex paginado de un producto. |
| `GET` | `/api/report/products/fuel-stock` | Control de stock de combustibles. |

Todos requieren JWT. Los parametros comunes son `dateFrom`, `dateTo` y
`localNumber?`.

El kardex agrega:

- `productId`: entero positivo; si falta, responde `[]`.
- `page`: entero positivo, por defecto `1`.
- `pageSize`: entero positivo, por defecto `100`.

## Propiedad de funciones

`sp_product_stock_dashboard` y `sp_product_kardex` pertenecen a este backend.
El reporte de combustible debe respetar las funciones compartidas de
Backoffice: no se deben reemplazar o modificar desde Reporte Gerencial sin una
coordinacion explicita.

## Corte de inventario

Las fechas por tenant se configuran en
`src/config/tenancy/inventory-version-cutover.config.ts`. En Santa Isabel, las
salidas del dia anterior al corte combinan V1 y V2, eliminan duplicados y
priorizan V2; desde el corte se usa V2. Los ingresos cambian directamente de V1
a V2 en la fecha configurada.

## Rendimiento

Los rangos amplios pueden procesar muchos movimientos. Antes de agregar nuevos
indices se debe comprobar `pg_indexes` y revisar el plan con
`EXPLAIN (ANALYZE, BUFFERS)` sobre una base representativa.

