# M4 — Catálogos operativos y huecos de contrato reportados en M3 (URGENTE: producción no puede crear trámites)

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** arquitecto (mutaciones)
**Rama:** `main`. Base: `304f63e` (en producción).
**Origen:** `informes/M3-pantallas-v2.opencode.informe.md`, sección "Bloqueos de servidor", puntos 1 a 7. En
producción hay 1 tipo de trámite y 0 trámites → la pantalla "Nuevo trámite" dice que no hay tipos.

## Alcance de archivos
1. `src/server/servicios/catalogos.ts` (**nuevo**): `crearServiciosCatalogos(db)` →
   `catalogosOperativos(ctx)`:
   - `exigir(ctx, 'tramite.ver')`;
   - devuelve `{ tiposTramite, estados, tiposInteraccion, tiposDocumento }`, **sólo activos**, ordenados por
     `orden` y nombre, como `CatalogoResumen` (más `vigenciaDias` y `multiplesArchivos` en los tipos de documento);
   - sin auditoría de vista: son catálogos, no datos personales.

   Agregalo a `servicios()` de `src/server/acciones/contexto.ts`.
2. `src/server/servicios/contratos.ts`, `mapeo.ts`, `legajos.ts`, `tramites.ts` e `interacciones.ts`, con los
   contratos que pide el informe:
   - `LegajoResumen.cantidadTramites`: los vínculos vivos;
   - `TramiteResumen.cedulas: { legajoId, cedula, esOriginal }[]`, sólo vivos. **Una consulta**, no N+1;
   - `InteraccionSalida.nombreUsuario`;
   - `TramiteSalida.obligatorios: { tipo: CatalogoResumen, cumplido: boolean }[]` (además de `faltantes`);
   - `TramiteSalida.documentos: DocumentoSalida[]`: los documentos con `tramite_id` = este trámite, en **una
     consulta**. La vista del trámite se audita **una vez**.
3. **`registrarInteraccionAccion`**: exige `interaccion.crear`, alineado con la matriz. Revisá que
   `interaccion.crear` exista para admin y operador.
4. **UI**, sólo para usar lo nuevo:
   - `src/app/(app)/tramites/catalogos.ts`: **borrarlo**. `nuevo/page.tsx`, `page.tsx` y `[id]/page.tsx` usan
     `servicios().catalogos.catalogosOperativos(ctx)`;
   - el detalle del trámite usa `tramite.documentos` en lugar de llamar a `listarDocumentosLegajo` por cada vínculo;
   - el historial muestra `nombreUsuario`;
   - el listado de trámites muestra las cédulas, con la original marcada;
   - el listado de legajos muestra la cantidad de trámites;
   - los obligatorios aparecen con "cumplido" o "falta", y si el tipo no tiene ninguno: "Este tipo de trámite no
     tiene documentos obligatorios definidos".
5. **Tests:**
   - `test/catalogos.test.ts`: `consulta` → ok; un usuario con sesión inválida → 401; los inactivos **no**
     aparecen; en una base recién sembrada devuelve "Múltiple cedulación";
   - ajustes en `tramites`, `legajos`, `interacciones` y `acciones`: `cedulas` en el resumen,
     `cantidadTramites`, `nombreUsuario`, `obligatorios` y `documentos`. **Contá las consultas** de `verTramite`
     y de `buscarTramites`: no tienen que crecer con la cantidad de vínculos. Alcanza con un spy en el driver o con
     comparar 1 contra 5 vínculos.

## Criterios
```
cd legajos && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm verificar
```
Sin `any`, sin `console.log`. Sin commit ni push.
