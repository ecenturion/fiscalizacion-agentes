# L02a — Tablas y constraints

**Arquitecto:** claude-code · **Implementa:** AGY · **Audita:** CODEX
**Fuente:** `docs/diseno.md` §2 (tabla del modelo), §2.1, §9.1–§9.3 y §10.1. **§9 y §10 mandan sobre §2.**
**Fuera de alcance:** grants, triggers, funciones y seeds. Los hace L02b.

## Alcance de archivos (4)
1. `src/server/db/schema.ts`: todas las tablas en el esquema `legajos` (`legajos.table(...)`):
   - `usuario`, `usuario_ip`, `sesion`, `acceso_log`, `limite_ip`;
   - `estado_legajo`, `tipo_interaccion`, `tipo_documento`;
   - `contador_legajo`, `legajo`, `cedula`;
   - `documento`, `documento_archivo`;
   - `interaccion`, `solicitud_documento`;
   - `auditoria`.
2. `drizzle/0001_*.sql` y `drizzle/meta/*`, generados con `pnpm db:generate`. Lo que drizzle-kit no expresa va
   **en la misma migración**, editada a mano debajo de lo generado:
   - la columna generada `legajo.numero`, si drizzle no la soporta;
   - `CREATE EXTENSION IF NOT EXISTS pg_trgm` y `unaccent`, en el esquema `legajos`;
   - los índices únicos sobre `lower(nombre)`;
   - los índices parciales.
3. `test/schema.test.ts`: **nuevo**. Corre como `legajos_owner`, porque los grants todavía no existen.

## Reglas del modelo (literal del diseño)
- **ids:** `uuid` sin `DEFAULT` (UUIDv7 desde la app). `creado_en timestamptz not null default now()` se permite
  (es un timestamp, no un id).
- **Nulabilidad:** §9.1, al pie de la letra. Todo `NOT NULL` salvo la lista de §9.1.
- **Checks:**
  - `usuario.rol in ('admin','operador','consulta')`;
  - `usuario.usuario = lower(usuario)`;
  - `intentos_fallidos >= 0`;
  - `acceso_log.resultado` con los valores de §2, **más `ip_invalida`** (§9.1);
  - `tipo_documento.vigencia_dias is null or > 0`;
  - `contador_legajo.ultimo >= 0`;
  - `legajo.correlativo > 0` y `anio between 2000 and 2100`;
  - `cedula.numero ~ '^[0-9]+$'`;
  - `documento_archivo.orden > 0`, `bytes > 0` y `mime in ('application/pdf','image/jpeg','image/png')`;
  - `interaccion.nota` con `btrim(nota) <> ''`;
  - el check de estado de **§10.1**, literal;
  - `auditoria.accion in ('alta','cambio','anulacion','vista','descarga','login_admin')`;
  - en toda tabla con `anulado_*`: las tres juntas o ninguna, y `btrim(motivo_anulacion) <> ''`.
- **Únicos:**
  - `usuario.usuario`;
  - `lower(nombre)` en los tres catálogos;
  - `legajo(anio, correlativo)` y `legajo.numero`;
  - `sesion.token_hash`;
  - `documento.version_de`, donde no es nulo;
  - `documento_archivo(documento_id, orden)` y `documento_archivo.path_relativo`.
- **Índices parciales:** cédula original única: `(legajo_id) where es_original and anulado_en is null`.
- **Índices:**
  - `cedula(numero)`;
  - trigram sobre `unaccent(nombres || ' ' || apellidos)`, si `unaccent` no es inmutable, con una función
    wrapper `legajos.f_unaccent` `IMMUTABLE`;
  - `acceso_log(ip, creado_en)`;
  - `interaccion(legajo_id, creado_en)`;
  - `documento(legajo_id, tipo_id)`.
- **`legajo.numero`:** generada, con la expresión de **§9.2**.
- **Tipos:** `usuario_ip.red` es `cidr`; `acceso_log.ip` y `limite_ip.ip` son `inet` (`limite_ip.ip` es la PK).
- **FKs:** todas con `ON DELETE RESTRICT`.

## Criterios
```
cd legajos && pnpm verificar && pnpm db:generate   # el segundo: "No schema changes"
```
`test/schema.test.ts`: una transacción por caso, con `.rejects.toMatchObject({ code })`:
1. Número: correlativo 1 → `2026-0001`, 12345 → `2026-12345`. Duplicado `(anio, correlativo)` → 23505.
2. Original: dos cédulas originales vivas en el mismo legajo → 23505. Si una está anulada → ok.
3. Cédula con número `12a` → 23514.
4. Anulación parcial (sólo `anulado_en`) → 23514. Motivo `'  '` → 23514.
5. Interacción con nota vacía → 23514. Con sólo `estado_nuevo_id` → 23514. Con ambos iguales → 23514. Con
   ambos nulos → ok. Con ambos distintos → ok.
6. `tipo_documento.vigencia_dias = 0` → 23514. Catálogo `'Nota'` y `'nota'` → 23505.
7. `documento_archivo` con mime `image/gif` → 23514. `orden` repetido → 23505.
8. `documento.version_de` repetido → 23505.
9. `acceso_log` con `ip` nula y resultado `ip_invalida` → ok.

Sin `any`. Sin commit ni push.

### Nota de despacho (2do intento)
El primer intento dejó `src/server/db/schema.ts` casi completo (238 líneas): **partí de ahí**, no lo reescribas. Se
cortó porque **`rm` no está permitido** en tu entorno. No crees archivos de prueba sueltos (`test.js` y similares):
para verificar, usá `pnpm verificar` y `pnpm db:generate`. Si te sobra un archivo, avisalo en el informe y el
arquitecto lo borra.

### Nota de despacho (3er intento, CODEX sombrero B)
AGY se cortó dos veces. `src/server/db/schema.ts` ya tiene las tablas: **partí de ahí**, revisalo contra las reglas
de arriba y completá lo que falte. **No toques `drizzle/0000_*`**: la migración nueva es `0001`. Faltan:
- la migración 0001 generada, con los agregados SQL a mano (extensiones, trigram con `f_unaccent`, columna
  generada `numero` si drizzle no la emite);
- `test/schema.test.ts`.
