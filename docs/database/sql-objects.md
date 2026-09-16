# Funciones e indices SQL

## Organizacion

```text
src/database/sql/
|-- functions/
|   |-- cash-petty/
|   |-- clients/
|   |-- liquidations/
|   |-- products/
|   `-- sales/
`-- indexes/
    |-- liquidations/
    `-- products/
```

Cada funcion vive en un archivo con el mismo nombre del objeto PostgreSQL. Los
indices se agrupan por dominio cuando forman parte del mismo plan de consulta.

## Instalacion

Los scripts se ejecutan manualmente en cada base tenant:

1. Seleccionar la base tenant correcta.
2. Ejecutar primero las funciones requeridas por el modulo.
3. Ejecutar los indices compatibles con esa base.
4. Verificar la firma en `pg_proc` y los indices en `pg_indexes`.
5. Probar el endpoint con un rango pequeno.

Los `CREATE INDEX CONCURRENTLY` no pueden ejecutarse dentro de una transaccion.
Los scripts actuales que usan `CREATE INDEX IF NOT EXISTS` son compatibles con
ejecucion transaccional, salvo que el propio archivo indique lo contrario.

## Catalogo tipado

`src/database/procedures-documentation/` declara nombre, orden de parametros y
tipo de retorno. Todo SQL nuevo debe registrarse antes de ser consumido por un
repository.

## Regla de compatibilidad

No modificar funciones pertenecientes a Backoffice desde este proyecto. Si un
reporte necesita una logica distinta, crear una funcion propia con nombre
especifico y coordinar su migracion posterior.
