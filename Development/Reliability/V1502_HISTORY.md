# Historial de arranque - PMM v1.5.0.2

Este archivo marca el inicio de la linea 1.5.0.2 y evita perder continuidad con el trabajo anterior.

## Origen exacto

Fecha de apertura de la linea: 2026-09-22.

Rama creada: `v1.5.0.2`.

Commit de origen:
`2586b4c3999ccc094344bc65710d6559f4858871`

Origen nominal:
`v1.5.0.1-PMM-reliability`.

El tag `v1.5.0.1` y la rama reliability apuntaban a ese mismo commit al fijar esta base.

## Que se hereda

No se parte de 1.5.0.0 ni de una release vieja. Se hereda todo el HEAD de reliability.

### I03 - Localizacion
- 30 idiomas registrados.
- 23 habilitados.
- 7 reservas.
- nativeName, RTL/LTR y compatibilidad heredada.
- traducciones integradas semanticamente sobre la linea de fiabilidad.

### I04 - Nexus Updates
- subpestana Updates;
- flujo de Check Updates;
- credencial Nexus personal protegida en Workspace;
- soporte Premium y flujo Free por `nxm://`;
- descarga/extraccion acotadas;
- analisis previo;
- archivo, rollback y recuperacion;
- binarios nativos conservados.

### Nativos y research
- Host C2B distribuido.
- Runtime C2B distribuido.
- PMMFixLab original distribuido.
- research/candidatas FixLab hasta 04A-6E conservados fuera del ejecutable distribuido salvo integraciones ya documentadas.

## Por que se abre 1.5.0.2

Dos lineas de trabajo deben converger sin seguir cargando cambios sobre 1.5.0.1:

1. reducir falsos positivos y mejorar la distribucion para Nexus/antivirus mediante hardening verificable;
2. investigar un fallo real de startup entre la barra de carga y la UI.

El objetivo no es cambiar el numero para "reiniciar" el proyecto; es congelar 1.5.0.1 como baseline y trabajar directamente en una nueva rama.

## Incidencia historica de arranque

Reporte del propietario:
- en su primer arranque de 1.5.0.1 aparecio un error despues de la barra de carga y antes de la UI;
- el segundo arranque funciono y desde entonces no ha conseguido reproducirlo.

Reporte posterior:
- aproximadamente dos dias despues, un usuario chino comunico un fallo del mismo tipo;
- segun el reporte, ese usuario no consigue que PMM llegue a iniciar.

Intentos del propietario:
- borrar Workspace;
- instalacion nueva;
- no reproducen actualmente el fallo.

No se conserva en este momento el texto exacto del error. No se afirma que ambos reportes sean byte/stack-identicos; se agrupan por el mismo punto aparente del startup hasta tener evidencia mejor.

Archivo autoritativo de la incidencia:
`Incidents/STARTUP_PRE_UI_2026-09.md`.

## Estado del paquete al crear la rama

El bootstrap de 1.5.0.2 no cambia `PMM/`.

Por tanto el paquete sigue mostrando:
- VERSION 1.5.0.1;
- BUILD_ID `PMM-v1.5.0.1-reliability-i04-nexus-updates`.

Esto evita romper manifiesto/checksums por una renumeracion cosmetica. La primera integracion funcional 1.5.0.2 cambiara VERSION, BUILD_ID, manifiesto y checksums juntos.

## Continuidad del plan anterior

El plan REL-00..REL-07 no se descarta. Se reagrupa en `V1502_PLAN.md`:

- S01: startup/evidencia;
- S02: procesos/PowerShell;
- S03: dependencias check/repair;
- S04: broker;
- S05: build/PE;
- S06: firma;
- S07: preflight/escaneos;
- S08: submissions de falsos positivos si aun hacen falta.

Los FINDINGS/CHECKS anteriores siguen siendo evidencia historica y no se reescriben.


## PRE-NF01 - continuity, local index and development package identity (2026-09-23)

Before starting NF01, the project continuity model was reorganized so a new Codex/chat/developer can continue directly from Git without an external handoff.

Added canonical continuity layer:
- `Development/Handoff/CURRENT_HANDOFF.md`;
- `Development/Handoff/CURRENT_STATE.json`;
- `Development/Handoff/HISTORY_REGISTRY.json`;
- `Development/Handoff/README.md`.

Historical FINDINGS/CHECKS/old handoffs were deliberately not moved or rewritten. They remain immutable evidence and are classified by the registry.

Added local repository indexing:
- `Development/Tools/build_repo_index.py`;
- generated output lives under ignored `.pmm-index/`;
- index records tracked files, classifications, symbols, process/network signals and path-reference candidates.

Adopted normal Codex/developer workflow:
- local clone;
- fetch + fast-forward only;
- clean working tree;
- refresh local index when HEAD changes;
- advance as far as safely possible in the current prompt/gate;
- one coherent development commit per prompt;
- update continuity/state/history/next in the same commit when project state changes;
- compare result against the original plan and record any superior plan modification explicitly.

Package identity was moved coherently to the active development line:
- VERSION `1.5.0.2`;
- BUILD_ID `PMM-v1.5.0.2-development-baseline`;
- RELEASE_MANIFEST identity updated;
- SHA256SUMS updated for the changed package metadata.

