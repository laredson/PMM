# Estado actual - PMM v1.5.0.2

## Rama

`v1.5.0.2`

Base heredada:
`2586b4c3999ccc094344bc65710d6559f4858871`
(`v1.5.0.1-PMM-reliability`, I04).

La rama conserva I03/I04 y todas las funciones del HEAD heredado. El bootstrap/documentacion no ha cambiado aun los bytes de `PMM/`.

## Direccion aprobada para 1.5.0.2

Documento autoritativo:

`Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`

Objetivo arquitectonico:
- un unico ejecutable **propio** de PMM;
- multiples procesos aislados pueden ejecutar el mismo PMM.exe como workers;
- Modules/Resources/CKL permanecen expuestos/editables donde tenga sentido;
- herramientas/binarios externos no se absorben por el mero hecho de ser EXE;
- FixLab solo se unifica cuando la reconstruccion tenga paridad suficiente.

## Producto que 1.5.0.2 debe dejar funcional

1. Updates de mods de acuerdo con el comportamiento definido, empezando por Nexus.
2. Analisis/conflictos y parche de compatibilidad.
3. Restauracion/reparacion de mods antiguos mediante Fix Lab.
4. Creacion de mods dirigida por IA.

En el punto 4:
- la IA es la responsable principal de crear la solucion/mod pedido por el usuario;
- PMM ofrece herramientas, evidencia, staging, build, validacion, despliegue/rollback y pruebas/observacion permitidas;
- un editor interno general no es requisito de 1.5.0.2.

## Baseline heredado que no se debe perder

- paquete actual aun identificado como 1.5.0.1 I04 hasta la primera integracion funcional;
- 30 idiomas registrados;
- 23 habilitados;
- 7 reservas;
- I04 Nexus Updates;
- Host/Runtime C2B;
- FixLab original distribuido + research/candidatas 04A-6E;
- Workspace;
- deploy/rollback/recovery;
- Deep Analysis;
- AIIO y flujos actuales.

## Hallazgos relevantes ya conocidos

- Host -> Runtime es nativo, pero la UI WPF normal sigue pudiendo arrancar PowerShell con `-ExecutionPolicy Bypass`.
- Normal Runtime startup puede entrar en reparacion/descarga de dependencias antes de UI si detecta componentes faltantes/invalidos.
- `OperationWorker.ps1` sigue siendo broker amplio de operaciones.
- hay mas rutas PowerShell con Bypass en workers/servicios.
- el build nativo actual post-procesa los PE para insertar icono; NF05 lo sustituira por recursos Windows convencionales.
- el VirusTotal historico registrado corresponde a una release RC30 antigua, no prueba el estado de 1.5.0.1/1.5.0.2.
- Authenticode/SignPath es opcional y posterior; no es requisito de cierre de 1.5.0.2.

## Incidencia STARTUP-PRE-UI-2026-09

Estado:
**OPEN / NOT REPRODUCED / CAUSE UNKNOWN / WATCHPOINT**

No es el siguiente trabajo activo.

No atribuir a locale, antivirus, Workspace, PowerShell u otra causa sin evidencia.

Si reaparece durante las pruebas posteriores, capturar evidencia y tratarla entonces.

## Progreso del nuevo plan

- NF00 plan/contrato: **CLOSED**
- NF01 baseline + matriz de migracion: **NEXT**
- NF02 unificacion Host/Runtime: PENDING
- NF03 startup/politica/dependencies hardening: PENDING
- NF04 workers single-EXE: PENDING
- NF04F FixLab convergence: PENDING
- NF05 build PE convencional/reproducible: PENDING
- P01 Updates: PENDING
- P02 Compatibility patch: PENDING
- P03 FixLab old-mod restoration: PENDING
- P04 AI-created mods via PMM capabilities: PENDING
- NF06 full regression: PENDING
- NF07 scanner/Nexus candidate validation: PENDING
- NF08 optional signing/provenance: OPTIONAL/LATER

Continue in `NEXT_SESSION.md`.
