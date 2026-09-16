# Configuracion local

## Requisitos

- Node.js 20.
- npm.
- Acceso a PostgreSQL master.
- Al menos un tenant activo y accesible.

## Variables de entorno

| Variable | Requerida | Proposito |
|---|---:|---|
| `DB_HOST` | si | Host PostgreSQL compartido. |
| `DB_PORT` | no | Puerto PostgreSQL; por defecto `5432` en validacion. |
| `DB_USER` | si | Usuario de base de datos. |
| `DB_PASSWORD` | si | Contrasena de base de datos. |
| `DB_NAME` | si | Base master con el catalogo de tenants. |
| `DB_SSL` | no | Activa SSL cuando vale `true`. |
| `PORT` | no | Puerto HTTP principal. |
| `API_PORT` | no | Respaldo usado si no existe `PORT`. |
| `FIXED_TENANT_DB` | no | Fuerza un tenant por nombre de base. |
| `DEV_TENANT_ID` | no | Tenant de desarrollo cuando no se usa dominio. |
| `DEV_TENANT_DB` | no | Base tenant asociada a `DEV_TENANT_ID`. |
| `TENANT_DOMAIN` | no | Dominio permitido; por defecto `isi.com.pe`. |
| `TENANT_CACHE_MAX` | no | Maximo de conexiones tenant en cache. |
| `TENANT_POOL_SIZE` | no | Tamano maximo del pool por tenant. |
| `TENANT_POOL_TTL_MIN` | no | Minutos de vida ociosa de una conexion tenant. |

No se deben copiar valores reales a la documentacion ni versionar archivos
`.env` con credenciales.

## Ejecucion

```bash
npm install
npm run start:dev
```

La API expone el prefijo global `/api`. El arranque imprime la URL efectiva.

## Verificacion

```bash
npm run build
npm test
```

El endpoint `GET /api/report/time` permite comprobar fecha y zona horaria del
servidor sin autenticacion.

