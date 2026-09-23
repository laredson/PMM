# PMM v1.5.0.2 - Decision transcript: single-EXE, noflag and product scope

Date: 2026-09-23
Branch: `v1.5.0.2`
Purpose: historical/contextual record for maintainers and Codex.

> This file is **context, not the normative implementation specification**.
> The authoritative execution requirements are in
> `V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`, `STATUS.md` and `NEXT_SESSION.md`.
> If an exploratory statement in this transcript conflicts with the final plan,
> the final plan wins.

This transcript records the conversation that led from the inherited reliability/no-false-positive work to the adopted 1.5.0.2 architecture and scope. It intentionally excludes tool-call internals, private reasoning, system instructions and unrelated conversation.

---

## 1. Startup incident is recorded, but not the active target

### Owner

> tambien hay una cosa, la primera vez que abrí la 1.5.0.1 me dio un error, no recuerdo cual, aunque la segunda vez que lo abrí ya funciona bien, pero 2 dias despues un usuario chino me reportó el mismo error y parece que no logra que funcione. no puedo reproducir el error, ni borrando workspace o una nueva instalacion, asique no se, pero el error hace que el programa no inicie, sale despues de la barra de carga y antes del UI.
> quiza solo haciendo bien todos los pasos ya se soluciona, lo dejo reportado por historico.
> creo que lo mejor es crear la branch v1.5.0.2 y ponernos con la mejor anti escaner. asegurate de incluir todas las nuevas features como los idiomas etc
> vamos a dejarlo todo preparado, con el archivo de historial, el paso que vamos y etc todo en esta nueva branch, a partir de ahi trabajaremos directamente sobre esta branch

### Resulting decision

A new `v1.5.0.2` branch was created from the actual reliability HEAD, preserving I03/I04 and all current features. The pre-UI startup failure was registered as an open, non-reproducible incident with unknown cause.

Later, the owner explicitly deprioritized trying to reproduce it:

### Owner

> creo que en lugar de intentar resolver un bug que no podemos reproducir, es preferible continuar el desarrollo de la parte antiflag. con suerte ese error se resolverá, pudiera ser porque el proceso estaba haciendose. y si despues de completar el noflag aparece, ya lo solucionaremos.
> entonces elabora el plan a seguir, despues lo ejecutaremos. investiga y revisa bien todo lo que se ha hecho y todo lo que no, y si es correcto seguir ese plan o hay alguna modificacion o mejora

### Decision

The incident remains a **watchpoint**, not the active development block. Architecture/hardening work proceeds first. If the failure reappears after the new baseline is established, it should be investigated with real evidence.

---

## 2. Review of the old noflag plan changed the order

The code review established several important facts:

- normal startup is native from Host to Runtime, but the main WPF UI still normally returns to Windows PowerShell;
- the WPF launch currently uses `-ExecutionPolicy Bypass`;
- several background/feature workers also use Bypass;
- normal Runtime startup can enter dependency repair/download behavior before the UI if components are missing or invalid;
- `OperationWorker.ps1` remains a broad PowerShell operation broker;
- current Go executable builds are post-processed by a custom PE icon-resource helper;
- the old recorded VirusTotal SHA belongs to an older RC30 package and is not evidence for the current 1.5.x package.

### Initial revised execution direction

The discussion converged on the following engineering order:

1. establish exact current evidence;
2. make startup local/read-only and separate check from repair;
3. remove inherited `ExecutionPolicy Bypass` where normal supported invocation works;
4. narrow process/worker boundaries;
5. move to a conventional reproducible Windows executable build;
6. only then perform current-artifact scanner/Nexus validation;
7. resolve remaining vendor false positives through official vendor channels rather than random binary mutation.

The intent throughout is legitimate false-positive reduction by conventional engineering, **not scanner evasion**.

---

## 3. Authenticode and SignPath were considered, then made optional/later

### Owner

