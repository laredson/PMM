# SESSION04A6D - job V2 candidato-only y commit Windows estable

Entrada: `e6324e6cf6e0163ea210cdbe930f611961743b0a`, rama
`v1.5.0.1-PMM-reliability`. El propietario confirmo que I02 arranca y funciona y
autorizo continuar. Alcance: CoreR1 aislado, CLI/harness externos y handoff. No se
modifico ni ejecuto `PMM/`, Palworld, FixLab original, release, PR o Actions.

## Resultado

Se implemento `PMM_R1_CANDIDATE_JOB_V2` y un CLI separado que reconstruyen en un
solo proceso PlanCore, CaptureCore, VerifyMembership, ExecuteBounded y
PublishCandidate. El job fija por SHA-256/tamano todos los documentos y exige:

- `candidateOnly=true`;
- `installRequested=false` y `deployRequested=false`;
- las tres raices protegidas reales y un padre de publicacion externo;
- una sola ejecucion/publicacion, sin retry ni importar evidencia serializada.

El resultado conserva estados de rechazo/residuo/commit. El CLI solo acepta
`run --job <absoluto> --job-sha256 <hex> --job-bytes <n>`, escribe JSON a stdout
y usa exit 0/3/2 para exito/rechazo/uso. No es PMMFixLab.exe y no instala.

## Defecto Windows descubierto y correccion

El stress amplio expuso que el rename de un directorio Windows tras cerrar sus
hojas era intermitente: `STATUS_ACCESS_DENIED (0xc0000022)` aparecio incluso en
publicacion secuencial. Compartir DELETE en el padre, compartirlo en staging,
serializar por padre y usar FileRenameInformationEx no eliminaron el fallo; no se
conservo ninguno como parche aparente y no se agregaron retries.

Windows ahora crea directamente el namespace aleatorio final, escribe COMPLETE
como `.pmm-complete-pending` y conserva abiertas las cuatro hojas verificadas.
El commit es el rename no-replace del handle del marcador a `COMPLETE.json`.
InspectCandidate rechaza el directorio antes del marcador. Linux mantiene
`.pmm-stage-*` + `renameat2(RENAME_NOREPLACE)`.

La documentacion Microsoft indica que RootDirectory debe abrirse con traverse +
read-attributes para evitar conflictos con la apertura interna del destino. La
prueba directa reprodujo `STATUS_SHARING_VIOLATION (0xc0000043)` al reutilizar el
handle amplio y paso 100/100 al retener un ancla minima verificada. El rollback
abre un handle DELETE separado y vuelve a comparar volume/file-ID antes de borrar.

Resultado final Win10 19045/NTFS:

- 2.000 publicaciones secuenciales: PASS;
- 500 tandas de cuatro publicaciones concurrentes: PASS (2.000 candidatos);
- rollback, cancelacion, cierre abrupto, DACL, Unicode, junction, hardlink,
  destino ocupado y errores post-commit: PASS.

## Evidencia

- Suite Go con seis opt-ins: 317 eventos PASS, 152 tests top-level PASS,
  3 eventos SKIP, 0 FAIL.
- Cuatro targets fuzz con corpus semilla: PASS; no fuzz aleatorio.
- 56 tests Python: 54 PASS, 2 SKIP por privilegio symlink.
- Seis verificadores Python independientes: PASS.
- Job exportado SHA-256
  `927262fa09ccd3977467ec3a27e57fdbaf9bcb7a2e41d25097f7031c7c75e7f5`;
  10 outputs comparados, candidateOnly true, gameAccepted/installed false.
- Dos builds byte-identicos:
  - harness: `7d09da6c001d926d077fd32863f2fd31c6708fd98330106d35a4f0caeebd2d8c`,
    6860288 bytes;
  - CLI: `0464e503a96f467e96501d0e71367027501640b7433bb1bd76cb1e159cd781bc`,
    4353536 bytes.
- Harness completo ejecutado con `-test.count=3`: PASS.
- CLI final: publica fixture (2 -> 3 candidatos), pin falso -> exit 3/PIN,
  uso incompleto -> exit 2.
- go vet Windows/Linux y cross-build Linux/amd64: PASS; Linux NO ejecutado.

Fixtures/builds externos: `C:/GPT-Local/Releases/PMM/s04a6d-*`. Evidencia durable:
`NativeCandidates/FixLab/CoreR1/evidence/s04a6d/`.

## Limites y siguiente frontera

No hubo race detector (gcc/clang/zig ausentes), Windows 11, SMB/ReFS, disco lleno
real, AV instrumentado, corte electrico, assets reales ni aceptacion Unreal/
Palworld. El CLI solo orquesta el perfil CoreR1 acotado; faltan semantica completa
V2, schemas/serializers reales, relocalizacion variable/bulk, UI/autenticacion de
politica e integracion final. No sustituir PMMFixLab.exe todavia.

I02 permanece `PMM-v1.5.0.1-reliability-i02`, tree
`9ef22d5815943ce50413dfa7e09b474b06a22860`, 629 archivos / 628 checksums /
0 mismatches. El arranque funcional basico fue confirmado por el propietario;
faltan cierre, segundo arranque, UI detallada y tiempos si aun no los reporta.
