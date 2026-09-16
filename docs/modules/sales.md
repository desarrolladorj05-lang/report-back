# Reportes de ventas

Todos los endpoints, excepto `time`, requieren JWT.

| Metodo | Ruta | Query principal | Proposito |
|---|---|---|---|
| `GET` | `/api/report/managment-sales` | `date` | Reporte gerencial consolidado. |
| `GET` | `/api/report/sales-by-sede` | `date`, `id_local?` | Ventas agrupadas por sede. |
| `GET` | `/api/report/fuel-by-sede` | `date`, `id_local?` | Combustibles agrupados por sede. |
| `GET` | `/api/report/contometer-by-product` | `date`, `id_local?`, `id_turno?`, `id_producto?` | Contometros filtrados. |
| `GET` | `/api/report/clients-full-detail` | `date`, `id_local?`, `id_concepto?`, `id_turno?` | Detalle de clientes. |
| `GET` | `/api/report/time` | ninguno | Hora UTC y hora de Lima. |

`date` se recibe como texto porque las funciones heredadas esperan el formato
operativo del reporte. Los identificadores opcionales se transforman a numero.

Ejemplo:

```bash
curl "http://localhost:3000/api/report/sales-by-sede?date=16/09/2026" \
  -H "Authorization: Bearer <accessToken>"
```

