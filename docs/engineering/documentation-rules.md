# Reglas de documentacion

## Endpoint nuevo o modificado

La pagina correspondiente debe incluir:

1. Proposito funcional.
2. Metodo y ruta completa con prefijo `/api`.
3. Autenticacion requerida.
4. Parametros de ruta, query y body.
5. Ejemplo HTTP o cURL.
6. Respuesta representativa cuando el contrato este estabilizado.
7. Errores funcionales.
8. Funciones SQL y dependencias relevantes.

## Exactitud

- No inventar campos ni envelopes.
- Confirmar controller, DTO, service y tipos publicos.
- Marcar claramente las funciones de instalacion manual.
- No llamar propio a un objeto SQL administrado por Backoffice.
- Actualizar `_sidebar.md` al crear una pagina visible.

## Datos de ejemplo

- Usar UUIDs ficticios y fechas representativas.
- No incluir nombres reales de trabajadores o clientes.
- No publicar credenciales, dominios internos ni tokens validos.
- Mantener los formatos de fecha y numeros del contrato real.

## Mantenimiento

La documentacion forma parte del cambio. Una modificacion de ruta, parametro,
respuesta o fuente SQL no se considera completa hasta actualizar su pagina.

