# Autenticacion

## Endpoints

| Metodo | Ruta | Autenticacion | Proposito |
|---|---|---|---|
| `POST` | `/api/auth/login` | no | Validar usuario, resolver tenant y crear cookie. |
| `POST` | `/api/auth/register` | no | Registrar un usuario en el tenant resuelto. |
| `POST` | `/api/auth/logout` | no | Eliminar la cookie `access_token`. |
| `GET` | `/api/auth/profile` | JWT | Retornar la identidad autenticada. |
| `GET` | `/api/auth/bootstrap` | JWT | Retornar menus, permisos y sedes efectivas. |

## Login

```http
POST /api/auth/login HTTP/1.1
Content-Type: application/json

{
  "username": "usuario.demo",
  "password": "secreto-seguro"
}
```

`username` es obligatorio y `password` requiere al menos seis caracteres. El
login tiene un limite de cuatro intentos cada veinte minutos.

La respuesta no expone el token. El servidor crea una cookie HTTP-only llamada
`access_token`, valida por una hora y marcada como `secure` en produccion.

## Uso del token

`JwtStrategy` acepta el JWT desde:

1. La cookie `access_token`.
2. `Authorization: Bearer <token>`.

La identidad incluye `userId`, `username`, `tenantId`, `tenantDbName` y los
modulos autorizados.

## Bootstrap de autorizacion

`GET /api/auth/bootstrap` es la fuente de autorizacion del frontend. Consulta
las mismas tablas `s_sem_*` y `user_local` utilizadas por Backoffice y limita
los menus al modulo gerencial (`M2` o `MANAGEMENT_REPORT`).

La respuesta contiene:

- `menus`: arbol de opciones que tienen un acceso efectivo de tipo VER.
- `permissionCodes`: union de permisos de los perfiles, aplicando primero los
  overrides de `s_sem_user_access`.
- `locals`: sedes activas asignadas mediante `user_local`.
- `hasAllLocals`: indica que la asignacion cubre todas las sedes activas.
- `authzVersion`: huella del contexto para detectar cambios de autorizacion.

El frontend usa `menus` para construir la portada y proteger las rutas. El
backend vuelve a validar el menu en cada familia de endpoints; ocultar una
opcion en el navegador no constituye la autorizacion.

## Alcance por sede

Los reportes nunca deben convertir la ausencia de un filtro en acceso global
para un usuario restringido:

- Con `hasAllLocals = true`, el usuario puede consultar todas las sedes.
- Con una lista parcial, los agregados se calculan solo sobre esas sedes.
- Un `localNumber` que no pertenece a `locals` responde `403`.
- Caja chica valida el UUID de la sede incluso en la consulta de detalle.
- Stock de combustible entrega `local_ids` directamente a
  `get_fuel_stock_detailed_groups`; no modifica esa funcion del Backoffice.

El kardex heredado no admite todavia sede como parametro. Por seguridad queda
bloqueado para usuarios con alcance parcial hasta que su funcion SQL soporte
ese filtro.

## Configuracion del Backoffice

Los menus gerenciales deben pertenecer al modulo `M2` (o
`MANAGEMENT_REPORT`; en la base actual su codigo es `report`) y usar los
`path_key` siguientes:

| Menu | `path_key` |
|---|---|
| Ventas | `/ventas` |
| Caja chica | `/caja` |
| Productos | `/productos` |
| Liquidaciones | `/liquidaciones` |

Cada menu necesita al menos un acceso efectivo con la accion VER. La
asignacion se realiza mediante perfil (`s_sem_profile_access`) o como override
de usuario (`s_sem_user_access`). Las sedes se administran con `user_local`.

Los menus inactivos se incluyen en el `bootstrap` con `isActive: false`. El
frontend los presenta en gris y bloquea su navegacion. Al activar el menu desde
Backoffice, queda disponible sin modificar nuevamente el frontend, siempre que
el perfil del usuario tenga asignado su acceso VER.
