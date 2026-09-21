# Estado actual - I03 localizacion integrada / 04A-6E arrays escalares V2

## Paquete ejecutable actual

`PMM/` es I03:
- version `1.5.0.1`;
- BUILD_ID `PMM-v1.5.0.1-reliability-i03`;
- PMM tree `e0c394997f1dbc172fef3cfc1a755f80f63e1692`;
- 631 archivos / 630 checksums / 0 mismatches;
- 30 idiomas registrados / 23 habilitados / 7 reservas.

I03 hereda el routing privado de I02 a `Workspace/.codex/config.toml` y
conserva byte-identicos Host C2B, Runtime C2B y FixLab original. No se
reconstruyeron binarios para una integracion de JSON/PowerShell.

## Localizacion I03

Donante fijado: `v1.5.0.0-PMM-translated@681f7994474ebfd6c2538775767d2002014170f7`.
English sigue como default/fallback. El idioma se selecciona, aplica, guarda y
entra en vigor al reiniciar; no hay cambio en vivo. `Refresh-UI` ya no reduce
el selector a en/es. Las excepciones RTL incluyen campos tecnicos virtualizados
sin forzar a LTR los textos mixtos de estado/log.

Validaciones locales:
- 1.292 claves canonicas; cero faltantes y cero placeholders incompatibles;
- 23/23 catalogos PowerShell 7 PASS;
- 23/23 cargas WPF PowerShell 5.1 PASS;
- smoke zh-CN, ar, vi, uk, cs y ga PASS;
- 3/3 pruebas Python I03 PASS;
- paquete e inventario PASS.

Español conserva 58 claves dinamicas adicionales autorizadas y fijadas por hash.
El propietario confirmo vi, uk, cs y ga en el donante. Falta ejecutar I03 completo
y comprobar visualmente persistencia, RTL/BiDi y pantallas reales tras reiniciar.

## Research conservado

04A-6E agrega V2 para recorrer arrays de escalares de ancho fijo sin editarlos y
lo valida desde UAsset hasta job/CLI candidato-only. NO se integra al FixLab
original. UAsset: 63 tests Go top-level, 32 Python y tres verificadores. CoreR1:
154 tests Go top-level, 54 Python PASS / 2 symlink SKIP y seis verificadores.
Ambos harnesses Windows pasaron x3; builds repetidos identicos. La evidencia 6D
de 2.000 publicaciones secuenciales y 500x4 concurrentes permanece vigente.
Win11, AV concurrente, disco lleno real, schema real y aceptacion Palworld siguen
pendientes.

No release, no tag, no PR, no workflow. No garantia antivirus/Nexus.
