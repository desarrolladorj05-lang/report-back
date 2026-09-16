# Reporte Gerencial Backend

API multitenant para los tableros de ventas, caja chica, liquidaciones y
movimientos de productos. Esta construida con NestJS, TypeScript, TypeORM y
PostgreSQL, y consulta las mismas bases tenant utilizadas por Backoffice.

## Documentacion

La documentacion tecnica vive en [`docs/`](docs/index.md) y puede abrirse como
sitio Docsify desde [`index.html`](index.html).

```bash
npx serve .
```

Luego abre la URL indicada por `serve`.

## Inicio rapido

```bash
npm install
npm run start:dev
```

La API usa el prefijo global `/api`. El puerto se obtiene de `PORT` o
`API_PORT` y, si ambos faltan, usa `3000`.

## Comandos

| Comando | Proposito |
|---|---|
| `npm run start:dev` | Ejecutar NestJS en modo watch. |
| `npm run build` | Compilar el backend. |
| `npm run start:prod` | Ejecutar `dist/main`. |
| `npm run lint` | Revisar y corregir archivos TypeScript con ESLint. |
| `npm test` | Ejecutar pruebas Jest. |

## Responsabilidad de datos

Backoffice es el propietario del esquema compartido. Este proyecto mantiene
funciones e indices SQL para sus reportes, pero no los instala automaticamente:
deben ejecutarse de forma controlada en cada base tenant.

