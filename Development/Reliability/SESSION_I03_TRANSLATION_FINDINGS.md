# SESSION_I03_TRANSLATION - findings

## Resultado

La localizacion terminada en
`v1.5.0.0-PMM-translated@681f7994474ebfd6c2538775767d2002014170f7`
se integro semanticamente sobre
`v1.5.0.1-PMM-reliability@fcd4b5ef8401ada4b6b8c2d79b9477738e15a3ee`.
No se hizo merge global, copia de PMM completa ni importacion de binarios antiguos.

I03 contiene 30 idiomas registrados, 23 habilitados y siete reservas. English
continua como default/fallback y la seleccion se aplica despues de guardar y
reiniciar. Se corrigio la ruta de `Refresh-UI` que reducia el selector a en/es y
se adapto la prueba smoke que todavia invocaba el antiguo hook de cambio en vivo.

## Decision española

`es.json` contiene las 1.292 claves canonicas y 58 claves dinamicas adicionales.
Se conservaron con autorizacion del propietario porque siguen siendo compatibilidad
util. Su conjunto se fija por hash en el validador I03. No se inventaron
traducciones para los otros idiomas ni se altero el texto del donante.

La unica clave canonica añadida por adaptacion a 1.5.0.1 es el aviso que nombra
`PMM Workspace folder`. Sus valores reutilizan la traduccion aprobada de la clave
donante equivalente; el auditor ya no reporta cadenas runtime faltantes.

## Limites

Las pruebas automaticas cubren estructura, placeholders, registro, nativeName,
fallback, cableado estatico, PowerShell 5.1 y carga WPF. No prueban por si solas
calidad linguistica, apariencia de cada pantalla, BiDi de todas las frases mixtas,
persistencia real entre dos procesos PMM ni workflows de Palworld.

El siguiente paso de usuario es hacer Pull, comprobar BUILD_ID I03, elegir varios
idiomas (incluido ar), aplicar, cerrar y abrir PMM. Ante regresion se corrige antes
de continuar con otra integracion grande.
