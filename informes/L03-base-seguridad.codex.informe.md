# Informe — L03-base-seguridad

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Base:** `a855d7d` (L02b)

## Archivos

Rutas relativas a `legajos/`.

### Creados

- `src/server/ip.ts`
- `src/server/permisos.ts`
- `src/server/contexto.ts`
- `src/server/errores.ts`
- `src/server/csrf.ts`
- `src/server/auth.ts`
- `src/server/auditoria.ts`
- `src/server/config.ts`
- `src/server/servicios/contratos.ts`
- `deploy/nginx.conf.example`
- `test/ip.test.ts`
- `test/auth-guard.test.ts`
- `test/permisos.unit.test.ts`

### Modificados

- `package.json`: dependencia solicitada `ipaddr.js`, fijada exactamente en 2.5.0.
- `pnpm-lock.yaml`: resolución de esa dependencia; no se actualizaron otras dependencias.

El único archivo escrito en `legajos-agents/` es este informe. Sin commit ni push. La spec no se movió.

## Implementación y decisiones

- IP exclusivamente desde `X-Real-IP`, normalizada con `ipaddr.process`; CIDR por comparación binaria y familias compatibles. Los tests prueban IPv4, IPv4-mapped, IPv6, ausencia, entradas inválidas y el falso prefijo `192.168.1.50` frente a `/32`.
- Matriz central con los 15 permisos; 45 combinaciones de rol y permiso verificadas contra una tabla independiente, más comprobaciones de que no hay permisos adicionales.
- `Contexto` lleva un `unique symbol` privado y es inmutable. `crearContexto` está documentada como interna y su único consumidor en el código de producción es `auth.ts`; los servicios sólo declaran entradas con `Contexto`.
- El guard valida mediante un único `UPDATE` condicional con `RETURNING`, con los límites estrictos de inactividad (8 h) y edad absoluta (12 h). En producción utiliza `now()` de Postgres; la dependencia `ahora` permite un instante fijo en tests.
- Los cierres de sesiones vencidas, de usuarios inactivos/bloqueados y de IP inválida/rechazada se confirman en el servidor conforme a §9.8. El rechazo por IP y su `acceso_log` se escriben en una misma transacción; el 401 se lanza después del commit para conservar ambas escrituras.
- Una falta de permiso, el cambio obligatorio de clave y un Origin inválido responden 403 sin cerrar la sesión. El cambio obligatorio sólo admite `cuenta.cambiar_clave`. CSRF exige igualdad exacta y rechaza ausencia, `null`, otro origen y una barra final adicional.
- Todos los `.set()` de Drizzle enumeran sus columnas. El token sólo se consulta mediante su SHA-256. No se modifican cookies desde el guard.
- `registrar` exige la transacción del llamador; se probó tanto la persistencia como el rollback de auditoría. Los registros de auditoría y acceso generan UUIDv7 en la app sin agregar otra dependencia.
- `ruta` del registro de rechazo del guard guarda el permiso solicitado, como identificador de operación: la interfaz especificada del guard no recibe la URL de la solicitud. El helper `registrarAcceso` sí recibe una ruta explícita para sus demás consumidores.
- Configuración validada al importar el módulo, también al importar el guard. Se prueban variables obligatorias, URLs, origen sin path/barra final, directorio absoluto y `TRUST_PROXY=1` en producción. Los errores sólo enumeran nombres de campos, sin imprimir valores ni credenciales.
- Los contratos de L05/L06/L07 contienen esquemas zod, tipos de entrada/salida y firmas, sin implementar servicios. Usan camelCase, fechas ISO, identificadores UUID, al menos una cédula en el alta y como máximo una original; las entradas no admiten paths de archivo del cliente. Los archivos se representan mediante streams del servidor.
- Nginx queda como borrador HTTPS: headers de proxy heredados por todas las ubicaciones, límite general de 1m y streaming/límite de 205m exclusivamente en `/api/documentos` y sus subrutas.
- Las pruebas del guard usan una conexión real autenticada como `legajos_app`, independiente de la siembra como `legajos_owner`; verifican `current_user` y ausencia de membresía en owner. No hay mocks de DB ni borrado de fixtures.

## Verificación final

La última corrida terminó con código 0: lint, typecheck, 214 tests en 7 archivos y build. `git diff --check` también terminó con código 0 y sin salida.

Se usó pnpm 11.0.0, fijado por `packageManager`. El launcher global instalado es 11.22.0 y empezó a fallar durante su selección de versión con `unable to open database file`. Se resolvió invocando el ejecutable 11.0.0 ya instalado mediante un enlace en `legajos/node_modules/.bin/pnpm` y anteponiendo ese directorio al PATH. No se editó la instalación global.

## Incidencias y límites

