# Que version estas ejecutando - integracion I04

| Ubicacion | Programa real |
| --- | --- |
| PMM/ en este worktree | Aplicacion I04 con Updates Nexus, Workspace privado y 23 idiomas |
| Rama remota antes del push I04 | Aplicacion I03 |
| CoreR1-tests.exe / UAsset-tests.exe | Solo pruebas FixLab, NO PMM |
| CoreR1-candidate.exe | CLI candidato-only, NO PMMFixLab ni instalador |

I04 = `PMM-v1.5.0.1-reliability-i04-nexus-updates` en `Resources/Metadata/BUILD_ID.txt`.

I04 no recompila ejecutables. Conserva Host `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`, Runtime `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f` y FixLab `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.

Abrir I04 prueba la interfaz y lógica local, pero no demuestra una descarga Nexus real, SSO, ejecución Palworld, firma o antivirus. La API key pertenece al usuario y solo debe guardarse cifrada dentro de Workspace.