Veredicto: CAMBIOS

- **ALTA nueva — §12.1:** `vips avg <tmp>` usa `fail_on=none`: puede aceptar JPEG truncados. Exigir `vips avg "<tmp>[fail_on=error]"` y verificar JPEG/PNG truncados. [Fuente libvips](https://github.com/libvips/libvips/blob/master/libvips/foreign/jpeg2vips.c).
- **ALTA nueva — §12.1:** exceptuar `qpdf --is-encrypted` de la regla «código distinto de 0 → 422»: devuelve **2 para PDF sin cifrar** y **0 para cifrado**; comprobar primero `--check`. [Manual](https://qpdf.readthedocs.io/en/12.0/cli.html).
- Comprobación bajo `--as=536870912`: qpdf 12.3.2, `--check` válido→0 y truncado→2; `--is-encrypted` válido sin cifrar→2. **vips/vipsheader no están instalados**; queda pendiente comprobar imágenes bajo ese límite.