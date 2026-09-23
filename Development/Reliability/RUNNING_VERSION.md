# Que version estas ejecutando - inicio de v1.5.0.2

| Ubicacion | Programa real |
| --- | --- |
| `v1.5.0.2` justo tras el bootstrap | Aplicacion I04 heredada, todavia identificada como 1.5.0.1 |
| `PMM/` | I04 con Nexus Updates, Workspace privado y 23 idiomas habilitados |
| `NativeCandidates/FixLab/` | Research/candidatas, NO sustituyen por si solas PMMFixLab distribuido |
| CoreR1/UAsset test executables | Herramientas de prueba, NO PMM |

BUILD_ID heredado:
`PMM-v1.5.0.1-reliability-i04-nexus-updates`.

Esto es deliberado: el bootstrap de rama no cambia `PMM/`. La primera integracion funcional 1.5.0.2 debe actualizar VERSION, BUILD_ID, RELEASE_MANIFEST y SHA256SUMS juntos.

La rama 1.5.0.2 conserva los 23 idiomas habilitados, I04 Nexus Updates y los binarios nativos del baseline. Abrirla antes de una integracion funcional equivale a ejecutar el mismo paquete I04 que sirvio de origen, no una build nueva solo por el nombre de la rama.
