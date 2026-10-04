# Sistema de Legajos para Fiscalización — Requisitos v0.2

> Fuente: el pedido de Emilio y sus respuestas del 2026-10-04. Lo que no está acá **no se asume**:
> va a "Preguntas abiertas".

## 1. Contexto
La sección de **Fiscalización** atiende los casos de **múltiple cedulación**: personas detectadas con más de una
cédula de identidad. Cada caso se lleva en un **legajo** que agrupa todas las cédulas de la persona, los
documentos escaneados y el historial de interacciones con el interesado (por ejemplo: se presenta y se le pide
certificado de vida y de residencia).

- Usuarios internos de la institución. Corre en un **servidor de la institución**, en la red interna.
- Los datos se cargan en este sistema, desde cero. Volumen esperado: **cientos de legajos**.

## 2. Alcance funcional

### 2.1 Legajo
- Agrupa las cédulas de **una** persona detectada con múltiple cedulación. Un legajo es un **caso**: la misma
  cédula **puede** aparecer en más de un legajo. Si se carga un número que ya existe en otro legajo, el sistema
  **avisa y muestra esos legajos**, pero deja seguir. Cada legajo lista sus legajos relacionados por número de cédula.
- **Nº de legajo automático por año:** `2026-0001`, `2026-0002`… Es único y no se reutiliza.
- **Fecha de detección** y **observación general**.
- Tiene un **estado** tomado de un catálogo **configurable** por el admin. El estado **sólo cambia mediante una
  interacción**, que lleva nota. La fuente de verdad es el estado actual del legajo, y cada cambio queda en el historial.
- Búsqueda por número de cédula (cualquiera del legajo) y por nombre o apellido (de cualquiera de sus cédulas).

### 2.2 Cédulas del legajo (original y duplicados)
Por cada cédula:
- número;
- nombres y apellidos (pueden diferir entre cédulas);
- fecha de nacimiento;
- fecha de emisión;
- marca **original**: **como máximo una** por legajo; las demás son duplicados. Se puede crear un legajo con
  una sola cédula y sin original marcada, y completarlo después;
- observación.

### 2.3 Documentos
- **Tipos de documento configurables**, por ejemplo: nota, certificado de nacimiento, de casamiento, de vida o de
  residencia. Cada tipo define:
  - nombre;
  - si es **obligatorio**, para mostrar lo que falta en cada legajo;
  - **vencimiento** en días, opcional. Cuenta desde la **fecha de expedición** que figura en el documento y que se
    carga al subirlo. A partir de ahí se calcula "vigente" o "vencido" y se avisa;
  - si admite **varios archivos**: por ejemplo, una nota de 3 páginas como un documento con 3 archivos ordenados.
- Formatos **PDF, JPG y PNG**, con un máximo de **20 MB por archivo**, validado por contenido y no sólo por extensión.
- Subida de archivos. **La base guarda sólo el path**. Los archivos viven en una carpeta del mismo servidor
  (`<RAIZ>/legajos/<legajo_id>/<documento_id>/<n>.<ext>`), con backup aparte.

### 2.4 Historial de interacciones
Cada interacción guarda:
- fecha, usuario y nota;
- **tipo de interacción**, configurable: se presentó, notificación, llamada…;
- **documentos solicitados**, cada uno con su estado: pendiente o recibido. Al recibirse, se vincula al documento cargado;
- **cambio de estado** del legajo, opcional: la interacción lo deja registrado.

### 2.5 Usuarios y seguridad
- Login con **usuario y contraseña**, hasheada con argon2id o bcrypt.
- Roles:
  - **admin:** todo, incluidos usuarios, catálogos, IPs y **anulaciones**;
  - **operador:** crea legajos y cédulas, sube documentos, registra interacciones y cambia el estado. **No anula**;
  - **consulta:** sólo lectura, pero **ve y descarga** los documentos.
- **Restricción por IP por usuario.** Cada usuario tiene su lista de IPs o rangos CIDR permitidos. Fuera de
  ella → acceso denegado. **Un usuario sin IPs no entra.** El admin también está restringido y se recupera con
  el comando local (§2.6.6).
- **Registro de accesos:**
  - logins correctos y fallidos;
  - IPs rechazadas;
  - con usuario, IP, fecha y resultado.
- **Nada se borra.** Las cédulas, documentos e interacciones se **anulan con motivo**. Toda alta, cambio o
  anulación queda en una **auditoría**, con usuario, fecha, valores anteriores y nuevos.

### 2.6 Reglas de seguridad (auditoría de codex, no negociables)
1. **IP real:** se toma de la conexión; `X-Forwarded-For` sólo se acepta si viene de un proxy configurado como
   confiable. La app no se expone salteando el proxy.
2. **La IP se chequea en cada request protegido**, no sólo en el login: páginas, API, Server Actions y descargas.
   Un cambio en la lista rige de inmediato.
3. **IPs y CIDR se validan y comparan con una biblioteca**, normalizando `::ffff:a.b.c.d` a IPv4. Nunca se
   compara por prefijo de texto.
4. **Archivos:** fuera de `public`. Se sirven sólo por id de documento, después de chequear sesión, rol e IP. El
   nombre en disco lo genera el servidor (UUID + extensión validada). El nombre original es sólo un metadato.
   Al resolver la ruta se verifica que la ruta canónica quede dentro de la raíz. Nunca se sobrescribe: reemplazar
   crea una versión nueva.
5. **Login:** límite de intentos por cuenta y por IP, con bloqueo temporal. Mensaje genérico ("usuario o
   contraseña incorrectos"). Todo queda en el registro de accesos.
6. **Recuperación del admin:** comando local en el servidor (CLI) para restablecer el acceso, también auditado.

## 3. Stack
Next.js (App Router) + PostgreSQL, con sesión propia por usuario y contraseña. Archivos en disco local.
Despliegue en el servidor de la institución: a definir si es con Docker o con Node + PM2.

## 4. Catálogos de arranque (editables por el admin)
- **Estados:** Detectado, Notificado, En trámite, Resuelto, Archivado.
- **Tipos de interacción:** Se presentó, Notificación, Llamada, Entrega de documentos.
- **Tipos de documento:** los del pedido, para confirmar: Nota (varios archivos), Certificado de nacimiento,
  Certificado de casamiento, Certificado de vida (con vencimiento), Certificado de residencia (con vencimiento).

## 5. Preguntas abiertas (no bloquean empezar el modelo)
1. **Servidor:** ¿qué sistema operativo tiene? ¿Se permite Docker? ¿Hay HTTPS interno? ¿Hay un proxy delante?
   Esto define cómo se lee la IP real.
2. **Vencimientos:** propuesta para v1: aviso en pantalla y listado de vencidos, sin emails.
3. **Certificados de vida y residencia:** los días de vencimiento de cada uno.
4. **Solicitudes:** propuesta: se solicita un **tipo** de documento. La solicitud queda "recibida" al cargar un
   documento de ese tipo en el legajo, y vuelve a "pendiente" si ese documento se anula.
5. **Catálogos en uso:** propuesta: se **desactivan**, no se borran. Si cambia el vencimiento o la obligatoriedad,
   se aplica a todos los documentos, incluidos los que ya existen.
