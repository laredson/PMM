# Tanda 01B - identidad e inventario cerrados

Fecha: 2026-09-18. Rama: `v1.5.0.1-PMM-reliability`.
Entrada: `74a47df7072f651c91ec114ff235e69bc8d1042a`.

## Resultado y limites

REL-02 queda cerrado para identidad e inventario estatico. VERSION, BUILD_ID y
RELEASE_MANIFEST concuerdan en 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b.
SHA256SUMS contiene 628 entradas para los 629 archivos versionados de PMM,
excluyendo solo su propio archivo. Los otros 625 archivos del paquete conservan
exactamente sus bytes, incluidos ejecutables, modulos, traducciones y UI.
No se certifica funcionamiento Windows ni ausencia de detecciones antivirus.

## Entrada verificada

ZIP aportado: `PMMv1.5.0.1.zip`, 53370602 bytes, SHA-256
`6a1721508a17ccf3c269ea1e3976d9502a7b918c0c72415026de8be3e1e40193`.
Su contenido versionado reproduce el arbol Git completo
`759d170d648a2f98fd7dc809b1b92e9fa34e7559`, exactamente el de la entrada remota.
No es solo una comparacion del numero de archivos. Se creo un indice Git local
para comparar, no para aparentar historia recuperada.

El ZIP no contiene .git ni Workspace. Su unico archivo ignorado por Git es
`PMM/Engine/oo2core_9_win64.dll`: se conserva en la entrada privada, pero NO se
incluye en la rama, inventario ni snapshot limpio entregado. No se elimina de
la instalacion del usuario ni se cambia la politica de adquisicion del programa.

El inventario anterior tenia 603 filas: faltaban 25 catalogos y habia cinco hashes
atrasados: Localization.ps1, README de localizacion, languages.json, VERSION.txt y
BUILD_ID.txt. Los bytes aportados coinciden con GitHub; este desfase no prueba
corrupcion de los ejecutables. El inventario nuevo se calcula desde los bytes
finales. No se cambian pins para aceptar dependencias inesperadas.

## Identidad

Los cuatro metadatos se modifican juntos. No se renumeran las versiones de
Host/Runtime (1.2.1), PMMCore (0.9.0), FixLab (0.2.0-variant-recipes), repak,
.NET ni los esquemas. Los hashes esperados de dependencias tampoco cambian.
La validacion historica se conserva bajo inheritedReleaseValidation, sin
atribuir sus resultados PASS a esta candidata de desarrollo.

releaseDate queda null porque la candidata no esta publicada. La busqueda
estatica de consumidores en fuentes encontro referencias en pruebas historicas
RC y en el preparador, no en el codigo activo distribuido consultado. Las pruebas
RC ya fijaban versiones antiguas; no se ejecutaron ni se alteraron para simular
un PASS. El validador actual Validate-v1.3.ps1 comprueba version/build y cobertura.
Aqui se ejecuto la comprobacion estatica equivalente en Python, no PowerShell/WPF.

## Evidencia nativa

Los SHA-256 recalculados de Host, Runtime y FixLab coinciden con sus pins y blobs.
`go version -m` leyo Go 1.23.2, windows/amd64, CGO_ENABLED=0 y trimpath=true en los
tres, sin ejecutarlos. NATIVE_ARTIFACTS.json conserva la metadata y hashes de
secciones PE originales. La tabla de certificados PE tiene longitud cero;
no se hizo una validacion Authenticode de Windows.

La conversacion previa describio candidatos Host/Runtime con coincidencias de
secciones. Al retomar solo persistian sus README, los binarios originales y el
snapshot antiguo; no persistian los .go, binarios candidatos ni sus informes
comparativos. Por tanto esas comparaciones quedan NO REPRODUCIDAS y REL-01
sigue pendiente. No se afirma que los candidatos nunca existieran: no se dispone
de evidencia reproducible para publicarlos ni declarar paridad. No se sustituyen
los nativos y la advertencia SOURCE_STATUS.md sigue vigente.

El hash VirusTotal `5be86567f597aefb64f1645a9b924c7de213da49206d7591b9e4f7f685fbcade`
coincide con el digest declarado por GitHub para el asset 537457024,
`PMM.1.3.0.RC30.stable.release.zip`, tag v1.3.0-Stable. Es un ZIP antiguo, no
PMM.exe. Se verifico la correspondencia en metadata de GitHub; no se descargo,
recalculo ni reescaneo ese asset y no se obtuvo la tabla de motores de VirusTotal.
Fuente: https://api.github.com/repos/laredson/PMM/releases/tags/v1.3.0-Stable

## Comprobaciones reproducibles

20 tests locales de herramientas: 12 del preparador y 8 del verificador.
Verificacion del paquete real: 628 hashes correctos, tres pins nativos y
201 pins de dependencias, incluidos 188 archivos del runtime .NET.
El preparador es idempotente sobre los bytes finales. No se ejecuto PMM,
Windows/WPF, antivirus ni CI remoto; no se creo release, tag ni PR.

Desde la raiz del repositorio:

```text
python Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b
```

Este modo comprueba solo archivos versionados. `--package <carpeta-PMM>` comprueba
TODOS los archivos de una distribucion limpia y rechaza cobertura incompleta o
archivos adicionales. Los checksums demuestran consistencia, no seguridad ni
procedencia del software por si solos. Ver SESSION01B_CHECKS.json.

Siguiente entrega: 02A, SOLO fuente candidata del Host, con codigo, receta y
pruebas conservados antes del cierre. NEXT_SESSION.md define la entrada exacta.
