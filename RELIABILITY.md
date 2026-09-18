# PMM v1.5.0.1 - fiabilidad independiente

Rama: v1.5.0.1-PMM-reliability. Ultimo checkpoint: **04A parcial, fuente FixLab bloqueada**.
Host/Runtime/UIBridge C2B permanecen como candidatas, sin sustitucion del programa.

El paquete conserva 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b: 629 archivos y
628 hashes correctos. La prueba informal de arranque del usuario se refiere a
ese paquete original; no acepta las candidatas ni las reparaciones FixLab.

04A identifica el EXE FixLab y seis nombres de fuente mediante metadata Go.
La carpeta source declarada falta y el overlay historico tiene Base64 invalido;
agregar padding no repara el pin/XZ. No hay una fuente recuperada ni motor nuevo.
Se entregan auditor de procedencia y lector de metadata, con 15 tests Python y
5 Go de herramientas. Cinco recetas y 137 payloads unicos verificados por lectura.
No ejecutar ni aplicar el bootstrap antiguo como intento de recuperacion.

Continuar en [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md).
[STATUS](Development/Reliability/STATUS.md),
[hallazgos 04A](Development/Reliability/SESSION04A_FINDINGS.md) y
[checks 04A](Development/Reliability/SESSION04A_CHECKS.json) contienen el estado real.
[FixLab](Development/Reliability/NativeCandidates/FixLab/README.md) tiene herramientas
reproducibles y contrato de la recuperacion/reconstruccion pendiente.

REL-01 sigue abierto y los gates Windows siguen NOT_RUN. No promover binarios,
no alterar recetas ni pins para simular equivalencia. No hay release/tag/PR.
