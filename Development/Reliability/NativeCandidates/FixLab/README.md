# FixLab - componentes candidatos, no motor instalado

CoreR1 conserva plan, captura, pertenencia PAK y ejecucion acotada en memoria.
04A-6B agrega guardado aislado y lectura posterior del resultado, no deploy.
UAsset, PAKV11 y PMMDLT1 no cambian en esta entrega.

El programa PMM/ sigue con sus EXE originales. Las fuentes de ESTA carpeta son
las candidatas en desarrollo. Leer ../../RUNNING_VERSION.md para no confundir
la version visible 1.5.0.1 con los reemplazos ya instalados.

CoreR1/PUBLICATION_CONTRACT.md explica errores antes/despues del commit y los
limites. El kit de pruebas Windows usa solo datos artificiales en TEMP. No poner
CoreR1-tests.exe en lugar de PMMFixLab.exe. Windows/Unreal/Palworld no aceptados.

No se recupero la fuente original ni el overlay roto. Core real, schemas/serializers
no escalares, relocalizacion variable y V2/CLI siguen pendientes.
Continuacion: ../../NEXT_SESSION.md, 04A-6C, aceptacion Windows del guardado.
