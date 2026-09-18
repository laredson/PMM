# Retomar exactamente aqui

Rama unica: `v1.5.0.1-PMM-reliability`. Version objetivo: **1.5.0.1**.
Ultima tanda: **01, investigacion parcial y herramienta de preparacion**.
Estado del programa: sin cambios funcionales; VERSION sigue 1.5.0.0 y el manifiesto sigue 1.3.4.1.
**No estan resueltos todavia el desfase de fuentes ni la identidad efectiva del paquete.**

## Leer

AGENTS.md -> este archivo -> SESSION01_FINDINGS.md -> NATIVE_ARTIFACTS.json -> SESSION_PLAN.md.
BASELINE.json conserva el punto de bifurcacion historico; no reescribirlo como si se hubiera creado hoy.

## Proxima tanda: 01B - cerrar identidad, sin modificar ejecutables

Entrada necesaria: bytes completos de una copia de esta rama, o la salida real de la herramienta de preparacion junto con evidencia suficiente para contrastarla con la base. El acceso de lectura textual utilizado en la tanda 01 no proporciono los binarios ni un checkout completo.

Con una copia local completa, el comando de preparacion es:

```text
python Development/Reliability/session01_prepare.py --out ../PMM-session01
```

Requiere Python 3.9+ y Git disponibles, la rama reliability seleccionada y el paquete sin cambios pendientes. No requiere ejecutar PMM ni instalar Go. El directorio de salida no debe existir. El checkout no se modifica. El archivo `PMM-session01/session01-packet.zip` contiene evidencia y la propuesta de los cuatro metadatos; no es un paquete para Nexus ni una release.

1. Verificar el commit de entrada, los tres blobs nativos y sus hashes. Si hay discrepancia, parar y registrar su causa: no cambiar pins a los bytes encontrados por comodidad.
2. Revisar que la propuesta preserve dependencias, versiones de componentes, campos de protocolos y evidencia historica. Revisar consumidores de releaseDate antes de adoptar un valor nulo para una candidata no publicada.
3. Aplicar los cuatro metadatos juntos SOLO en reliability. Regenerar SHA256SUMS sobre los bytes finales de todo PMM, sin Workspace ni autorreferencia. No resolver el problema cambiando solo la etiqueta visible.
4. Comprobar estaticamente version/build concordantes, cobertura/hash de todos los archivos, metadatos de componentes y ausencia de cambios fuera del alcance. No ejecutar PMM ni CI remoto.
5. Actualizar STATUS.md, este archivo y el registro de la tanda. Subir un commit silencioso con la autorizacion de la intervencion. No publicar release/tag/PR.

Salida verificable: identidad 1.5.0.1 coherente y SHA256SUMS completo. Nativos y traducciones byte-identicos a la entrada. El desfase de fuentes sigue separado y no impide corregir esta identidad cuando se tienen los bytes.

## Despues: 02 - recuperar/reconciliar SOLO Host

El commit de importacion es `683a46df474c5f576e0bf5543d070da0dab7478a`, con padre `bc04d18d677e8f6bf754518e342184761d6527a3`. El Host anterior es otro source/blob y no se acepta como equivalente automaticamente.

Buscar la fuente del splash identificada por el SHA-256 de referencia `91e7531d9018ba1cbf7a3cbe20ed4736df3210c1ebad467cc80536959404ded9` en backups/entregas/ramas disponibles. Con los bytes del binario, leer informacion de compilacion y contrastar contratos. Documentar si se recupera un original o si se reconstruye una implementacion; no equiparar ambas cosas. No sustituir PMM.exe sin paridad y aceptacion Windows.

## Prompt para continuar

"Continua en v1.5.0.1-PMM-reliability. Lee AGENTS.md y Development/Reliability/NEXT_SESSION.md. Completa solo la tanda 01B con los archivos reales disponibles: identidad 1.5.0.1 e inventario completo, sin tocar traducciones ni binarios. No afirmes recuperar fuentes: eso corresponde a las tandas siguientes. Documenta evidencia, pendientes y el siguiente paso; commit silencioso, sin Actions, PR, tags ni release. Si siguen faltando bytes, registra el bloqueo y no cambies pins ni declares completada la tanda."