> rapidamente,que es el authenticode? hay que pagar para tener esa firma?

### Discussion result

Authenticode was explained as Windows code signing that binds publisher identity to exact file bytes. Commercial certificates normally cost money.

### Owner

> no voy a pagar porque es un programa open source, no comercial y fanmade para un juego en particular.
> hay alguna alternativa que se ajuste a esto?

SignPath Foundation was identified as a possible free open-source signing route.

### Owner clarification

> wice games es una empresa desarrolladora de videojuegos, no está relacionada con pmm. los proyectos de mods y fanmade son mios, personales, no de la empresa.
> Entonces entraremos con SignPath foundation cuando el programa esté listo, pero todavía quedan algunas features que reparar o mejorar, entonces el signpath deberia ser despues de eso verdad? aunque si signpath funciona solo con los exe, entonces si podemos continuar el desarrollo ya que los exe en principio no cambiarian...

### Final ownership/signing decision

- PMM is a **personal open-source/fan-made project**.
- Do not attribute PMM to Wice Games Studio.
- Signing is done only after final executable-affecting development.
- Every future changed/rebuilt signed artifact would require signing again.
- SignPath/Authenticode is useful provenance, but later the owner reconsidered whether it is proportionate for PMM.

### Owner

> entonces sigamos hasta nf05, despues le haremos las curas a pmm para asegurar que todos los nodos funcionan como es deseado (por ejemplo la feature updates todavía no hace lo que se requiere)
> entonces despues de desarrollar el programa y dejarlo listo, podemos dejar firmada la version. en el caso de una nueva version, bugfix, nuevas features etc deberíamos volver a hacer la firma?

### Decision

Architecture/hardening and product correctness come first. Signing, if used, is a release step after the program is ready, not part of ordinary development.

---

## 4. The conversation questioned whether PMM should have several PMM-owned EXEs at all

### Owner

> esto me hace reflexionar sobre si la estructura del programa esta bien así. en un principio no iba a tener ningun exe, segun hemos ido avanzando se han ido creando exe para algunas cosas. y si metemos todo el programa en un exe? o unificamos los exes? no sería mejor que todo este dentro del exe? la unica carpeta seria workspace...

### Exploration

A distinction was made between:

1. **one file / one process / opaque bundle**;
2. **one PMM-owned executable that can create separate worker processes**;
3. keeping modules/resources/data externally visible and editable.

The second model was judged much more suitable.

Example process model:

```text
PMM.exe
├─ PMM.exe --worker analyze
├─ PMM.exe --worker build
├─ PMM.exe --worker update
└─ PMM.exe --worker fixlab
```

Every worker is a separate Windows process even though all are created from the same binary.

---

## 5. Crash-isolation requirement

### Owner

> no crashearia el programa entero al fallar uno de los worker si metemos todos los exes?

### Decision

No, provided workers remain **separate OS processes**.

The architecture must not become:

```text
one PMM.exe process
├─ UI thread
├─ Analyze thread
├─ Build thread
└─ FixLab thread
```

for failure-sensitive heavy work.

Instead:

```text
PMM.exe                       # UI/supervisor process
PMM.exe --worker analyze      # separate process
PMM.exe --worker build        # separate process
PMM.exe --worker update       # separate process
PMM.exe --worker fixlab       # separate process
```

A worker failure should produce a controlled exit/result and leave the UI alive.

Desired worker properties discussed:
- operation identity;
- private staging/work path;
- timeouts where meaningful;
- cancellation;
- stdout/stderr or structured diagnostics;
- defined exit codes;
- no live commit until successful validation;
- rollback/recovery records for mutations.

Thus the target is **one PMM-owned executable, not one process**.

---

## 6. Project philosophy and intended long-term direction

### Owner

