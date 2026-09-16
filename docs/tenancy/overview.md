# Arquitectura multitenant

## Resolucion

Durante el login, `TenantResolverService` aplica este orden:

1. `FIXED_TENANT_DB`, si esta configurado.
2. `DEV_TENANT_ID` y `DEV_TENANT_DB` fuera de produccion.
3. Dominio y subdominio obtenidos de `Origin`, `Referer` o
   `X-Client-Origin`.

En solicitudes autenticadas, `JwtStrategy` toma `tenantId` del JWT, comprueba
que el tenant continue activo y registra `dbName` en el contexto CLS.

## Conexion tenant

```text
JWT tenantId
  -> TenantResolverService
  -> TenancyContextService
  -> TenantDataSourceFactory
  -> TenantConnectionManager
  -> base tenant
```

`TenantConnectionManager` mantiene un cache LRU por nombre de base, evita abrir
dos conexiones simultaneas para el mismo tenant y destruye conexiones
expulsadas o al cerrar el modulo.

## Propiedad del esquema

Backoffice sigue siendo propietario de tablas, relaciones y migraciones. Este
backend consulta el esquema compartido y versiona SQL especializado para sus
tableros. Ninguna funcion o indice se instala automaticamente al iniciar.

## Seguridad

- Un cliente no elige `dbName` mediante query params.
- El tenant autenticado proviene del JWT y se valida contra master.
- Los repositories solicitan el `DataSource` al contexto actual.
- Un JWT sin `tenantId` es rechazado.

