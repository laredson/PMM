# Que version estas ejecutando - integracion I03

| Ubicacion | Programa real |
| --- | --- |
| PMM/ en la rama reliability tras I03 | Aplicacion REAL I03 con Host/Runtime C2B, Workspace privado y 23 idiomas habilitados |
| PMM/ del ZIP I01 historico | Aplicacion I01 sin routing I02 ni idiomas I03 |
| CoreR1-tests.exe / UAsset-tests.exe | Solo pruebas FixLab, NO PMM |
| CoreR1-candidate.exe | CLI candidato-only, NO PMMFixLab ni instalador |

I03 = `PMM-v1.5.0.1-reliability-i03` en `Resources/Metadata/BUILD_ID.txt`.
I02 es la base de Workspace; I01 es la base binaria conservada.

I03 no recompila ejecutables. Deben conservar:
- Host `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`;
- Runtime `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`;
- FixLab `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.

Abrir I03 prueba la integracion de idiomas y Workspace, pero no completa
aceptacion Windows, FixLab, optimizacion, firma o antivirus. Confirmar cambio de
idioma despues de Apply y reinicio, incluido arabe, antes de considerarlo aceptado.
