# Estado v1.5.0.1 - cierre 02C-1

02C-1 CERRADA para supervision candidata, tests con stubs y builds reproducibles.
Entrada 54a2a8224822431e24fb740d6b6bc1d2fa42a177. Fecha 2026-09-18.
SIGUIENTE: 02C-2 (instancia UI/canal), no repetir 03B. REL-01 sigue ABIERTO.

| Area | Estado real | Pendiente |
| --- | --- | --- |
| Identidad 01B | Conservada; 629 archivos / 628 hashes; 1.5.0.1 / s01b | Mantener |
| PS/sondeos | Ruta del sistema, PS5.1 Desktop, limites y errores en ambas candidatas | Windows real y coste de sondeos repetidos |
| Salida/supervision | Pipes propios, limites, logs, fallo explicito; stubs y race Linux | Familias/Job Object, I/O bloqueado y aceptacion Windows |
| CLI/helper | Timeout validado antes de multiplicar, reg.exe con plazo | Compatibilidad CLI y Windows |
| UI/HWND | Especificacion previa conservada, canal NO implementado | 02C-2 |
| Manifiesto/rutas/repair | R03B-02/04 y 06/07 ABIERTOS | Antes de promocion |
| FixLab | Fuentes/paridad pendientes | 04 |
| Traducciones | Intactas, sin fusion | Integracion posterior autorizada |

Host C1 96e6e6b024207257e7777d7ad72711bf8f8c0966c86929d6f5528ec177ddb059.
Runtime C1 db39fb942ebf9ba2c8d78c71abf4df43ec918a4040fe09dfaad65cba9a97ac77.
Dos builds de cada uno identicos en Linux/amd64 Go1.23.2. No equivalencia original.
48 funciones de tests Go (excluidos dos dispatchers de fixtures), 29 Python;
Supervision tambien con race detector Linux. No Windows/PMM/PS/.NET/WPF/AV ejecutados.
Solo helpers de build/lectura y procesos de prueba locales propios.

Cambios visibles de candidata: eco de hijos del Host va a logs, no a consola;
limites dan error en vez de truncado silencioso; FLAGS CLI invalidos se rechazan.
No son cambios instalados. Los 629 archivos PMM, snapshot, idiomas y workflows no
cambian. No firma, release, tag, PR, instalacion ni CI remoto solicitado.
SESSION02C1_CHECKS/FINDINGS, Supervision/README y SupervisionEvidence/s02c1 conservan
comandos, codigo, limites y evidencia. Los registros anteriores son historicos.
