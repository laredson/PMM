# PMM v1.5.0.1 - linea independiente de fiabilidad

Rama: `v1.5.0.1-PMM-reliability`. Idiomas: `v1.5.0.0-PMM-translated`, independiente.
Ancestro comun: `38bd5a934488ac11a6200d3142b889ca86a82f57`.

**01B cerrada para identidad e inventario estatico.** El paquete declara 1.5.0.1
coherentemente, con build PMM-v1.5.0.1-reliability-s01b. SHA256SUMS contiene
628 entradas para 629 archivos y solo excluye su propio archivo. Los otros
625 archivos, incluidos binarios e idiomas, se conservan byte por byte.
Esto no es una release publica ni una declaracion de hardening terminado.

## Continuar

[Development/Reliability/NEXT_SESSION.md](Development/Reliability/NEXT_SESSION.md)
es el punto de entrada: 02A, SOLO fuente candidata del Host. No repetir 01B.
[STATUS.md](Development/Reliability/STATUS.md),
[SESSION01B_FINDINGS.md](Development/Reliability/SESSION01B_FINDINGS.md) y
[SESSION01B_CHECKS.json](Development/Reliability/SESSION01B_CHECKS.json) documentan
esta entrega. [SESSION_PLAN.md](Development/Reliability/SESSION_PLAN.md) mantiene
las siguientes tandas. Los nativos del paquete no han sido sustituidos.

## Verificacion local de solo lectura

```text
python Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b
```

Comprueba archivos versionados por Git; `--package <carpeta-PMM>` comprueba TODOS
los archivos de una distribucion limpia. No ejecuta PMM, no repara y no hace red.
Los 20 tests locales de herramientas y los hashes no sustituyen pruebas Windows
ni escaneos antivirus.

REL-01 sigue pendiente: los candidatos descritos en la charla anterior no quedaron
conservados con codigo/informes. No se certifica su equivalencia. La advertencia
Development/Source/SOURCE_STATUS.md sigue activa. No integrar idiomas, publicar
ni cambiar protecciones por iniciativa propia.
