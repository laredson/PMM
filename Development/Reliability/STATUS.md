# Estado de v1.5.0.1 - cierre 03A

**03A CERRADA: candidata Runtime, receta, evidencia basica y contrato UI.**
Fecha: 2026-09-18. Entrada: f52101800b92b696b0600bb3382f89292a926cc8.
Retomar NEXT_SESSION.md: 03B, solo comparacion/gate Runtime.

| Area | Estado | Siguiente accion |
| --- | --- | --- |
| Identidad REL-02 / 01B | Conservada: 1.5.0.1 / s01b; 629 archivos y 628 hashes correctos | Mantener, no repetir |
| Host 02A/02B | Fuente candidata S02B conservada, sin cambios en 03A | 02C bloqueos H02B-04/05/06; 05 Windows |
| Runtime 03A | Fuente candidata RECONSTRUCTION compilada y guardada; no original recuperado | 03B contratos/gate; sin sustitucion |
| FixLab | Fuente/paridad pendientes | 04 |
| Hardening/distribucion | No terminado | 06..12 despues de base verificable |
| Traducciones | Intactas y sin fusion | Integracion autorizada posterior |

Runtime S03A: SHA-256 10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f.
Dos builds en rutas distintas son identicos en Linux/amd64 Go1.23.2. Pasaron 13
funciones de test Go (9 subcasos de ruta) y 9 tests Python de herramientas.
No se ejecutaron EXE Windows, WPF, PowerShell, PMM ni antivirus. La comparacion
PE/pclntab es estatica: original y candidata son diferentes, incluida .text.

Cambio funcional candidato limitado: WPF ya no recibe HideWindow/SW_HIDE;
conserva CREATE_NO_WINDOW. Modelo de ruta/argv/entorno/streams comprobado con
fixtures. Seleccion/sondeo PowerShell, dependencias, root y lifecycle se conservan
con riesgos documentados R03A-01..06; no estan resueltos por extraer el modelo.
El acuerdo de autenticacion del HWND con Host queda propuesto, no implementado.

Todos los archivos del paquete, Host candidato y snapshot historico permanecen
intactos. REL-01 NO cerrado; SOURCE_STATUS.md sigue vigente. No hay instalacion,
firma, PR, tag, release o CI remoto solicitado. Cada informe anterior permanece
historico; no atribuir a S03A resultados de otras candidatas.

SESSION03A_FINDINGS.md, SESSION03A_CHECKS.json y NativeCandidates/Runtime/evidence/
conservan el cierre. NativeCandidates/Runtime/UI_PROCESS_CONTRACT.md detalla el
contrato real de fuente, riesgos y requisitos para 03B/02C.