- La primera corrida falló en 14 aserciones: Drizzle configura el cliente postgres para entregar timestamps crudos como texto en consultas SQL directas. Se corrigió el helper del test para leer la sesión mediante el schema tipado de Drizzle; las siguientes comprobaciones pasaron.
- **Incidencia de alcance de ejecución:** durante la primera verificación que llegó al build, Next descargó automáticamente SWC en `/home/ecenturion/.cache/next-swc`, fuera de las dos carpetas autorizadas. Fue una escritura automática no prevista, visible en la salida real; no se puede afirmar que toda escritura de esa corrida quedó dentro del alcance. No se tocó posteriormente esa caché externa. La última corrida fija `NEXT_SWC_PATH` dentro de `legajos/node_modules/.cache/next-swc`.
- Hubo intentos fallidos de la última verificación antes de ejecutar scripts, por el error del launcher de pnpm indicado arriba. Se conservan sus salidas completas debajo.
- El build avisa que infirió `/home/ecenturion` como raíz por un lockfile externo. No se modificó ese lockfile ni `next.config.ts`, que está fuera del alcance de L03.
- `deploy/nginx.conf.example` no se probó contra un Nginx instalado ni se desplegó: es el borrador pedido. La integración de estos contratos en servicios y páginas corresponde a tareas posteriores.
- La instalación de `ipaddr.js` requirió recrear `node_modules` con un store dentro de `legajos/node_modules/.pnpm-store`; el primer intento de cambiar el store sin reinstalar fue rechazado por pnpm (`ERR_PNPM_UNEXPECTED_STORE`). No se agregaron dependencias distintas de la solicitada.

## Salidas reales de las verificaciones

### Corrida 1 — código de salida 1

```sh
cd legajos && pnpm verificar
```