> este programa es basicamente para aprender a programar algo complejo. todavía no se cual es la mejor manera de orientar este proyecto en concreto.
> sinceramente me parece que eso de la firma signpath o authenticode es algo demasiado grande para un programa de gestion de mods de un videojuego que esta de moda, y que van a salir 2 palword mas asique no sabemos si este va a medrar en el tiempo. y personalmente, el juego está "bien" pero tiene un diseño base que no da más de sí, ayuda a crear la "ilusion" de un pokemon bueno, pero no es un gran juego en ese sentido, es bastante limitado y repetitivo, y ni siquiera soy tan fan de la saga pokemon, solo jugué el amarillo y ni me lo pasé, aunque me gustó bastante.
> dicho eso sí pondría todos los exe en un solo exe del cual sacar nuevas instancias para los subprocesos. mantendría la arquitectura accesible para que cualquiera pueda modificarlo facilmente sin tener que tocar el exe para nada. si logramos que el mismo exe sobreviva hasta la version 6.2 sería un buen logro, una demostracion de que un programa puede evolucionar muchisimo sobre una buena base, bien pensada y preparada para sostenerse. tampoco es para sembrar un nuevo paradigma en el desarrollo de programas, pero en cualquier caso una buena experiencia de aprendizaje y si esto le sirve a miles de usuarios, si conseguimos que instalar pmm sea lo básico para jugar palworld modeado, incluyendo todas las formas de modeo, un editor nativo que usa ue y las demas herramientas de manera integrada, que todos lo usen para crear facilmente un servidor, etc; es el objetivo, facilitar el modding en palworld en todas las formas posibles. incluyendo conexion con la workshop, nexus, otras paginas de mods, un lugar comun de pmm para las CKL y donde la comunidad comparte sus nuevas updates, etc
> el target es ambicioso. quiero completar este desarrollo que ya lleva bastante tiempo hasta una version basica pero que sea funcional y que sirva, nos vamos a conformar con: que se pueda actualizar mods automaticamente, que la gente pueda hacer un parche de compatibilidad, restaurar mods antiguos, crear sus propios mods usando IA que se ayuda de PMM. ese es el funcionamiento actual de pmm. hacer que el programa se suba a nexus sin problemas, que todo funcione bien, es el objetivo de esta 1.5.0.2
> creo que deberiamos unificar los exes unicamente, dejar expuesto todo lo posible, hacer que se verifique en nexus y hacer que lo que ya hay funcione como es deseado. pero no se en qué orden hacer esas cosas. tu propuesta?

### Architectural conclusion from that discussion

The project should not pursue architectural sophistication for its own sake.

For 1.5.0.2:
- unify PMM-owned executables;
- keep the architecture open;
- keep modules/data/resources editable;
- improve legitimate scanner/Nexus behavior;
- make existing product capabilities actually work;
- avoid adding the future large-scope roadmap until the current baseline is complete.

A long-lived PMM.exe was treated as a desirable experiment in stable contracts, not as an absolute requirement that the binary can never change.

The stable core should preferably own:
- startup/supervision;
- worker dispatch;
- bounded IPC/process contracts;
- integrity/safety primitives;
- dependency status/explicit repair entry points;
- selected native operations.

Most changing behavior should remain in open modules/resources where practical.

---

## 7. External EXEs are explicitly outside the unification target

### Owner

> obviamente me refiero a los propios... los exe externos estan certificados y no son el problema, ni necesitamos incluirlos en nuestro binario.
>
> en cuanto a mantener el exe, sí por supuesto. si llegamos a crear un editor integrado con ue y demas herramientas de modding, se puede considerar aumentar el exe. 6.2 es una exageracion, simplemente la idea de mantenerlo abierto, que no necesiten recompilar, que sea facil de compartir y de desarrollar.
> en general me parece un buen plan, creo que sería más conveniente continuar usando codex, y no quiero tener que entregar un handoff. incluiremos el nuevo plan en github para que lo continue desde ahi. crea un informe detallado para ello, pero primero dime un resumen aqui para que lo pueda validar y despues lo subimos a git para iniciar el proceso en codex

