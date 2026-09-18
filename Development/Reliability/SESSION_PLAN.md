# Tandas acotadas para Chat Pro

No reservar duraciones ni prometer trabajo en segundo plano. Cada intervencion ejecuta una sola entrega verificable y se detiene antes del siguiente bloque. El usuario autoriza las escrituras de cada intervencion; no hay permiso remoto permanente.

## Regla de cierre

Leer HEAD y NEXT_SESSION al entrar. Fijar entrada/alcance. Trabajar sin Actions. Al cerrar, registrar archivos modificados, verificaciones reales, lo no ejecutado, resultado y proxima accion. Un bloqueo se registra como BLOCKED/PARTIAL, nunca como DONE. Un commit coherente con `[skip ci]`; comprobar diff y ausencia de workflows sin ejecutar tests remotos. No introducir una reestructuracion masiva en una tanda de diagnostico.

| Tanda | Alcance unico | Entrada | Salida / criterio de cierre |
| --- | --- | --- | --- |
| 01 | Procedencia e identidad inicial | Rama de fiabilidad | PARCIAL: historial documentado y preparador offline con 12 tests sinteticos; no cierre de fuentes/identidad |
| 01B | Identidad y checksums | ZIP real y arbol Git verificados | CERRADA: cuatro metadatos coherentes, 628 hashes/629 archivos, otros 625 intactos |
| 02A | Fuente candidata de Host | Original y contrato; no repetir busquedas sin pistas | CERRADA: candidato RECONSTRUCTION, dos builds identicos, tests de modelo/herramientas y evidencia guardados; original intacto |
| 02B | Comparacion del Host | Candidato conservado de 02A | Comparacion reproducible y limites; sin sustitucion por coincidencia parcial ni sin aceptacion Windows |
| 03 | Fuente de Runtime | Binario y contratos de dependencias/UI | Fuente reconciliada, mapa de diferencias y candidato separado; pruebas de arranque Windows pendientes si no ejecutadas |
| 04 | Fuente de FixLab | Binario 0.2.0 y referencia de source | Procedencia y fuente verificables; recetas/datos intactos; no ejecutar reparaciones en el juego |
| 05 | Paridad Windows y gate de sustitucion | Candidatos y pruebas locales del usuario | Evidencia de start/cierre/splash/UI/errores/cancelacion; solo los componentes aceptados pueden sustituirse |
| 06 | Comprobar dependencias sin reparar silenciosamente | Fuentes reconciliadas | Separacion check/repair, diagnostico claro y ausencia de descarga/reinstalacion silenciosa al faltar un archivo |
| 07 | Reparacion explicita y reversible | Contrato de dependencias | Staging, pins, verificacion antes de ejecutar, rollback y respeto a bloqueo/cuarentena; sin debilitar antivirus |
| 08 | Invocaciones y politicas de procesos | Mapa de llamadas real | Argumentos estructurados, rutas/operaciones delimitadas, logs/cancelacion; retirar Bypass solo con alternativa soportada y validada |
| 09 | Recursos y procedencia del build | Toolchain/fuentes completos | Recursos Windows estandar y construccion repetible; fuentes -> artefactos documentados; sin firma fingida |
| 10 | Firma | Identidad/certificado provisionados expresamente | Firma/timestamp y verificaciones reales o estado BLOCKED por falta de certificado; no comprar ni instalar raices por iniciativa propia |
| 11 | Integracion de idiomas | Commit de idiomas aceptado | Fusion semantica hacia reliability, nativeName/RTL/PS5.1 preservados, metadata/checksums regenerados; no modificar la rama donante |
| 12 | Candidata y distribucion | Paridad, idiomas y artefactos listos | Preflight/escaneos autorizados/evidencias. No es emulacion exacta de Nexus ni garantia de cero detecciones; publicacion requiere autorizacion aparte |

Cada fila admite subdivisiones A/B si aparece una dependencia real. Mantener 1.5.0.1 como objetivo y distinguir tandas con BUILD_ID; no cambiar la version de .NET, PMMCore o FixLab al cambiar la version del producto.

Las validaciones auxiliares de scripts de mantenimiento usan fixtures y se etiquetan como tales. No sustituyen pruebas del programa, aprobacion humana ni resultados antivirus. No exigir un falso resultado global PASS para poder guardar un checkpoint honesto.

## Actualizacion al cerrar 02B

02B completada: comparacion estatica reproducible, correcciones acotadas y gate
Windows explicito. REL-01 sigue abierto. Dividir 03 en 03A (fuente/build Runtime)
y 03B (comparacion Runtime). Despues, 02C resuelve H02B-04/05/06 del Host con el
contrato UI ya conocido: origen HWND, sondeo acotado y drenaje/logs. 04 FixLab y
05 Windows permanecen separados. No promocionar candidatos con bloqueos abiertos.

## Actualizacion al cerrar 03A

03A completada: 20 .go de candidata Runtime, go.mod, receta offline y evidencia,
contrato UI y riesgos R03A-01..06. Dos builds finales identicos, 13 tests Go y 9
Python. PMM/ y Host no cambian; paridad Windows no verificada. Siguiente 03B:
comparacion detallada/gate Runtime, despues 02C para el acuerdo Host/UI. No
confundir candidata compilable con componente autorizado para reemplazo.
