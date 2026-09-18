# PMM v1.5.0.1 - linea independiente de fiabilidad

Rama: `v1.5.0.1-PMM-reliability`. Idiomas: `v1.5.0.0-PMM-translated`, independiente.
Ancestro comun: `38bd5a934488ac11a6200d3142b889ca86a82f57`.

**01B cerrada para identidad; 02A cerrada para fuente candidata del Host.**
El paquete conserva 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b y sus 629 archivos,
sin cambios en 02A. Esto no es una release ni hardening antivirus terminado.

La candidata se encuentra en
[NativeCandidates/Host](Development/Reliability/NativeCandidates/Host/README.md):
fuentes completos, build offline, diferencias, hashes y logs conservados.
Esta compilada y es repetible en el entorno registrado, pero NO esta instalada,
NO es la fuente original recuperada y NO tiene equivalencia Windows certificada.
No copiar su EXE sobre PMM.exe. Runtime, FixLab e idiomas permanecen intactos.

## Continuar

[Development/Reliability/NEXT_SESSION.md](Development/Reliability/NEXT_SESSION.md)
define 02B: solo comparacion del Host y lista de aceptacion Windows.
[STATUS.md](Development/Reliability/STATUS.md),
[SESSION02A_FINDINGS.md](Development/Reliability/SESSION02A_FINDINGS.md) y
[SESSION02A_CHECKS.json](Development/Reliability/SESSION02A_CHECKS.json)
registran lo hecho y lo pendiente. No repetir 01B ni afirmar paridad anterior
sin codigo e informes reproducibles.

## Verificacion del paquete, solo lectura

```text
python Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b
```

Con --package PMM inspecciona todos los archivos de una distribucion limpia.
Sin esa opcion usa archivos versionados del checkout. No ejecuta PMM ni repara.

La advertencia Development/Source/SOURCE_STATUS.md sigue activa. Las pruebas de
herramientas y hashes no sustituyen Windows ni un escaneo antivirus. No hay
sincronizacion automatica con idiomas, CI de desarrollo ni publicacion automatica.
