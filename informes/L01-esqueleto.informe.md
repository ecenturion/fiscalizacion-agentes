# L01 — esqueleto

**Estado:** COMPLETADO · AGY implementó (primer despacho cortado: el allowlist niega `npm info`; el arquitecto resolvió las versiones en la spec). Ajustes del arquitecto: eslint ignora `.next`/`drizzle`/`next-env.d.ts`; `pnpm-workspace.yaml` con `allowBuilds` resueltos (esbuild, unrs-resolver); `*.tsbuildinfo` ignorado; el global-setup ya no corre `db:generate` (las migraciones se commitean); `chequear-sistema.sh` sin duplicados y con el paquete de Fedora correcto (`vips-tools`).

Verificación: `pnpm verificar` exit 0 · humo 3/3 (app conecta, no es miembro de owner, no puede crear tablas) · `next build` ok. La regla de lint contra `.set({...spread})` salta (probado con un archivo temporal). `chequear-sistema`: falta vips en la PC de desarrollo.
