# Caja chica

## Endpoints

| Metodo | Ruta | Entrada | Proposito |
|---|---|---|---|
| `GET` | `/api/cash-petty/report` | `year`, `month` | Resumen mensual de cajas chicas. |
| `GET` | `/api/cash-petty/:id/movements` | UUID de caja | Movimientos de una caja chica. |

Ambos endpoints requieren JWT.

## Resumen mensual

- `year`: entero entre 2000 y el ano actual.
- `month`: entero entre 1 y 12.

```http
GET /api/cash-petty/report?year=2026&month=9 HTTP/1.1
Authorization: Bearer <accessToken>
```

## Detalle

`id` debe ser un UUID v4 valido. El repository ejecuta la funcion de detalle
registrada en `cash-petty-detail.ts`.

