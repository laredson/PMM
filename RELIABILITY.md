# PMM v1.5.0.1 - fiabilidad

Rama: `v1.5.0.1-PMM-reliability`. Rama de idiomas independiente, no modificada.

**Ultima tanda: 03A cerrada en su alcance.** Runtime candidato reconstruido,
compilado y conservado con receta offline, evidencia y contrato con la UI.
No se ha recuperado el original ni certificado equivalencia funcional.

El programa distribuido sigue intacto: 629 archivos, 628 hashes, version 1.5.0.1,
build `PMM-v1.5.0.1-reliability-s01b`. Ninguna candidata reemplaza los ejecutables.

## Continuar

[Development/Reliability/NEXT_SESSION.md](Development/Reliability/NEXT_SESSION.md)
fija **03B: comparacion y gate de Runtime**, no repetir 01B/02A/02B/03A.
[STATUS.md](Development/Reliability/STATUS.md) contiene el estado actual y
[SESSION_PLAN.md](Development/Reliability/SESSION_PLAN.md) las tandas pendientes.

## Evidencia nueva

[SESSION03A_FINDINGS.md](Development/Reliability/SESSION03A_FINDINGS.md) y
[SESSION03A_CHECKS.json](Development/Reliability/SESSION03A_CHECKS.json).
Fuente completa en `Development/Reliability/NativeCandidates/Runtime/`, con
README, build.py, tests, UI_PROCESS_CONTRACT.md y evidence/.

S03A conserva dependencias y seleccion de PowerShell; distingue presentacion WPF
de utilidades CLI. Su hash repetible en el entorno registrado es
`10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f`.
13 tests Go y 9 Python pasaron; no prueban Win32 ni equivalencia con el original.
No se ejecuto el candidato ni se hicieron reparaciones/escaneos o instalaciones.

Host S02B permanece sin cambios. Sus bloqueos y los nuevos riesgos Runtime quedan
para 03B/02C y aceptacion Windows. SOURCE_STATUS.md sigue vigente; REL-01 abierto.
No se ha creado release/tag/PR. Los commits de desarrollo no activan workflows.