```text
$ pnpm lint && pnpm typecheck && pnpm test && pnpm build
$ eslint .
$ tsc --noEmit
$ vitest run

 RUN  v3.2.7 /home/ecenturion/develop/legajos

{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "legajos" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
$ tsx src/server/db/migrar.ts
Aplicando migraciones...
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "drizzle" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P07',
  message: 'relation "__drizzle_migrations" already exists, skipping',
  file: 'parse_utilcmd.c',
  line: '207',
  routine: 'transformCreateStmt'
}
Migraciones aplicadas
 ✓ test/schema.test.ts (53 tests) 124ms
 ✓ test/triggers.test.ts (21 tests) 111ms
 ❯ test/auth-guard.test.ts (28 tests | 14 failed) 143ms
   ✓ Guard contra Postgres real conectado como legajos_app > ejecuta los servicios como app sin pertenecer a owner 23ms
   × Guard contra Postgres real conectado como legajos_app > sin cookie → 401, sin modificar otra sesión 7ms
     → expected '2026-10-04 14:00:00+00' to deeply equal 2026-10-04T14:00:00.000Z
   ✓ Guard contra Postgres real conectado como legajos_app > token desconocido → 401 6ms
   × Guard contra Postgres real conectado como legajos_app > sesión ya cerrada → 401, sin revivirla 7ms
     → expected { …(3) } to match object { …(3) }
   × Guard contra Postgres real conectado como legajos_app > inactividad de 8 h → 401 y cierre 5ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > inactividad de 9 h → 401 y cierre 5ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > edad absoluta de 12 h → 401 y cierre 4ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > edad absoluta de 13 h → 401 y cierre 3ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > usuario inactivo → 401 y cierre 5ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > usuario bloqueado → 401 y cierre 4ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   ✓ Guard contra Postgres real conectado como legajos_app > bloqueo vencido permite acceso 4ms
   × Guard contra Postgres real conectado como legajos_app > IP fuera de lista → 401, cierre y log persistido 5ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > X-Real-IP undefined → 401 y log ip_invalida 4ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > X-Real-IP inválida → 401 y log ip_invalida 4ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > usuario sin ninguna IP → 401 4ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   × Guard contra Postgres real conectado como legajos_app > IP revocada rige en el siguiente request 6ms
     → expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)
   ✓ Guard contra Postgres real conectado como legajos_app > consulta sin cedula.crear → 403 y sesión viva 5ms
   ✓ Guard contra Postgres real conectado como legajos_app > cambio obligatorio sólo permite cuenta.cambiar_clave 4ms
   ✓ Guard contra Postgres real conectado como legajos_app > mutación con Origin undefined → 403 3ms
   ✓ Guard contra Postgres real conectado como legajos_app > mutación con Origin null → 403 3ms
   ✓ Guard contra Postgres real conectado como legajos_app > mutación con Origin https://ajeno.test → 403 3ms
   ✓ Guard contra Postgres real conectado como legajos_app > mutación con Origin https://legajos.test/ → 403 3ms
   ✓ Guard contra Postgres real conectado como legajos_app > lectura no exige Origin 3ms
   × Guard contra Postgres real conectado como legajos_app > caso feliz devuelve Contexto y actualiza ultimo_uso 4ms
     → expected { cerrada_en: null, …(2) } to match object { …(2) }
(1 matching property omitted from actual)
   ✓ Guard contra Postgres real conectado como legajos_app > exigir aplica el permiso del servicio 3ms
   ✓ Guard contra Postgres real conectado como legajos_app > registrar guarda los datos del Contexto y un UUIDv7 en la transacción 4ms
   ✓ Guard contra Postgres real conectado como legajos_app > rollback revierte también la auditoría 4ms
   ✓ Guard contra Postgres real conectado como legajos_app > registrarAcceso admite usuario e IP nulos y genera UUIDv7 2ms
 ✓ test/permisos.test.ts (29 tests) 41ms
 ✓ test/ip.test.ts (20 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms
 ✓ test/humo.test.ts (3 tests) 22ms

⎯⎯⎯⎯⎯⎯ Failed Tests 14 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > sin cookie → 401, sin modificar otra sesión
AssertionError: expected '2026-10-04 14:00:00+00' to deeply equal 2026-10-04T14:00:00.000Z

- Expected: 
2026-10-04T14:00:00.000Z

+ Received: 
"2026-10-04 14:00:00+00"

 ❯ test/auth-guard.test.ts:93:48
     91|     cookie = undefined;
     92|     await expect(guard()).rejects.toBeInstanceOf(ErrorNoAutenticado);
     93|     expect((await estadoSesion())?.ultimo_uso).toEqual(ahora.minus({ h…
       |                                                ^
     94|   });
     95| 

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > sesión ya cerrada → 401, sin revivirla
AssertionError: expected { …(3) } to match object { …(3) }

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T14:50:00.000Z,
+   "cerrada_en": "2026-10-04 14:50:00+00",
    "motivo_cierre": "logout",
-   "ultimo_uso": 2026-10-04T14:00:00.000Z,
+   "ultimo_uso": "2026-10-04 14:00:00+00",
  }

 ❯ test/auth-guard.test.ts:106:34
    104|       WHERE id = ${sesionId}`;
    105|     await expect(guard()).rejects.toMatchObject({ status: 401 });
    106|     expect(await estadoSesion()).toMatchObject({
       |                                  ^
    107|       cerrada_en: ahora.minus({ minutes: 10 }).toJSDate(), motivo_cier…
    108|       ultimo_uso: ahora.minus({ hours: 1 }).toJSDate(),

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > inactividad de 8 h → 401 y cierre
 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > inactividad de 9 h → 401 y cierre
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "vencida",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:115:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > edad absoluta de 12 h → 401 y cierre
 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > edad absoluta de 13 h → 401 y cierre
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "vencida",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:121:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[4/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > usuario inactivo → 401 y cierre
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "usuario",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:127:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[5/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > usuario bloqueado → 401 y cierre
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "usuario",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:133:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[6/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > IP fuera de lista → 401, cierre y log persistido
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "ip",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:144:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[7/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > X-Real-IP undefined → 401 y log ip_invalida
 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > X-Real-IP inválida → 401 y log ip_invalida
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "ip",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:158:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[8/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > usuario sin ninguna IP → 401
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "ip",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:169:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[9/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > IP revocada rige en el siguiente request
AssertionError: expected { …(3) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
-   "cerrada_en": 2026-10-04T15:00:00.000Z,
+   "cerrada_en": "2026-10-04 15:00:00+00",
    "motivo_cierre": "ip",
  }

 ❯ comprobarCierre test/auth-guard.test.ts:82:34
     80| 
     81|   async function comprobarCierre(motivo: string) {
     82|     expect(await estadoSesion()).toMatchObject({ cerrada_en: ahora.toJ…
       |                                  ^
     83|   }
     84| 
 ❯ test/auth-guard.test.ts:178:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[10/14]⎯

 FAIL  test/auth-guard.test.ts > Guard contra Postgres real conectado como legajos_app > caso feliz devuelve Contexto y actualiza ultimo_uso
AssertionError: expected { cerrada_en: null, …(2) } to match object { …(2) }
(1 matching property omitted from actual)

- Expected
+ Received

  {
    "cerrada_en": null,
-   "ultimo_uso": 2026-10-04T15:00:00.000Z,
+   "ultimo_uso": "2026-10-04 15:00:00+00",
  }

 ❯ test/auth-guard.test.ts:214:34
    212|     });
    213|     expect(Object.isFrozen(ctx)).toBe(true);
    214|     expect(await estadoSesion()).toMatchObject({ ultimo_uso: ahora.toJ…
       |                                  ^
    215|   });
    216| 

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[11/14]⎯


 Test Files  1 failed | 6 passed (7)
      Tests  14 failed | 188 passed (202)
   Start at  15:56:20
   Duration  2.98s (transform 91ms, setup 0ms, collect 416ms, tests 451ms, environment 1ms, prepare 273ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.
```

### Corrida 2 — código de salida 0

```sh
cd legajos && pnpm verificar
```

```text
$ pnpm lint && pnpm typecheck && pnpm test && pnpm build
$ eslint .
$ tsc --noEmit
$ vitest run

 RUN  v3.2.7 /home/ecenturion/develop/legajos

{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "legajos" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
$ tsx src/server/db/migrar.ts
Aplicando migraciones...
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "drizzle" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P07',
  message: 'relation "__drizzle_migrations" already exists, skipping',
  file: 'parse_utilcmd.c',
  line: '207',
  routine: 'transformCreateStmt'
}
Migraciones aplicadas
 ✓ test/auth-guard.test.ts (28 tests) 134ms
 ✓ test/schema.test.ts (53 tests) 126ms
 ✓ test/triggers.test.ts (21 tests) 108ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (20 tests) 6ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  7 passed (7)
      Tests  202 passed (202)
   Start at  15:57:20
   Duration  2.98s (transform 105ms, setup 0ms, collect 498ms, tests 438ms, environment 1ms, prepare 263ms)

$ next build
   Downloading swc package @next/swc-linux-x64-gnu... to /home/ecenturion/.cache/next-swc
   Downloading swc package @next/swc-linux-x64-musl... to /home/ecenturion/.cache/next-swc
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 1058ms
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/4) ...
   Generating static pages (1/4) 
   Generating static pages (2/4) 
   Generating static pages (3/4) 
 ✓ Generating static pages (4/4)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      125 B         103 kB
└ ○ /_not-found                            996 B         104 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


○  (Static)  prerendered as static content
```

### Corrida 3 — código de salida 1

```sh
cd legajos
export XDG_CACHE_HOME="$PWD/node_modules/.cache"
export TMPDIR="$PWD/node_modules/.tmp"
mkdir -p "$TMPDIR"
pnpm verificar
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

### Corrida 4 — código de salida 1

```sh
cd legajos
export XDG_CACHE_HOME="$PWD/node_modules/.cache"
export TMPDIR="$PWD/node_modules/.tmp"
mkdir -p "$XDG_CACHE_HOME" "$TMPDIR"
pnpm verificar
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

### Corrida 5 — código de salida 1

```sh
cd legajos
export NEXT_SWC_PATH="$PWD/node_modules/.cache/next-swc"
pnpm verificar
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

### Corrida 6 — código de salida 1

```sh
cd legajos
export NEXT_SWC_PATH="$PWD/node_modules/.cache/next-swc"
export npm_config_store_dir="$PWD/node_modules/.pnpm-store"
pnpm verificar
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

### Corrida 7 — código de salida 1

```sh
cd legajos
export PATH="$PWD/node_modules/.bin:$PATH"
export NEXT_SWC_PATH="$PWD/node_modules/.cache/next-swc"
pnpm verificar
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

### Corrida 8 — código de salida 0

```sh
cd legajos
export PATH="$PWD/node_modules/.bin:$PATH"
export NEXT_SWC_PATH="$PWD/node_modules/.cache/next-swc"
pnpm verificar
```

```text
$ pnpm lint && pnpm typecheck && pnpm test && pnpm build
$ eslint .
$ tsc --noEmit
$ vitest run

 RUN  v3.2.7 /home/ecenturion/develop/legajos

{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "legajos" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
$ tsx src/server/db/migrar.ts
Aplicando migraciones...
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "drizzle" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P07',
  message: 'relation "__drizzle_migrations" already exists, skipping',
  file: 'parse_utilcmd.c',
  line: '207',
  routine: 'transformCreateStmt'
}
Migraciones aplicadas
 ✓ test/auth-guard.test.ts (40 tests) 160ms
 ✓ test/schema.test.ts (53 tests) 125ms
 ✓ test/triggers.test.ts (21 tests) 109ms
 ✓ test/permisos.test.ts (29 tests) 40ms
 ✓ test/humo.test.ts (3 tests) 23ms
 ✓ test/ip.test.ts (20 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  7 passed (7)
      Tests  214 passed (214)
   Start at  16:03:24
   Duration  3.00s (transform 113ms, setup 0ms, collect 458ms, tests 469ms, environment 1ms, prepare 264ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 787ms
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/4) ...
   Generating static pages (1/4) 
   Generating static pages (2/4) 
   Generating static pages (3/4) 
 ✓ Generating static pages (4/4)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      125 B         103 kB
└ ○ /_not-found                            996 B         104 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


○  (Static)  prerendered as static content
```

