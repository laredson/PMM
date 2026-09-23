# Indice historico - PMM reliability

Este indice permite reconstruir la historia del proyecto leyendo Git. Los archivos FINDINGS describen conclusiones/limites; los CHECKS guardan evidencias, hashes y recuentos. No sustituir evidencia historica por afirmaciones posteriores.

## Fundacion / identidad

### SESSION01 / SESSION01B
Archivos:
- `SESSION01_FINDINGS.md`
- `SESSION01B_FINDINGS.md`
- `SESSION01B_CHECKS.json`

Trabajo: inventario inicial, separacion de la linea reliability, identidad coherente 1.5.0.1, BUILD_ID s01b y regeneracion de checksums. El paquete queda 629 archivos / 628 checksums.

## Host

### SESSION02A
- `SESSION02A_FINDINGS.md`
- `SESSION02A_CHECKS.json`

Primera reconstruccion conservadora del Host en `NativeCandidates/Host/`. No source original recuperado y no sustitucion del binario empaquetado.

### SESSION02B
- `SESSION02B_FINDINGS.md`
- `SESSION02B_CHECKS.json`

Comparacion/correcciones del Host reconstruido: framing, prioridad de cierres/fallos y orden de foreground checks. Evidencia PE/build separada de equivalencia funcional.

### SESSION02C1
- `SESSION02C1_FINDINGS.md`
- `SESSION02C1_CHECKS.json`

Introduce `NativeCandidates/Supervision/` como modulo local compartido. Mejora supervision/cancelacion sin instalar candidatos.

### SESSION02C2A / SESSION02C2B
- `SESSION02C2A_FINDINGS.md`, `SESSION02C2A_CHECKS.json`
- `SESSION02C2B_FINDINGS.md`, `SESSION02C2B_CHECKS.json`

Cierre del canal Host/Runtime/UIBridge e integracion de los modulos compartidos. C2B produce las candidatas que posteriormente usa I01.

Hashes C2B autoritativos:
- Host `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`
- Runtime `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`.

## Runtime

### SESSION03A
- `SESSION03A_FINDINGS.md`
- `SESSION03A_CHECKS.json`

Reconstruccion Runtime inicial y contratos de UI/procesos.

### SESSION03B
- `SESSION03B_FINDINGS.md`
- `SESSION03B_CHECKS.json`

Refuerzo del inventario Runtime: lectura interrumpida, duplicados y errores de recorrido. No equivalencia Windows declarada.

## FixLab / REL-01

### SESSION04A
- `SESSION04A_FINDINGS.md`
- `SESSION04A_CHECKS.json`

