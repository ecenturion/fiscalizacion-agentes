# L11a — Deploy con Docker en el servidor de la institución (CentOS 7 + Apache)

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** arquitecto
**Reemplaza** a la sección §4 del diseño, que suponía Ubuntu, Nginx y PM2. Decisiones de Emilio (2026-10-05):
- servidor **definitivo** `192.168.5.104`: CentOS 7, glibc 2.17, 1 CPU y 1 GB de RAM;
- el mismo servidor ya corre Apache 2.4 + PHP en el 80 y PostgreSQL 13 con otras bases;
- **Docker**, con un **PostgreSQL 16 propio en contenedor**;
- URL **`https://192.168.5.104/fiscalizacion`**, servida por el Apache existente en el 443 con un certificado
  autofirmado;
- primer admin: `admin`, desde `192.168.5.0/24`.

Ya hecho por el arquitecto en el servidor: Docker 26.1.4 + Compose 2.27 y `mod_ssl`.

**OPENCODE ya terminó L08b (`L08b` commiteada).** Esta tarea también ajusta la UI para el basePath, punto 15.

## Alcance de archivos

### App (sólo estos)
1. **`next.config.ts`**:
   - `basePath: process.env.NEXT_BASE_PATH || ''`, que se fija en build;
   - `output: 'standalone'`;
   - `poweredByHeader: false`;
   - `serverExternalPackages` para `@node-rs/argon2` si hace falta.
2. **`src/lib/base.ts`**: `BASE = process.env.NEXT_PUBLIC_BASE_PATH ?? ''` y `conBase(ruta)` → `${BASE}${ruta}`. Es
   para los `href` crudos, `<form action>`, `fetch` y `<iframe src>`, que Next **no** prefija. `<Link>` y
   `redirect()` sí lo hacen.
3. **`src/server/cookie.ts`**: `path` = `BASE || '/'`.
4. **`src/app/logout/route.ts`**: redirige a `${APP_ORIGIN}${BASE}/login`.
5. **`src/middleware.ts`**:
   - matcher y exclusiones con basePath (Next le pasa `pathname` sin basePath; verificalo);
   - redirige a `/login` con `request.nextUrl.clone()`, para que conserve el basePath.
6. **`src/server/config.ts`**: agregá `VALIDACION_MEMORIA_BYTES` opcional. Ningún otro cambio.

### Contenedores y despliegue (nuevos)
7. **`Dockerfile`**, multi-stage:
   - etapa *build*: `node:22-bookworm-slim` + pnpm, `pnpm install --frozen-lockfile` y `pnpm build`, con
     `ARG NEXT_BASE_PATH=/fiscalizacion` exportado también como `NEXT_PUBLIC_BASE_PATH`;
   - etapa *runtime*: `node:22-bookworm-slim` + `apt install qpdf libvips-tools util-linux`, sin recomendados;
   - usuario **no root** (`uid 10001`);
   - copia `.next/standalone`, `.next/static`, `drizzle/`, `scripts/` compilados y lo necesario para migrar;
   - `ENV NODE_ENV=production HOSTNAME=0.0.0.0 PORT=3000`;
   - `HEALTHCHECK` con `curl` o `node -e` a `/fiscalizacion/login`;
   - `ENTRYPOINT` → `scripts/entrypoint.sh`.
8. **`scripts/entrypoint.sh`**:
   1. espera a Postgres;
   2. corre `node migrar.js` con `MIGRATE_DATABASE_URL`, el rol owner;
   3. hace `exec node server.js`.

   Así las migraciones van siempre antes de servir.
9. **`deploy/compose.prod.yml`**:
   - **`db`**:
     - `postgres:16-alpine` con un volumen en `/srv/fiscalizacion/pgdata`;
     - **sin puertos publicados**;
     - `POSTGRES_PASSWORD` desde `.env`;
     - `deploy/initdb/01-roles.sh` crea `legajos_owner` y `legajos_app` con sus claves (de `.env`), la base
       `fiscalizacion` con dueño owner, el esquema `legajos`, `REVOKE CREATE ON SCHEMA public FROM PUBLIC` y el
       `search_path` de app. Mismo contenido que `test/setup-roles.sql`, pero con claves;
     - `mem_limit: 256m`;
   - **`app`**:
     - la imagen `fiscalizacion:<tag>`;
     - `ports: ["127.0.0.1:3000:3000"]`, **sólo loopback**;
     - el volumen `/srv/fiscalizacion/archivos:/datos/archivos`;
     - `env_file: .env`;
     - `mem_limit: 700m`;
     - `restart: unless-stopped`;
     - `depends_on` de `db` con healthcheck.
10. **`deploy/.env.example`**:
    - `DATABASE_URL` (app), `MIGRATE_DATABASE_URL` (owner), `POSTGRES_PASSWORD`, `OWNER_PASSWORD`, `APP_PASSWORD`;
    - `APP_ORIGIN=https://192.168.5.104`;
    - `ARCHIVOS_DIR=/datos/archivos`;
    - `TRUST_PROXY=1`;
    - `VALIDACION_MEMORIA_BYTES=536870912`.

    Comentarios incluidos, **sin valores reales**.
