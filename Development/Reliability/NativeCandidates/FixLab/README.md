# FixLab - componentes candidatos, no motor instalado

CoreR1 conserva plan, captura, pertenencia PAK y ejecucion acotada en memoria.
04A-6B agrega guardado aislado y lectura posterior del resultado, no deploy.
04A-6E amplia UAsset/CoreR1 solo para recorrer arrays de escalares de ancho fijo;
PAKV11 y PMMDLT1 no cambian en esta entrega.

El programa PMM/ conserva PMMFixLab.exe original; Host/Runtime C2B si estan
integrados. Las fuentes de ESTA carpeta son candidatas en desarrollo. Leer
../../RUNNING_VERSION.md para no confundir 1.5.0.1 con reemplazos instalados.

CoreR1/PUBLICATION_CONTRACT.md explica errores antes/despues del commit y los
limites. El kit de pruebas Windows usa solo datos artificiales en TEMP. No poner
CoreR1-tests.exe en lugar de PMMFixLab.exe. Windows/Unreal/Palworld no aceptados.

No se recupero la fuente original ni el overlay roto. 04A-6D agrega job V2/CLI
candidato-only y valida el commit Windows. 04A-6E admite ArrayProperty solo con
innerType escalar fijo, sin editarlo; no es el motor V2 completo. Siguen pendientes
una fuente de schema real, serializers variables/complejos y relocalizacion.
Continuacion: ../../NEXT_SESSION.md y SESSION04A6E_FINDINGS/CHECKS.
