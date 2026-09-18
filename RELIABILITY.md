# PMM v1.5.0.1 - cierre 03B

Rama: v1.5.0.1-PMM-reliability. Identidad distribuida: 1.5.0.1, build s01b.
03B cierra comparacion del Runtime, correccion minima y gate; NO equivalencia
Windows ni sustitucion de ejecutables. REL-01 sigue abierto.

Empezar por [NEXT_SESSION.md](Development/Reliability/NEXT_SESSION.md), despues
[STATUS.md](Development/Reliability/STATUS.md) y
[SESSION03B_FINDINGS.md](Development/Reliability/SESSION03B_FINDINGS.md).

Runtime candidato: Development/Reliability/NativeCandidates/Runtime/.
S03B = 45e017190c379774afd24557084e7fa532bbef58b6ead6869294943bb72ed0be.
Fuentes completos, build.py, compare_runtime.py, tests y evidence/s03b conservados.
Original y candidata difieren; repetir build no demuestra equivalencia del programa.

Corregido SOLO en candidata: no aceptar inventario leido a medias, rutas duplicadas
o recorrido con errores. No se redisenan descargas, permisos o UI en esta tanda.
Los 629 archivos distribuidos siguen intactos. No instalar el candidato.

18 tests Go y 15 Python pasaron; el inventario real de .NET fue leido/verificado,
NO ejecutado. Windows/WPF/PowerShell/PMM/AV y los 18 casos del gate no se ejecutaron.
[WINDOWS_RUNTIME_ACCEPTANCE.md](Development/Reliability/WINDOWS_RUNTIME_ACCEPTANCE.md)
y [HOST_RUNTIME_HANDSHAKE.md](Development/Reliability/NativeCandidates/Runtime/HOST_RUNTIME_HANDSHAKE.md)
separan pruebas pendientes y propuesta de IPC de lo realmente implementado.

Siguiente: 02C-1 (plazos/sondeos/supervision); despues 02C-2 (instancia UI/handoff).
No repetir 01B/02A/02B/03A/03B ni recuperar progreso de mensajes sin evidencia.
Rama de traducciones independiente; no hay merge, PR, tag o release automaticos.
