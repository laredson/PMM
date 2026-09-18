> Contrato de **PlanCore** (04A-5A), conservado. Desde 04A-5B existe una API
> separada CaptureCore con lecturas explicitas; ver CAPTURE_CONTRACT.md.

# Contrato de planificacion R1 y procedencia - 04A-5A

## Estados y responsabilidades

El caller mantiene inmutables todos los bytes durante PlanCore. Aporta un hash
esperado por documento desde una fuente de confianza. El planificador calcula
esos hashes y comprueba identidad JSON; NO autentica origen, firmas o archivos
referenciados. No hay I/O de archivos, procesos o red en la biblioteca Go.

Receta/inventario incoherente -> nil,error. Plan coherente -> PLAN_VALID con
requisitos bloqueantes. Esta entrega JAMAS emite TRANSFORM_READY. Ni siquiera
aportar un SchemaClaim habilita transformacion: aun faltan validar archivos,
layout real, pre/post-condiciones y relocalizacion del core. No se pretende que
un bool sea una barrera de seguridad frente a un consumidor comprometido.

El inventario es PMM_R1_INVENTORY_V1: schema, role (donor/current), providerSHA256,
build, files [{path, sha256, sizeBytes}]. Todos los campos son obligatorios.
ProviderSHA256 del donante declara la identidad del PAK entero; para current,
la identidad de un conjunto de proveedores fijado EXTERNAMENTE. El formato de
ese conjunto y la verificacion de sus bytes pertenecen a la siguiente capa.
No se implementa en secreto un hash de concatenacion ni se afirma haberlo leido.

La comprobacion de la lista de donantes admite cualquiera de sus alternativas,
no exige las dos a la vez. No prueba que la extraccion provenga del PAK declarado.
La comparacion de build es exacta y deliberadamente conservadora, no una regla
atribuida al ejecutable original. SizeBytes es metadata no negativa, no bytes leidos.

## Seleccion y outputs

CurrentNameHashSources requiere headers presentes en el inventario current; no
inventamos sus hashes de nombres ni requerimos .uexp solo para cosechar nombres.
Cada grupo exige donante .uasset/.uexp y destinos actuales .uasset/.uexp completos.
Minimos por grupo se comprueban sobre rutas unicas; targetRegex se ancla al inicio
y final reales incluso si su expresion interna contiene alternativas/flags.
Reglas diferentes que seleccionan la misma ruta son ambiguas y se rechazan.

Las operaciones propuestas son COPY_SUPPORT y RELOCATE_REQUIRED. Las rutas de
salida de familias derivan del stem del destino y las extensiones del donante.
NO significa que sus bytes o tamanos finales sean conocidos. PAK capacity/output
hashes/readback, transformaciones y guardado transaccional siguen pendientes.
Los hashes de los archivos fuente permanecen identificados como fuente, nunca
se copian a un campo de 'output validado'.

Soporte: prefix con '/', no prefijo textual ambiguo; cada raiz aporta algun dato.
includeFiles exige existencia y no puede contradecir excludeRegex. Los restantes
excluidos se registran. Soporte parcial .uasset/.uexp se rechaza; no se reintroduce
implicitamente un archivo excluido. ForbiddenOutputRegex se aplica a TODAS las
salidas, incluidas las copias y sidecars. No se normalizan rutas silenciosamente.

Rutas ASCII, longitud <=1024, profundidad <=32, segmentos <=255. Se rechazan '..',
'.', ADS, barras invertidas, caracteres reservados, dispositivos, finales punto/
espacio y colisiones de case en archivos Y directorios. Mount no es ruta de disco.
Esto es un perfil limitado de la candidata, no regla universal de Unreal.

## Expediente opcional del schema

SchemaClaims recibe documentos pinneados PMM_R1_SCHEMA_PROVENANCE_V1 con:
recipeSHA256, donorUasset, donorHeaderSHA256, donorExportSHA256,
currentProviderSHA256, profile, classPath, layoutSHA256, origin, revision,
reviewRecordSHA256, ademas de schema. Ningun campo approved/verified es aceptado.

Se comprueba vinculacion exacta a un donante usado en postProcess del plan actual,
perfil cooked-ue4-522-ue5-1008 y /Script/Engine.SkeletalMesh. Duplicados o una revision
ligada a otros hashes se rechazan. Resultado siempre DECLARED_UNVERIFIED.
Los hashes layout/review son REFERENCIAS, no evidencia cargada o revisada.
No se inventa schema a partir del offset 120, no se confunde nombre/clase con
posicion verificada y no se amplian las protecciones de UAsset/RewriteNames.

## Limites y JSON

Techos por llamada: receta 256 KiB; inventario 8 MiB cada uno; claim 16 KiB;
16384 archivos por inventario; 16384 outputs; 64 claims. Request.Limits solo reduce.
Receta: 32 grupos, 16 firmas, 64 referencias de nombres, 64 raices de soporte,
1024 ficheros explicitos, 32 regex por lista, 512 bytes por regex. JSON depth 16,
400000 valores por documento. Contexto se comprueba por hash-bloque, valor JSON,
familia y archivo. No son garantias de RSS ni tiempo absoluto de CPU.

JSON rechaza claves duplicadas, desconocidas, diferente capitalizacion, faltantes,
null, UTF-8 invalido y caracteres de reemplazo/control en valores string. Las
propiedades opcionales se omiten, no se envian como null. No se aplican defaults
ambiguos a version, minimos o hashes. Los patrones son Go regexp, no Python/PCRE.

Referencias primarias consultadas 2026-09-18 y contrastadas con Go1.23.2 local:
https://pkg.go.dev/encoding/json (duplicados, case y Unicode)
https://pkg.go.dev/regexp (sintaxis RE2 y busqueda)
Fuente de dominio: receta core R1 original SHA-256
3f08c8da1dbc799b0c47a8a00d88819280e14ad7e21dce9f0622c7974a0c4f9c
mas SOURCE_CONTRACT y contratos PMMDLT1/PAKV11/UAsset anteriores. No decompilacion
nueva ni source original recuperado. Las pruebas del contrato real usan inventarios
SIMULADOS y no prueban que existan o funcionen los assets del juego.
