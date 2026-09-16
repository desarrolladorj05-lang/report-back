# Vision general de arquitectura

## Proposito

Separar transporte HTTP, reglas de composicion y acceso a PostgreSQL para que
los reportes puedan evolucionar sin duplicar consultas en controllers.

## Flujo principal

```text
Solicitud HTTP
  -> JwtAuthGuard
  -> JwtStrategy resuelve tenant
  -> controller valida DTO
  -> service compone el caso de uso
  -> repository ejecuta funcion SQL
  -> service transforma el resultado
  -> respuesta JSON
```

## Capas

| Capa | Responsabilidad |
|---|---|
| Controller | Ruta, DTO, guard y medicion del tiempo total. |
| Service | Coordinacion, comparaciones, calculos y contrato publico. |
| Repository | Ejecucion de funciones mediante `BaseRepository`. |
| Procedure documentation | Nombre tipado, parametros y retorno de cada funcion. |
| SQL | Agregaciones pesadas ejecutadas cerca de los datos. |

## Modulos NestJS

- `AuthModule`
- `TenancyModule`
- `SaleReportModule`
- `CashPettyReportModule`
- `LiquidationDashboardModule`
- `ProductStockDashboardModule`

## Convenciones relevantes

- Prefijo HTTP global: `/api`.
- Validacion global: `ValidationPipe` con `whitelist` y `transform`.
- Errores: `HttpExceptionFilter` global.
- Limite general: 10 solicitudes por minuto e IP.
- Timeout HTTP: 5 minutos para reportes pesados.
- `synchronize: false`: TypeORM nunca administra el esquema tenant.

