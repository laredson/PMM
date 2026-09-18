# Retomar exactamente aqui

Rama unica: `v1.5.0.1-PMM-reliability`.
**01B terminada: no repetir identidad/inventario ni pedir de nuevo el ZIP.**
Version: 1.5.0.1. Build: PMM-v1.5.0.1-reliability-s01b.
Leer AGENTS.md -> este archivo -> STATUS.md -> SESSION01B_FINDINGS.md ->
NATIVE_ARTIFACTS.json -> Development/Source/SOURCE_STATUS.md.

## Siguiente tanda 02A: SOLO fuente candidata del Host

Objetivo: recuperar o reconstruir una fuente candidata verificable de PMM.exe.
No modificar Runtime, FixLab, UI, idiomas ni dependencias en esta tanda.
No sustituir PMM.exe ni cambiar sus pins para aceptar un candidato no probado.

Entrada comprobada:

- Host original PMM/PMM.exe: SHA-256
  010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d.
- Go 1.23.2, windows/amd64, CGO_ENABLED=0, trimpath=true; hashes PE en NATIVE_ARTIFACTS.json.
- Snapshot Development/Source/Host/; la advertencia de desfase sigue vigente.
- Importacion Guided Flow: 683a46df474c5f576e0bf5543d070da0dab7478a;
  padre bc04d18d677e8f6bf754518e342184761d6527a3.
- Contrato splash/handoff HWND: RELEASE_MANIFEST.host y documentacion RC21.
- Referencia historica de fuente splash, todavia no ligada a un archivo recuperado:
  91e7531d9018ba1cbf7a3cbe20ed4736df3210c1ebad467cc80536959404ded9.

La busqueda anterior ya consulto 1.3.0-fix-lab, 1.3.0-stable, 1.3.0final,
1.2.1-stable, 1.4.0-ReUI y 1.3.1-mod-creation: el main.go era el mismo snapshot.
archive-main-before-1.2.1 y release/1.2 tenian el Host anterior. No repetir estas
consultas sin una pista nueva. No se afirma haber agotado todos los backups.

La charla menciono candidatos casi equivalentes, pero solo persistieron README,
no sus .go/binarios/informes. No dar por recuperadas esas fuentes ni por probada
su paridad. Conservar en esta tanda los resultados antes de prometer continuidad.

## Trabajo y cierre

1. Leer snapshot/contrato y buscar una fuente exacta solo con pistas nuevas.
2. Si no aparece, reconstruir cambios acotados desde contratos y evidencia
   estatica. Etiquetar RECONSTRUCTION, no ORIGINAL_RECOVERED.
3. Guardar los .go, diff, receta de build y hashes bajo
   Development/Reliability/NativeCandidates/Host/. Explicar diferencias y limites.
4. Compilar candidatos fuera del paquete. No ejecutar PMM ni hacer pruebas
   funcionales Windows sin el alcance/autorizacion correspondientes.
5. Cerrar con fuente candidata/evidencia guardadas o con bloqueo concreto.
   Actualizar STATUS, este archivo y el registro antes del commit [skip ci].
   No declarar equivalencia solo porque una seccion .text coincida.

La siguiente tanda 02B tratara SOLO comparacion reproducible/paridad del Host.
Runtime queda para 03. Ningun resultado depende exclusivamente de directorios
temporales o de la memoria de una conversacion. Binarios originales intactos
hasta la aceptacion Windows pertinente. Sin Actions, PR, tags ni release.

## Comprobacion disponible

`python Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b`
comprueba identidad y hashes versionados, sin ejecutar PMM ni hacer red.

## Prompt para continuar

"Completa solo 02A en v1.5.0.1-PMM-reliability. Lee AGENTS.md y NEXT_SESSION.md.
Recupera/reconstruye la fuente candidata del Host y guarda codigo, receta, hashes
y diferencias. No cambies binarios, Runtime, idiomas ni pins. Documenta limites
y la entrada exacta de 02B; un commit [skip ci], sin Actions, PR, tags ni release.
No certifiques comparaciones anteriores sin disponer de sus archivos."