I03/I04 remain feature/integration provenance. This renumbering does not claim NF01+ implementation is complete.

NF01 remains the next functional/research block.


## NF01 - baseline and migration inventory (2026-09-23)

NF01 inspected the exact v1.5.0.2 branch at HEAD `4d14627ce111aa416491f1fa278473354e70550d`.

The normal local clone was attempted first but the execution container could not resolve `github.com`. Work continued against the authenticated exact branch tree. This is recorded rather than being misrepresented as a local run.

NF01 established:
- executable tree identities/sizes and package SHA pins;
- Host route/supervision contract;
- Runtime subcommands and generic process boundary;
- startup dependency repair/network behavior;
- OperationWorker operation/progress/result/lock/journal contracts;
- current FixLab native requirements/build interface;
- verified Bypass launch families;
- major source divergence between old Development/Source snapshots and later NativeCandidates;
- NF02A migration/rollback/Windows acceptance design.

Architectural refinement:
the one-EXE target will retain Host/Runtime isolation by launching the same executable as a separate Runtime child:

`PMM.exe -> PMM.exe runtime start`

NF02A will establish a new canonical source at `Development/Source/PMM/` instead of promoting the stale snapshots.

NF01 remains open only for a short local confirmation gate: local SHA recomputation + generated index + exhaustive grep.


## NF02A - unified canonical source consolidation (2026-09-23)

The local-clone NF01-L gate was attempted again but the execution container still could not resolve github.com.

Work advanced without pretending that gate passed.

A new canonical Go module was created at:
`Development/Source/PMM/`

It consolidates the latest Reliability Host, Runtime, Supervision and UIBridge candidates.

Key migration behavior:
- default invocation remains Host;
- `runtime` prefix dispatches to the internal Runtime role;
- Host native routes that logically target PMMRuntime are translated to a self-child invocation of the same executable;
- Host/Runtime remain separate OS processes;
- current external editable UI/modules/resources remain external.

No distributed executable was replaced and no package feature behavior was intentionally changed.

Added:
- offline build script;
- dispatcher tests;
- migrated candidate tests;
- Windows acceptance checklist;
- canonical source-status documentation.

NF02A now awaits a real local build plus Windows acceptance.


## NF02A compile proof - connector-backed reconstruction (2026-09-23)

The environment again failed to clone GitHub because outbound DNS/connectivity is unavailable.

To avoid blocking the development gate, the canonical `Development/Source/PMM/` source was reconstructed locally from the exact branch files available through the authenticated GitHub connector and compiled with Go 1.23.2.

The staged reconstruction initially failed only because not all Runtime source files had yet been materialized. After materializing the canonical files, no actual NF02A source compile error remained.

Validation reached:
- dispatcher test PASS;
- Runtime/Supervision/UIBridge Linux compile PASS;
- Host Windows test cross-compile PASS;
- Runtime Windows cross-compile PASS;
- unified Windows GUI executable cross-build PASS;
- PE32+ x86-64 / GUI subsystem verified.

The reconstruction candidate is 6,526,464 bytes with SHA-256
`e0ad8c0a4cc872f30c7077428aedcc66895966111bfc95a38d0e3bb8cd0cae14`.

That hash is deliberately **not** treated as a release/canonical candidate hash because the build was not made from a literal Git clone and not every migrated remote test file was materialized.

No distributed package binary changed.

The canonical build script was improved to record per-file source SHA-256 inventory and corrected the build-report field name to `pmmRuntimeRemoved`.

Next gate: exact-clone build confirmation, then Windows acceptance.


## NF02A integration preparation / NF02B split (2026-09-23)

The exact clone was attempted again and failed because the execution container
still cannot resolve github.com. No Windows/Wine runtime is available either.

Package integration was therefore correctly withheld.

Canonical source/tooling preparation:
- Host/Runtime doctors no longer require PMMRuntime.exe;
- native-shell wording reflects same-binary Runtime mode;
- Host same-executable route test added;
- build report V2 cross-compiles every Windows package test set and validates PE metadata;
- disposable Windows staging tool added;
- staging route rewrite tested against current routes.json: all five native Runtime routes converted to PMM.exe runtime form.

A direct-caller risk was promoted into the formal plan:
NF02A accepts/integrates the unified PMM.exe while retaining PMMRuntime.exe;
NF02B migrates all remaining direct callers; NF02C deletes the legacy executable.

This prevents a startup-successful but feature-broken single-EXE transition.


## NF02A Windows gate blocked; NF02B distributed PowerShell pre-inventory (2026-09-23)

The exact local clone was attempted again and failed before authentication because
the execution container cannot resolve github.com. No Wine/Windows runtime is
installed.

NF02A acceptance and package integration were therefore correctly withheld.

To advance without changing product behavior, the exact branch tree was used to
read all 132 distributed PMM PowerShell scripts.

The scan found 13 active PMMRuntime consumer files and 18 direct native
invocations:
- 10 archive create;
- 4 archive extract;
- 2 dependencies ensure;
- 1 UI;
- 1 self-test.

The central migration point is `Get-PMMRuntimePath` in Shared/Paths.ps1.
ModuleRuntime's binary snapshot keeps PMMRuntime until NF02C.

No PMM product file was changed in this prompt.
