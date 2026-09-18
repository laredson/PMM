# PMM v1.5.0.1 - fiabilidad independiente

Rama: v1.5.0.1-PMM-reliability. Ultima entrega: **02C-2A, biblioteca de canal UI**.
Siguiente: **02C-2B, integracion en Host/Runtime**. 02C-2 completa aun no cerrada.

El modulo local UIBridge implementa protocolo, registro/generation/ACK/cierre,
validacion de procesos/ventanas y transporte named pipe Windows. Sus 25 pruebas
Go del modelo/protocolo y race Linux pasan; el codigo Windows compila. **Todavia
no se ha conectado a PMM ni se ha ejecutado el transporte real en Windows.**

C1 ya consta en GitHub en 054e164; conservar esas candidatas, no las versiones
anteriores de ZIP. 01B mantiene 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b; los 629
archivos del paquete y sus ejecutables originales permanecen intactos.

Leer [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[STATUS](Development/Reliability/STATUS.md),
[hallazgos 2A](Development/Reliability/SESSION02C2A_FINDINGS.md),
[checks](Development/Reliability/SESSION02C2A_CHECKS.json) y
[UIBridge](Development/Reliability/NativeCandidates/UIBridge/README.md).
La guia INTEGRATION.md evita reconstruir el trabajo desde el resumen del chat.

El arranque correcto comunicado por el usuario corresponde al paquete actual,
no a las candidatas no instaladas. REL-01 y el gate Windows siguen abiertos.
No tocar traducciones/main ni publicar releases sin la autorizacion correspondiente.
