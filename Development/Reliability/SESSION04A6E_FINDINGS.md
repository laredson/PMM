# SESSION04A6E - arrays escalares V2 acotados

Entrada: `4763e6834c9a797b3fece6b6b0517b65f2881b2a`, rama
`v1.5.0.1-PMM-reliability`. El propietario informo que I02 parece funcionar bien
y autorizo continuar. Alcance: UAsset/CoreR1 aislados, fixtures artificiales,
builds externos y handoff. No se modifico ni ejecuto `PMM/`, Palworld, FixLab
original, release, PR o Actions.

## Resultado

Se agrego `PMM_FIXED_UNVERSIONED_SCHEMA_V2` con un permiso deliberadamente
estrecho: `ArrayProperty` cuyo `innerType` sea un escalar de ancho fijo ya
conocido. El lector usa el contador int32 y recorre el payload para localizar la
propiedad escalar objetivo. El array nunca se edita, redimensiona ni relocaliza.

V1 permanece escalar. V2 rechaza arrays anidados, structs, maps, sets, strings y
serializers custom. El contador debe estar entre 0 y 1.048.576 y todo el payload
debe caber dentro del export. Tambien se validan los elementos Bool, FName y
FPackageIndex; la cancelacion se consulta durante recorridos largos. Un caller
interno no puede eludir la lista de tipos soportados.

CaptureCore acepta la forma V2 solo bajo las mismas restricciones y conserva
`LayoutSemanticsVerified=false`. ExecuteBounded y el job V2 fueron ejercitados de
extremo a extremo con un array IntProperty anterior a PostProcessAnimBlueprint.
El cuarto escenario genera 10 outputs y un PAK byte-exact, pero sigue siendo
sintetico y candidato-only.

## Referencia primaria y defecto de portabilidad

Se fijo UAssetAPI commit `3228c1e86261aa08131f7ec0ff1a395f5d0b2a84` como
referencia de formato. `ArrayPropertyData.cs` confirma int32 NumEntries seguido
por elementos y `Usmap.cs` aporta el tipo interno del array. No se compilo ni
copio UAssetAPI y no se afirmo que una `.usmap` real haya sido autenticada.

La ejecucion real en Windows descubrio lecturas/escrituras Python dependientes de
cp1252 en fixtures Unicode. Los scripts afectados ahora usan UTF-8 explicito. La
correccion es de portabilidad del harness y no cambia bytes de produccion.

## Evidencia

- UAsset: 63 tests Go top-level PASS, 120 eventos PASS incluyendo paquete,
  0 SKIP/FAIL; 32 Python PASS; tres verificadores independientes PASS.
- CoreR1: 154 tests Go top-level PASS, 322 eventos PASS incluyendo paquete,
  2 SKIP/0 FAIL; 54 Python PASS, 2 SKIP por privilegio symlink; seis
  verificadores independientes PASS.
- Ocho targets fuzz con corpus semilla PASS; no fuzz aleatorio.
- Harnesses Windows completos ejecutados con `-test.count=3`: PASS.
- Dos builds Windows byte-identicos por modulo:
  - UAsset harness: `4acd771d44c639cd9bf7639ae0ac89a2807e8215fa823fa8c048eb05dbdcc6fa`,
    5.898.240 bytes;
  - CoreR1 harness: `225693032eef2c7275e2ad2ce43c5986004d5af2cd4f3368c4c5742e8dccd3dd`,
    6.879.232 bytes;
  - CoreR1 CLI: `02d4716ab7da5f37ff70406eda22f2eccb70303bf5fdcd78140e068920243d31`,
    4.360.704 bytes.
- Vet Windows/Linux y cross-build linux/amd64: PASS; Linux NO ejecutado.
- CLI final sobre job array SHA-256
  `2d7e996f15ff02c70b32f4a94fab234538a6803f68134fad1ec9535316752774`:
  exit 0, candidato `PMM-candidate-eef09e699ee7f43504c197a293efd3b8`,
  10 outputs comparados independientemente, installed/gameAccepted false.
  Pin falso: exit 3/PIN sin candidato nuevo. Uso incompleto: exit 2.

Fixtures/builds externos: `C:/GPT-Local/Releases/PMM/s04a6e-*`. Evidencia durable:
`NativeCandidates/FixLab/UAsset/evidence/s04a6e/` y
`NativeCandidates/FixLab/CoreR1/evidence/s04a6e/`.

## Limites y siguiente frontera

No hubo race detector, fuzz aleatorio, Windows 11, SMB/ReFS, disco lleno real,
AV instrumentado, corte electrico, assets reales ni aceptacion Unreal/Palworld.
El soporte V2 no parsea `.usmap`, no autentica la procedencia del schema y no
cubre serializers variables o containers complejos. El siguiente bloque debe
consumir un schema real pinneado o agregar otro serializer acotado con evidencia
primaria, sin reducirlo artificialmente a la forma admitida. No sustituir
`PMMFixLab.exe` ni conectar instalacion/deploy.

I02 permanece `PMM-v1.5.0.1-reliability-i02`, tree
`9ef22d5815943ce50413dfa7e09b474b06a22860`, 629 archivos / 628 checksums /
0 mismatches. El propietario informa que parece funcionar bien; faltan cierre,
segundo arranque, UI detallada y tiempos si aun no los reporta.
