# I04 - actualizaciones Nexus seguras

I04 integra en `v1.5.0.1-PMM-reliability` un flujo visible y recuperable de actualizaciones de mods sin sustituir la arquitectura de I03 ni reconstruir binarios.

## Alcance

- `Mods & Merge` contiene siete subpestañas ordenadas: Library & Import, Updates, Fix Lab, Analyze & Resolve, Deep Analysis, Build & Deploy y AI Assistant.
- ColorFlow y AUTO incorporan Check Updates antes de Fix Lab/Analyze, con omisión explícita para trabajo offline.
- Credencial de desarrollo Nexus cifrada con DPAPI en `Workspace/State`; SSO permanece deshabilitado hasta registrar PMM.
- Cuenta Premium: descarga directa. Cuenta Free: confirmación por archivo en Nexus y continuación por `nxm://` validado.
- Identidad V2, plan ligado al fingerprint, cadena exacta de sucesores FileId, caché/backoff/cuotas y estados 401/403/429.
- Descarga parcial cancelable, HTTPS y redirecciones controladas, límite de 8 GiB, reserva de espacio y validación de hash.
- ZIP/7z/RAR/PAK con traversal, ADS, enlaces, colisiones, ejecutables, archivos anidados y límites de expansión bloqueados.
- La primera automatización acepta exactamente un PAK y ejecuta Deep Analysis sobre la biblioteca propuesta.
- Sustitución de biblioteca, procedencia y despliegue gestionado con rollback; `~mods` reutiliza la transacción de despliegue existente.
- Histórico indefinido en `Workspace/ModUpdates/Archive`, restauración y borrado manual explícito.
- Los lotes avanzan el fingerprint únicamente tras verificar la sustitución propia de PMM; los candidatos restantes se reanalizan sobre la nueva biblioteca.
- Con Palworld abierto, PMM descarga y analiza, conserva el candidato local y lo reanuda automáticamente al cerrarse el juego.
- Deep Analysis consume `PMM_UPDATE_PLAN_V1` y no repite consultas de red.

## Validación local

- PowerShell 5.1: regresiones Nexus/NXM y transacción de actualización PASS.
- Inyección posterior al despliegue: biblioteca, `~mods` y estado restaurados; recuperación simulada tras reinicio PASS.
- Módulos, workers, persistencia, análisis y compatibilidad semántica PASS.
- WPF inglés/español: 27 aserciones por idioma PASS.
- Localización: 30 idiomas registrados, 23 habilitados, 1.292 claves, cero faltantes y placeholders compatibles; 23/23 cargan en PowerShell 5.1.
- Binarios Host, Runtime y FixLab permanecen byte-idénticos a I03.

No se usó una cuenta Nexus real, no se ejecutó Palworld, no se probó SSO y no se publicó CI, tag ni release. Premium/Free y fallos HTTP se cubren con fixtures o controles locales; la aceptación real sigue pendiente de una credencial del usuario.

La regresión heredada `rc28_validation_runtime_regression.ps1` sigue buscando dos funciones en el antiguo archivo Bootstrap aunque ya estaban modularizadas antes de I04; falla también contra la base I03 y no representa una regresión de Updates.