Procedencia del PMMFixLab original. Binario original:
SHA-256 `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.
Se confirma que el source exacto no esta en el snapshot y que el overlay bootstrap historico esta corrupto. No repetir esa busqueda sin pista nueva.

Commit de cierre de procedencia conocido: `1b15621cf988bd7e582af19e46ea7ad81796fad8`.

### SESSION04A2 - PMMDLT1
- `SESSION04A2_FINDINGS.md`
- `SESSION04A2_CHECKS.json`
- modulo `NativeCandidates/FixLab/PMMDLT1/`

Codec delta acotado con hashes/limites/cancelacion. Commit conocido:
`f7c8359a8e0f089311cc01a6133bdfd9790e702a`.

### SESSION04A3 - PAKV11
- `SESSION04A3_FINDINGS.md`
- `SESSION04A3_CHECKS.json`
- modulo `NativeCandidates/FixLab/PAKV11/`

Perfil UE PAK v11 deliberadamente estrecho: ASCII, compact32, PHI/FDI, sin compresion/cifrado. Commit:
`a66cea06e673a169623b3c12821739b0fa6d0b9f`.

### SESSION04A4 - UAsset read
- `SESSION04A4_FINDINGS.md`
- `SESSION04A4_CHECKS.json`

Lector UAsset fijado a perfil cooked UE4 522 / UE5 1008 y revision UAssetAPI conocida. Commit:
`e8608cf0f0283180d99a1c88e085e1a78cfae295`.

### SESSION04A4B - RewriteNames
- `SESSION04A4B_FINDINGS.md`
- `SESSION04A4B_CHECKS.json`

`RewriteNames` solo sobre fuentes serializadas conocidas; cambios de ancho bloqueados si implican relocalizacion opaca. Commit:
`7b0a030ec3f5dd38249a6c47582d8f8c72cd1900`.

### SESSION04A4C - postProcess
- `SESSION04A4C_FINDINGS.md`
- `SESSION04A4C_CHECKS.json`

`PatchPostProcess` escalar ligado a schema/review; no se deriva schema de offsets. El offset 120 es comprobacion, NO permiso de escritura. Commit:
`4d8b0ca142dc55fbf066b1a18fac1658dfd6b87b`.

### SESSION04A5A - PlanCore
- `SESSION04A5A_FINDINGS.md`
- `SESSION04A5A_CHECKS.json`

Plan declarativo estricto, soporte/alternativas/familias/path safety. `PLAN_VALID` solo significa coherencia de metadata. Commit:
`a97966e351a307902d6d66ecd012a017ad6febb1`.

### SESSION04A5B - CaptureCore
- `SESSION04A5B_FINDINGS.md`
- `SESSION04A5B_CHECKS.json`

Snapshots privados de assets/archives, dossiers y bindings. No autentica build/semantica. Commit:
`d5af1bff255b94e0e47bf9b2ed6f3277712ae346`.

### SESSION04A5C - VerifyMembership
- `SESSION04A5C_FINDINGS.md`
- `SESSION04A5C_CHECKS.json`

Comprueba pertenencia byte-exact de todos los archivos declarados dentro de proveedores PAK pinneados usando PAKV11. Propiedad current conservadora: exactamente un proveedor; duplicados bloquean. Commit:
`587b4ed0c026ff97bb043fad84bd16d09803b02c`.

### SESSION04A6A - ExecuteBounded
- `SESSION04A6A_FINDINGS.md`
- `SESSION04A6A_CHECKS.json`
- `SESSION04A6A_PUBLICATION.json`
- contrato `NativeCandidates/FixLab/CoreR1/EXECUTION_CONTRACT.md`

Une captura + membership + plan/review y ejecuta SOLO el perfil acotado en memoria: nombres del mismo ancho, postProcess escalar, soporte y PAKV11. 104 tests Go / 44 Python en la evidencia de esa tanda; Windows test build compilado, no ejecutado. Publicacion final:
`fe239c33d1a77c47afa08502656f6e2cbe4f913d`.

### SESSION04A6B - PublishCandidate
- `SESSION04A6B_FINDINGS.md`
- `SESSION04A6B_CHECKS.json`
- `NativeCandidates/FixLab/CoreR1/PUBLICATION_CONTRACT.md`
- `NativeCandidates/FixLab/CoreR1/WINDOWS_PUBLICATION_ACCEPTANCE.md`

Guardado transaccional de `MemoryResult` a bundle candidato aislado, sin deploy al juego. Readback, rename sin reemplazo, manifest/completion, rollback acotado. 130 tests Go / 52 Python; race enfocado en 26 pruebas nuevas PASS; Windows-only compilado, no ejecutado. Commit:
`96287f98f59b7387a00b29cec7c9316800bde098`.

### SESSION04A6C - Windows real e interfaz candidata

- `SESSION04A6C_FINDINGS.md`
- `SESSION04A6C_CHECKS.json`
- `NativeCandidates/FixLab/CoreR1/INTEGRATION_CONTRACT.md`
- `NativeCandidates/FixLab/CoreR1/evidence/s04a6c/`

Continua desde I01B mientras el propietario prueba I01. Corrige fallos reales
del adapter de publicacion Win10 y agrega ExecuteAndPublishCandidate.
141 Test Go + 4 targets Fuzz con seeds PASS; 50 Python PASS / 2 SKIP;
harness independiente 40 PASS, dos builds identicos, 25 rondas concurrentes.
Win10 NTFS no elevado; aceptacion entre entornos parcial. PMM I01 intacto.

### SESSION04A6D - job V2/CLI y commit Windows por marcador

- `SESSION04A6D_FINDINGS.md`
- `SESSION04A6D_CHECKS.json`
- `NativeCandidates/FixLab/CoreR1/JOB_V2_CONTRACT.md`
- `NativeCandidates/FixLab/CoreR1/evidence/s04a6d/`

Agrega job V2 pinneado y CLI candidato-only que orquestan el perfil CoreR1 sin
install/deploy. El stress descubre que el rename de directorio Windows era
intermitente incluso secuencial; se reemplaza en Windows por commit atomico de
COMPLETE con RootDirectory de acceso minimo, sin retry. 152 tests Go top-level,
4 fuzz seeds, 54 Python, seis verificadores, harness x3, 2.000 publicaciones
secuenciales y 500x4 concurrentes PASS. Dos builds de harness/CLI reproducibles.
Win10 NTFS; Win11/SMB/AV/disco lleno/race siguen pendientes. PMM I02 intacto.

### SESSION04A6E - arrays escalares V2 acotados

- `SESSION04A6E_FINDINGS.md`
- `SESSION04A6E_CHECKS.json`
- `NativeCandidates/FixLab/UAsset/evidence/s04a6e/`
- `NativeCandidates/FixLab/CoreR1/evidence/s04a6e/`

Agrega `PMM_FIXED_UNVERSIONED_SCHEMA_V2` exclusivamente para recorrer
`ArrayProperty` de elementos escalares de ancho fijo, sin mutarlos ni relocalizar.
CaptureCore acepta la misma forma sin autenticar semantica y el escenario `array`
la valida hasta job/CLI candidato-only. UAsset: 63 tests Go top-level, 32 Python y
tres verificadores. CoreR1: 154 tests Go top-level, 54 Python PASS / 2 SKIP y seis
verificadores. Harnesses Windows x3, builds repetidos byte-identicos, vet y
cross-build Linux PASS sin ejecucion. Schema real, containers complejos,
relocalizacion y aceptacion Unreal/Palworld siguen pendientes. PMM I02 intacto.

## Primera integracion ejecutable

### SESSION_I01
- `SESSION_I01_FINDINGS.md`
- `SESSION_I01_CHECKS.json`
- `Integration/I01/README.md`
- `Integration/I01/assemble.py`
- `Integration/I01/evidence/`

Se ensambla una aplicacion real de prueba usando Host/Runtime C2B y FixLab original. Cinco archivos del paquete cambian. Build `PMM-v1.5.0.1-reliability-i01`. 92 tests Go + 12 Python del ensamblador y Windows vet; aun sin ejecucion Windows real.

El conector del chat no pudo transferir los dos EXE grandes, asi que el commit documental conserva receta/evidencia, pero `PMM/` remoto sigue s01b. Commit:
`552a4562b53a7142dfc8c2e5a67abacd6b79b61e`.

### SESSION_I01B
- `SESSION_I01B_FINDINGS.md`
- `SESSION_I01B_CHECKS.json`

Un entorno Windows con checkout local reconstruye Host/Runtime C2B con Go 1.23.2,
reproduce los hashes fijados e integra en `PMM/` los cinco archivos I01. El arbol
del paquete queda `12e01ba3a24a2c0ce5e74d681b4931307c845a56`, con 628 checksums y
0 mismatches. La publicacion binaria pendiente de SESSION_I01 queda cerrada; la
aceptacion funcional Windows del programa sigue pendiente del propietario.

## SESSION_I03_TRANSLATION
- `SESSION_I03_TRANSLATION_FINDINGS.md`
- `SESSION_I03_TRANSLATION_CHECKS.json`
- `Integration/I03/`

Integra semanticamente el commit de traducciones
`681f7994474ebfd6c2538775767d2002014170f7` sobre I02. El paquete I03 registra
30 idiomas, habilita 23, conserva siete reservas y mantiene los tres ejecutables
byte-identicos. PowerShell 7 valida 23 catalogos; PowerShell 5.1 carga las 23
ventanas WPF; el usuario debe completar la aceptacion visual/persistencia I03.

## Documentos transversales

- `IMPLEMENTATION_PLAN.md`: REL-00..REL-07.
- `SESSION_PLAN.md`: orden operativo de sesiones/areas.
- `NATIVE_ARTIFACTS.json`: inventario nativo.
- `WINDOWS_HOST_ACCEPTANCE.md`
- `WINDOWS_RUNTIME_ACCEPTANCE.md`
- `WINDOWS_UIBRIDGE_ACCEPTANCE.md`
- `TRANSLATION_INTEGRATION.md`
- `RUNNING_VERSION.md`
- `NEXT_SESSION.md`
- `STATUS.md`.

## Como usar este indice

Para retomar una etapa concreta, leer primero su FINDINGS y luego CHECKS/contrato. Si un documento mas nuevo dice que una publicacion pendiente ya se resolvio, eso actualiza el estado de entrega pero NO reescribe las condiciones de prueba del archivo historico.

No deducir "PASS" de un commit existente. Revisar siempre si la prueba fue estatica, Linux, compilacion Windows o ejecucion Windows real.

## INTEGRATION_I04_NEXUS_UPDATES
- `Integration/I04/README.md`
- `Integration/I04/prepare_i04.py`
- `Integration/I04/verify_i04.py`
- `Integration/I04/evidence/package-checks.json`

Prepara sobre I03 el flujo Nexus visible y recuperable: cliente/credencial DPAPI,
plan por fingerprint, `nxm://` Free validado, descarga/extraccion acotadas,
Deep Analysis previo, archivo indefinido, rollback y despliegue transaccional.
Los tres ejecutables permanecen byte-identicos. La cuenta Nexus real, SSO y
Palworld siguen pendientes. El cambio aun no se ha publicado.

