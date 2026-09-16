# Documentacion de Reporte Gerencial API

Documentacion tecnica del backend que alimenta los tableros gerenciales de
ventas, caja chica, liquidaciones y stock de productos.

## Estado actual

La API usa autenticacion JWT, resuelve el tenant por dominio o por el
`tenantId` firmado y ejecuta consultas en la base PostgreSQL correspondiente.
Los reportes principales se apoyan en funciones SQL versionadas en el mismo
repositorio.

## Modulos disponibles

| Modulo | Prefijo HTTP | Fuente principal |
|---|---|---|
| Autenticacion | `/api/auth` | Master y base tenant |
| Ventas | `/api/report` | Funciones SQL de ventas |
| Caja chica | `/api/cash-petty` | Funciones SQL de caja chica |
| Liquidaciones | `/api/report/liquidations` | Dashboard y detalle de cajas |
| Productos | `/api/report/products` | Movimientos, kardex y combustible |

## Ruta recomendada

1. [Configuracion local](getting-started/local-setup.md)
2. [Arquitectura](architecture/overview.md)
3. [Multitenancy](tenancy/overview.md)
4. [Funciones e indices SQL](database/sql-objects.md)
5. [Catalogo de modulos](modules/sales.md)

## Criterio editorial

- La explicacion funcional se escribe en espanol.
- Rutas, campos, variables e identificadores conservan su nombre tecnico.
- Los contratos documentados deben coincidir con controllers, DTOs y tipos.
- No se publican credenciales, hosts privados, tokens ni datos personales.
- Todo endpoint nuevo o modificado debe actualizar su pagina y `_sidebar.md`.

