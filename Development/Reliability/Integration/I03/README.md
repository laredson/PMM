# I03 - integracion controlada de localizacion

I03 porta a `v1.5.0.1-PMM-reliability` el trabajo aprobado del commit
`681f7994474ebfd6c2538775767d2002014170f7` de
`v1.5.0.0-PMM-translated`, adaptado a la arquitectura y al paquete I02.

## Identidad

- Base objetivo: `fcd4b5ef8401ada4b6b8c2d79b9477738e15a3ee`.
- Build: `PMM-v1.5.0.1-reliability-i03`.
- Version de producto: `1.5.0.1`.
- PMM tree: `e0c394997f1dbc172fef3cfc1a755f80f63e1692`.
- Paquete: 631 archivos, 630 checksums, 0 discrepancias.
- Host, Runtime y FixLab permanecen byte-identicos a I02.

## Alcance

- 30 idiomas registrados.
- 23 habilitados y completos:
  `en, es, fr, it, pt-BR, ro, de, pl, nl, ga, cs, uk, ru, ja, zh-CN, zh-TW, ko, hi, th, id, vi, tr, ar`.
- 7 reservas deshabilitadas:
  `bn, ur, mr, te, arz, pcm, ha`.
- English conserva default/fallback.
- El cambio de idioma sigue siendo seleccionar, aplicar, guardar y reiniciar.
- Se portan las excepciones RTL/LTR revisadas del donante.
- `Refresh-UI` restaura cualquier codigo habilitado mediante
  `Resolve-PMMLanguageCode`; se elimina la ruta antigua limitada a en/es.

Español conserva 58 claves dinamicas adicionales, todas heredadas. La lista queda
fijada por SHA-256
`14a47a3db8969d4864b8cdc6bfe28be68333946bdc89e2dd30a30fd5186147c4`.
Los otros 22 idiomas habilitados coinciden exactamente con las 1.292 claves
canonicas de English. Esta excepcion evita perder traducciones dinamicas ya usadas.

La cadena nueva de reliability que menciona `PMM Workspace folder` se añadió como
clave canonica 1.292. Reutiliza en cada idioma la traduccion ya aprobada de la
frase equivalente sobre `PMM folder`; no se inventaron textos nuevos.

## Verificacion local

- `verify_translation.py`: 30 registrados, 23 habilitados, 1.292 claves
  canonicas, cero faltantes, cero placeholders incompatibles.
- `test_verify_translation.py`: 3/3 PASS.
- `Test-Localization.ps1` con PowerShell 7: 23/23 PASS.
- `Test-PowerShell51.ps1`: 23/23 PASS, incluida carga WPF.
- `Smoke-Localization.ps1`: zh-CN, ar, vi, uk, cs y ga PASS.
- `verify_identity.py`: 631 archivos, 630 filas, 0 mismatches.
- Regresiones I02 heredadas: Desktop routing 14/14 y binding 32/32 PASS.

No se reconstruyen ejecutables: una integracion de JSON/PowerShell no justifica
cambiar los binarios C2B aceptados para prueba. Tampoco se ejecuto CI, Actions,
Palworld, antivirus ni una inspeccion visual humana completa de I03.

El propietario ya habia probado vi, uk, cs y ga en el donante y confirmo que
funcionaban. Esa evidencia no sustituye la prueba final del paquete I03 despues
de hacer Pull.