11. **`deploy/apache-fiscalizacion.conf`**, para incluir dentro del `<VirtualHost _default_:443>` de `ssl.conf` o
    como `conf.d` propio:
    ```
    <Location /fiscalizacion>
      ProxyPass        http://127.0.0.1:3000/fiscalizacion
      ProxyPassReverse http://127.0.0.1:3000/fiscalizacion
      ProxyPreserveHost On
      ProxyAddHeaders Off
      RequestHeader unset X-Forwarded-For
      RequestHeader set X-Real-IP "expr=%{REMOTE_ADDR}"
      LimitRequestBody 215000000
    </Location>
    ```
    Más un redirect del 80 al 443 **sólo** para `/fiscalizacion` (`Redirect permanent /fiscalizacion
    https://192.168.5.104/fiscalizacion`). El resto del 80 **no se toca**.
12. **`scripts/admin-crear.ts`**: `node admin-crear.js <usuario> <red>`, con el rol owner, para el **primer**
    admin:
    - falla si ya existe algún admin activo;
    - crea el usuario, con la red normalizada como en `ip.ts`;
    - genera una clave temporal con `debe_cambiar_clave`;
    - audita `login_admin`;
    - imprime la clave una sola vez.

    Se ejecuta con `docker compose exec app node scripts/admin-crear.js admin 192.168.5.0/24`.
13. **`scripts/deploy.sh`**, que corre en la PC. Filosofía de los otros proyectos: verificar, construir, enviar y
    reiniciar.
    - Flags:
      - `--host root@192.168.5.104` por defecto (también desde `DEPLOY_HOST` de `.env.deploy`, que va en
        `.gitignore`);
      - `--sin-verificar`;
      - `--estado`;
      - `--logs`.
    - Pasos:
      1. `pnpm verificar`, salvo con `--sin-verificar`;
      2. `docker build -t fiscalizacion:<git-sha> --build-arg NEXT_BASE_PATH=/fiscalizacion .`;
      3. `docker save fiscalizacion:<sha> | gzip | ssh $HOST 'gunzip | docker load'`;
      4. `scp deploy/compose.prod.yml deploy/initdb/* deploy/apache-fiscalizacion.conf` a `/srv/fiscalizacion/`;
      5. en el servidor: `TAG=<sha> docker compose -f compose.prod.yml up -d`;
      6. esperar al healthcheck;
      7. `curl -k https://127.0.0.1/fiscalizacion/login` → 200;
      8. mostrar el estado.
    - **No** instala Apache ni toca otros sitios. Si `/srv/fiscalizacion/.env` no existe, lo genera **en el
      servidor** con claves aleatorias (`openssl rand`), con permisos `600` y sin imprimirlas.
14. **`deploy/README.md`**: instalación inicial, en este orden:
    1. instalar Docker y `mod_ssl` (ya hecho);
    2. generar el certificado autofirmado con SAN `IP:192.168.5.104`;
    3. incluir la conf de Apache;
    4. `firewall-cmd --add-service=https --permanent`;
    5. correr el primer deploy;
    6. crear el admin.

    Incluye también el backup (`pg_dump` vía `docker compose exec db` + `rsync` de archivos, con la app detenida
    según §11.1, adaptado a Docker) y la prueba de restauración.

### UI con basePath
15. Reemplazá los enlaces crudos por `conBase(...)`. Son estos:
    - `src/app/(app)/layout.tsx:23`: el `action="/logout"`;
    - `src/app/(app)/legajos/page.tsx:66`: el `action="/legajos"` del buscador;
    - `src/app/(app)/legajos/[id]/page.tsx:172,176`: los `href` a `/api/archivos/...`;
    - `src/app/(app)/legajos/[id]/componentes/SubirDocumento.tsx:82`: el `open('POST', '/api/documentos')`;
    - `src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx:44,49,52`.

    **Además, en el visor reemplazá `next/image` por un `<img>` común.** El optimizador de Next pediría
    `/api/archivos` desde el servidor sin la cookie del usuario (401) y fuera del guard y la auditoría. Con un
    comentario `eslint-disable-next-line @next/next/no-img-element` que lo explique. Si hay `images` en
    `next.config`, sacalo.
    Comprobación: con `grep -rn "'/api\|\"/api\|\`/api\|action=\"/" src/app` no queda ninguno sin `conBase`.

## Criterios
```
cd legajos && pnpm verificar
NEXT_BASE_PATH=/fiscalizacion NEXT_PUBLIC_BASE_PATH=/fiscalizacion pnpm build   # build con basePath ok
docker build -t fiscalizacion:prueba --build-arg NEXT_BASE_PATH=/fiscalizacion .   # en la PC
```
Además, **dentro de la imagen**:
- `docker run --rm --entrypoint sh fiscalizacion:prueba -c 'qpdf --version && vips --version && prlimit --version && id -u'`
  muestra qpdf ≥ 11, vips ≥ 8.12 y un uid distinto de 0;
- la validación de §13 funciona bajo `prlimit --as=512MiB` con los fixtures: agregá `scripts/validar-imagen.sh`,
  que copia `test/fixtures/archivos` al contenedor y corre `validarArchivo` contra cada uno.

Sin `any`. Sin commit ni push. **No te conectes al servidor**: el despliegue real lo hace el arquitecto.
