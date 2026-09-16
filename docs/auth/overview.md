# Autenticacion

## Endpoints

| Metodo | Ruta | Autenticacion | Proposito |
|---|---|---|---|
| `POST` | `/api/auth/login` | no | Validar usuario, resolver tenant y crear cookie. |
| `POST` | `/api/auth/register` | no | Registrar un usuario en el tenant resuelto. |
| `POST` | `/api/auth/logout` | no | Eliminar la cookie `access_token`. |
| `GET` | `/api/auth/profile` | JWT | Retornar la identidad autenticada. |

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