### Final clarification

The target is specifically PMM-owned executables such as:
- PMM.exe;
- PMMRuntime.exe;
- PMMFixLab.exe when parity allows.

Third-party executables/runtimes stay external.

The architecture remains easy to share/develop without recompiling PMM.exe for ordinary module/data changes.

The repository itself, through `START_HERE_NEW_PROJECT.md`, `NEXT_SESSION.md` and the authoritative plan, becomes the handoff to Codex. No separate manually transported handoff is required.

---

## 8. Product-scope order accepted before implementation

The validated summary converged on:

1. freeze current contracts/baseline;
2. unify PMM-owned executables while preserving isolated workers;
3. harden startup/process/dependency behavior for legitimate Nexus/scanner compatibility;
4. establish a conventional reproducible PMM.exe build;
5. then repair/finish existing product capabilities;
6. full regression;
7. validate the actual candidate in Nexus/scanners.

The feature-curing order proposed was:

1. Updates;
2. compatibility patch workflow;
3. FixLab / old-mod restoration;
4. AI mod creation and related flows.

Large future expansions such as Workshop, server management, complete UE-integrated editor and broader community infrastructure are intentionally outside the 1.5.0.2 completion scope.

---

## 9. Critical clarification: AI is the mod creator; PMM is the capability plane

After validating the overall plan, the owner corrected one important phrase.

### Owner

> dado que no hay un verdadero editor interno funcional, el concepto es que la ia sea la responsable de la creacion de un nuevo mod, lo que pmm ofrece es acceso directo a herramientas, capacidad de probar el juego, etc pero la creacion queda más a cargo de la ia, que usa pmm para sus fines, los que el usuario ha definido.
> por lo demas todo bien, asique puedes crear y subir a git

### Final product interpretation

For 1.5.0.2:

- **user**: defines the desired mod/outcome;
- **AI**: performs the primary design/reasoning/creation work;
- **PMM**: exposes safe capabilities the AI can use.

PMM capabilities can include:
- game/reference evidence;
- asset/tool access;
- bounded build operations;
- staging;
- validation;
- transactional deploy/rollback;
- permitted game launch/testing/observation;
- durable project/session state;
- diagnostics returned to the same AI workflow.

A complete internal graphical mod editor is **not** required to close 1.5.0.2.

This clarification is normative and is also copied into
`V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`.

---

## 10. Adopted 1.5.0.2 execution model

The detailed plan was committed to the branch with the following sequence:

- **NF00** plan/contract freeze;
- **NF01** exact baseline and migration matrix;
- **NF02** Host + Runtime convergence into one PMM.exe;
- **NF03** startup offline, explicit repair, PowerShell policy cleanup;
- **NF04** one-executable worker architecture;
- **NF04F** FixLab convergence when parity permits;
- **NF05** conventional reproducible PMM.exe build;
- **P01** Updates product cure;
- **P02** compatibility patch product cure;
- **P03** old-mod restoration/FixLab product cure;
- **P04** AI-created mod workflow through PMM capabilities;
- **NF06** full regression/package preflight;
- **NF07** current-artifact scanner/Nexus validation;
- **NF08** optional signing/provenance later.

At the end of this transcript, **NF01 is the next implementation block**.

---

## 11. Guidance for future readers

Do not treat exploratory ideas in this transcript as implementation requirements.

In particular:
- do not build a monolithic one-process application;
- do not embed all editable PMM content into the executable;
- do not absorb external third-party EXEs;
- do not make SignPath a release blocker;
- do not chase the unreproduced startup bug before NF01/NF02/NF03 unless new evidence appears;
- do not build a complete internal mod editor as the meaning of AI mod creation;
- do not assume a scanner cause from an old VirusTotal sample.

Use the transcript to understand **intent and tradeoffs**.

Use the authoritative plan to implement them.