## PMM v1.5.0.2 - nueva linea

### V1502_BOOTSTRAP

- `V1502_HISTORY.md`
- `V1502_STATE.json`
- `V1502_PLAN.md`
- `Incidents/STARTUP_PRE_UI_2026-09.md`

La rama `v1.5.0.2` nace directamente del commit
`2586b4c3999ccc094344bc65710d6559f4858871` de la linea reliability, por lo que
hereda I03 (23 idiomas habilitados) e I04 Nexus Updates completos.

El bootstrap no modifica `PMM/`: el paquete conserva identidad 1.5.0.1/I04 hasta
la primera integracion funcional 1.5.0.2, momento en que VERSION, BUILD_ID,
manifiesto y checksums deben moverse juntos.

Se registra tambien STARTUP-PRE-UI-2026-09: fallo observado despues del splash y
antes de UI, una vez por el propietario y posteriormente por un usuario chino.
No es reproducible actualmente por el propietario y su causa sigue UNKNOWN.

Nota de continuidad I04: aunque el registro original de I04 conserva el estado
"pendiente de publicacion" de aquella tanda, la base fijada para v1.5.0.2 ya
contiene sus cambios en el historial posterior de la rama reliability. No
reescribir la evidencia historica; usar V1502_STATE/STATUS para el estado actual.


### V1502_ARCHITECTURE_DECISION_TRANSCRIPT

- `V1502_DECISION_TRANSCRIPT_2026-09-23.md`

Preserves the owner/assistant discussion that selected the one-PMM-owned-EXE,
open/module-oriented architecture, deferred signing, Nexus/noflag direction and
AI-created-mod responsibility model. It is context only; the authoritative
implementation contract is `V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`.
