# Retomar despues de 02C-2B

Rama exclusiva v1.5.0.1-PMM-reliability. 02C-2B cerrada para integracion candidata;
Windows/IPC/GUI siguen NOT_RUN. Leer AGENTS -> este archivo -> STATUS ->
SESSION02C2B_FINDINGS/CHECKS. No repetir tandas ni pedir el ZIP de nuevo.

## Estado conservado

Paquete original intacto: 1.5.0.1, build PMM-v1.5.0.1-reliability-s01b,
629 archivos, 628 hashes, arbol PMM 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
Host C2B a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c.
Runtime C2B b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f.
Fuentes/recetas y dependencias LOCALES Supervision/UIBridge estan en NativeCandidates.
No copiar estos EXE sobre PMM.exe/Engine/PMMRuntime.exe. No se recupero fuente original.

02C-2A fue biblioteca; 02C-2B ya la conecta. No reimplementar el canal. Host captura
Runtime antes de Wait; Runtime conecta antes de tareas largas, acks serializados
+ heartbeat, una WPF por coordinador, directorios nuevos, READY posterior a ACK,
retirada terminal y handoff por Gate desde el hilo del splash. state.txt del Host
es solo progreso. Leer UIBridge/INTEGRATION.md antes de modificar esa cadena.

## Siguiente tanda 04A - SOLO procedencia/fuente FixLab

1. Verificar HEAD y leer NATIVE_ARTIFACTS, SOURCE_STATUS y documentos FixLab.
   No tocar Host/Runtime/UIBridge ni el paquete. Original PMM/Engine/PMMFixLab.exe:
   8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
2. Localizar fuente verificable de 0.2.0-variant-recipes. Revisar como DATOS el
   historial/entregas y el overlay .github/bootstrap/fixlab-r2-overlay.patch.xz.b64.part*
   si resulta pertinente; NO ejecutar workflows/bootstrap ni aplicar un overlay
   completo sobre la rama. Una referencia de manifiesto no demuestra existencia.
3. Si se recupera una fuente, registrar origen y hash exactos. Si se reconstruye,
   etiquetar RECONSTRUCTION. Guardar SOLO candidata aislada en NativeCandidates/FixLab;
   contratos/recetas/output hashes originales no se sustituyen para hacerla pasar.
4. Receta offline y evidencia si puede compilarse; no ejecutar reparaciones reales,
   herramientas del juego ni distribuir datos propietarios. Fixtures sinteticos
   y lectura de metadatos no se presentan como aceptacion en Palworld/Windows.
5. Registrar hallazgos y alcance terminado o bloqueo concreto, con entrada precisa
   de 04B (comparacion) o la recuperacion pendiente. Un commit [skip ci] autorizado,
   sin Actions/PR/tag/release. Conservar identidad y los archivos de PMM.

## Gates antes de cualquier promocion

WINDOWS_HOST_ACCEPTANCE, WINDOWS_RUNTIME_ACCEPTANCE y WINDOWS_UIBRIDGE_ACCEPTANCE
siguen NOT_RUN. El ultimo incluye casos integrados de C2B. No confundir abrir el
PMM original con probar los candidatos. Falta gestion de familia/Job Objects,
validacion manifiesto/pins/rutas R03B-02/04 y politica/reparacion 06/07. Activacion
propia de WPF y carreras de HWND mismo proceso necesitan observacion Windows.

## Prompt

"Completa solo 04A en reliability: lee NEXT_SESSION y recupera/reconcilia la fuente
candidata de FixLab con procedencia y receta conservadas. No sustituyas binarios ni
toques Host/Runtime/UIBridge, traducciones o recetas productivas. No ejecutes bootstrap,
reparaciones o juego. Registra evidencia, limites y 04B; commit [skip ci], sin Actions,
PR, tags ni release."
