# Retomar despues de 03A

Rama: v1.5.0.1-PMM-reliability. 01B/02A/02B/03A cerradas EN SUS ALCANCES.
Paquete intacto: 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b, 629 archivos.
Leer AGENTS.md -> este archivo -> STATUS.md -> SESSION03A_FINDINGS.md ->
NativeCandidates/Runtime/README.md y UI_PROCESS_CONTRACT.md.
No repetir las tandas cerradas ni pedir otra vez el ZIP.

## Siguiente tanda 03B - SOLO comparar Runtime y fijar gate

Entradas guardadas:
- Original PMM/Engine/PMMRuntime.exe:
  e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a.
- Candidata S03A:
  10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f.
- Fuentes completos/receta en Development/Reliability/NativeCandidates/Runtime/.
- Go1.23.2 offline; dos builds iguales y 13+9 tests de modelos/fixtures/herramientas.
- Original y candidata NO son identicos. Cuatro secciones iguales y 80/81 nombres
  de funciones no prueban equivalencia. No se ha ejecutado Windows.

1. Verificar HEAD y hashes; regenerar candidata solo en salida nueva y externa.
2. Comparar de forma reproducible CLI, root, start, seleccion PS/CLM, dependencias,
   error/exit codes, UI normal/nativa, herencia de sesion y cierre. Separar fuente
   del snapshot, evidencia del binario original y resultados ejecutados.
3. Revisar R03A-01..06 y su relacion con H02B-04/05/06. No editar Host ni WPF en
   paralelo. No convertir el JSON de PID o state.txt en autenticacion ficticia.
   Concretar el acuerdo de instancia UI para 02C y el tratamiento de carreras,
   multiples ventanas, ready antes del registro, salida y reutilizacion de PID.
4. Corregir solo defectos imprescindibles de la candidata si quedan demostrados;
   registrar delta y nuevos hashes. No redisenar reparacion de red ni ejecutar
   dependencies ensure/start del EXE distribuido como supuesta prueba inocua.
5. Preparar WINDOWS_RUNTIME_ACCEPTANCE.md con casos concretos y estado NOT_RUN.
   Pruebas Windows pertenecen a 05 o a una intervencion expresamente autorizada.
6. Verificar PMM/, Host S02B, snapshot, FixLab e idiomas intactos. Registrar cierre,
   limites y entrada precisa de 02C. Un commit [skip ci], sin Actions, PR, tag o release.

## Comandos desde la raiz

```text
python -B Development/Reliability/NativeCandidates/Runtime/build.py --out ../PMM-Runtime-S03B
python -B Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b
```

La primera salida debe ser nueva. Para verificar un paquete sin Git, usar
--package PMM en el segundo comando. No copiar la candidata sobre el original.

## Pendientes posteriores

02C: Host/UI (HWND, sondeo PS, drenaje). 04: FixLab. 05: aceptacion real Windows.
Host S02B conservado: a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97.
La fuente original no se declara recuperada por compilar una reconstruccion.

## Prompt de continuacion

"Completa solo 03B en v1.5.0.1-PMM-reliability. Lee AGENTS.md y NEXT_SESSION.md.
Compara Runtime S03A con el original y guarda evidencia/gate Windows. No sustituyas
binarios, no modifiques Host/WPF/idiomas ni redisenes dependencias. Registra pruebas
reales, limites y entrada de 02C. Un commit [skip ci], sin Actions, PR, tags ni release."
