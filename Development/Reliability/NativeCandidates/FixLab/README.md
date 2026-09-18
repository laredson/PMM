# FixLab - reconstruccion por componentes

Fuente original no recuperada. El motor completo todavia no esta construido ni
instalado. Las herramientas de 04A documentan la fuente ausente y overlay invalido.
No reintentar ese bootstrap ni presentar sus datos parciales como fuente valida.

## Componentes conservados

- PMMDLT1/ (04A-2): lectura/aplicacion en memoria con hashes/limites y fixtures.
- PAKV11/ (04A-3): Build/Read/Verify, perfil sin cifrar/comprimir y lectura independiente.
- UAsset/ (04A-4): lectura de perfil cooked 522/1008, nombres/mapas/dependencias;
  header-only y export ranges diferenciados, secciones desconocidas opacas.

Son codigo funcional de bibliotecas, no un main que simula PMMFixLab completo.
Cada carpeta conserva contrato, pruebas, receta offline y evidencia de su alcance.
Los harnesses TEST no son actualizaciones de PMMFixLab.exe.

Auditor/lector de 04A siguen disponibles: audit_source.py e inspect_binary.py.
SOURCE_CONTRACT.md es evidencia historica del contrato esperado, no source recuperado.
Original conservado: 8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.

Siguiente 04A-4B: serializacion/relocalizacion con proteccion de regiones opacas.
Despues core R1/V2/CLI y solo entonces comparacion 04B/gates reales. No modificar
recetas o pins para aceptar resultados; no afirmar compatibilidad Unreal sin pruebas.
