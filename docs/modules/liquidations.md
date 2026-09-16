# Dashboard de liquidaciones

## Endpoints

| Metodo | Ruta | Proposito |
|---|---|---|
| `GET` | `/api/report/liquidations/dashboard` | Resumen, evolucion, rankings y conciliacion. |
| `GET` | `/api/report/liquidations/cash-registers` | Cajas del rango para detalle bajo demanda. |

Ambos requieren JWT y aceptan:

| Parametro | Tipo | Requerido | Descripcion |
|---|---|---:|---|
| `dateFrom` | fecha ISO | si | Inicio inclusivo. |
| `dateTo` | fecha ISO | si | Fin inclusivo. |
| `localNumber` | entero positivo | no | Limita el reporte a una sede. |

```bash
curl "http://localhost:3000/api/report/liquidations/dashboard?dateFrom=2026-09-01&dateTo=2026-09-16" \
  -H "Authorization: Bearer <accessToken>"
```

## Fuentes

- `sp_liquidation_dashboard`: periodo actual, conciliacion y agregados.
- `sp_liquidation_period_totals`: comparacion optimizada con periodo anterior.
- `sp_liquidation_cash_registers`: detalle de cajas cargado por separado.

La conciliacion usa la ultima liquidacion activa de cada caja. Los importes de
efectivo y tarjeta conservan el agrupamiento utilizado por el reporte de
liquidacion de Backoffice.

## Despliegue SQL

Los tres archivos de `src/database/sql/functions/liquidations/` deben estar
instalados en cada tenant. Al modificar el contrato JSON de la funcion principal
es obligatorio reinstalarla antes de desplegar un frontend que consuma campos
nuevos.

