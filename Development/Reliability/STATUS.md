# Estado de v1.5.0.1 - cierre 02B

**02B CERRADA para comparacion y gate; REL-01 NO cerrado.** 2026-09-18.
Entrada: baa063933c8940a7654d3350f728a81ed967f92c.
Retomar NEXT_SESSION.md: 03A, candidato Runtime aislado.

| Area | Estado | Siguiente accion |
| --- | --- | --- |
| Identidad REL-02 / 01B | Conservada: 1.5.0.1 / s01b, 629 archivos y 628 hashes correctos | No repetir; mantener |
| Host 02A/02B | S02A reproducido; S02B con correcciones y comparacion persistidas | 02C: bloqueos origen HWND/sondeo/drenaje; 05: Windows |
| Runtime | Fuente/paridad pendiente | 03A fuente/build; 03B comparacion |
| FixLab | Fuente/paridad pendiente | 04 |
| Hardening/distribucion | No terminado | Tandas de dependencias/procesos/recursos/firma despues de base verificable |
| Traducciones | No modificadas ni fusionadas | Integracion autorizada posterior |

S02B: SHA-256 a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97.
Dos builds en salidas distintas fueron byte-identicos en el entorno registrado.
Nueve tests Go del modelo (16 subcasos HWND previos) y trece tests Python pasaron.
El original y candidato NO son identicos; .text difiere. La tabla Go pclntab
mapea funciones reales, no prueba semantica ni recupera fuente original.

Corregido solo en candidata: framing LF/CRLF, rechazo de registros parciales,
prioridad cierre/fallo sobre ready y chequeo de foco antes de ShowWindowAsync.
Siguen bloqueando promocion H02B-04/05/06 (origen del HWND, timeout/seleccion PS,
lectura de pipes/logs). Las carreras y apariencia reales esperan Windows.

Los 629 archivos PMM/, el snapshot Development/Source/, Runtime/FixLab, idiomas
y workflows permanecen identicos. No se ejecutaron PMM/candidata Windows/WPF,
no hay escaneo AV, instalacion, firma, release/tag/PR ni CI remoto solicitado.
Los tests son de herramientas/modelos, NO paridad del programa en Windows.

SESSION02B_FINDINGS.md, SESSION02B_CHECKS.json, WINDOWS_HOST_ACCEPTANCE.md y
NativeCandidates/Host/evidence/s02b/ guardan evidencia y limites. Los registros
02A/01B se conservan historicos; no se atribuyen sus resultados a la nueva candidata.
