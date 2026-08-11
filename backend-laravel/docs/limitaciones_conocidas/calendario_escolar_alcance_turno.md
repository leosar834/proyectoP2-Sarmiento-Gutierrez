# Limitación conocida: `dias_sin_clases.alcance` por turno no aplica a taller/ed_fisica

**Estado:** documentada, sin resolver — a decidir más adelante.
**Dónde vive en el código:** `app/Http/Controllers/Api/AsistenciaController.php`, método privado `buscarDiaSinClasesHoy()` (docblock incluido ahí también).

## El problema

La tabla `dias_sin_clases` tiene una columna `alcance` (`todos` / `mañana` / `tarde` / `noche`) que permite declarar un día sin clases acotado a un solo turno, en vez del día completo.

Esto funciona correctamente para el área **teórica**, porque `cursos.turno` existe como columna: si hoy se declara "sin clases" con `alcance: mañana`, solo se bloquean los cursos cuyo `turno` sea `mañana`; los de tarde y noche se pueden abrir sin problema.

Para las áreas **taller** y **educación física**, esto NO funciona igual, porque ni `grupos_taller` ni `grupos_ed_fisica` tienen una columna `turno` en el schema actual. El sistema no tiene ningún dato con el que comparar el `alcance` de un día sin clases contra el horario real de un grupo de taller o de educación física.

**Comportamiento actual (implementado a propósito, no es un bug):** un día sin clases con `alcance` acotado a un turno específico (`mañana`/`tarde`/`noche`) **no bloquea ninguna planilla de taller ni de educación física**, sin importar en qué horario ocurra en la realidad esa clase. Solo un día sin clases de `alcance: todos` (el día completo) bloquea las tres áreas por igual.

## Impacto concreto

Si un taller puntual efectivamente se dicta solo por la mañana, y ese día se declara "sin clases" nada más que para la mañana (`alcance: mañana`), el sistema **no lo va a bloquear** — un profesor de taller podría, en teoría, abrir la planilla igual ese día. La única forma de garantizar que ese taller quede cubierto es declarar el día completo sin clases (`alcance: todos`), lo cual también bloquearía sin necesidad los cursos teóricos de tarde/noche que sí tendrían clase normal.

## Opciones para resolverlo más adelante

### Opción 1 — Agregar columna `turno` a `grupos_taller` y `grupos_ed_fisica`
Cambio de schema: una migración nueva que agregue `turno ENUM('mañana','tarde','noche')` a ambas tablas (nullable al principio, para no romper filas existentes, con un plan de completarlas a mano o inferirlas de algún otro dato si existe). Una vez poblada, `buscarDiaSinClasesHoy()` se actualiza para comparar contra ese campo igual que ya hace con `Curso::turno`.

- **Pros:** resuelve el problema de raíz, deja el sistema consistente entre las tres áreas.
- **Contras:** toca el schema de la base (no solo la API), hay que decidir qué turno asignarle a los grupos de taller/ed_fisica ya existentes, y evaluar si `turno` es realmente un dato que tiene sentido por grupo completo (¿puede un mismo grupo de taller tener sesiones en más de un turno a lo largo de la semana? Si es así, una sola columna `turno` no alcanzaría y habría que modelarlo distinto, por ejemplo por día de la semana + horario).

### Opción 2 — Tratar el alcance por turno como advertencia, no como bloqueo silencioso, para taller/ed_fisica
En vez de que el `alcance` acotado simplemente no tenga efecto sin avisar nada, la API podría igual dejar abrir la planilla de taller/ed_fisica en esos casos, pero devolver un aviso explícito (por ejemplo un campo `advertencias` en la respuesta) indicando que hoy hay un día sin clases parcial que no se pudo verificar contra el turno real del grupo, para que quien esté tomando asistencia lo vea y decida con criterio humano.

- **Pros:** no requiere tocar el schema, es rápido de implementar, y es más honesto que el silencio actual (el usuario se entera de que hay una situación ambigua en vez de no enterarse de nada).
- **Contras:** no resuelve el problema de fondo, solo lo hace visible; sigue dependiendo de que una persona interprete la advertencia correctamente.

### Opción 3 — Dejarlo como está (documentado, sin resolver)
Mantener el comportamiento actual: `alcance` por turno solo aplica de verdad a `teorica`; para taller/ed_fisica únicamente `alcance: todos` tiene efecto. Es la opción elegida por ahora.

- **Pros:** cero trabajo adicional, no complica el schema, y en la práctica declarar el día completo sin clases cuando hay dudas es una solución razonable (mejor bloquear de más que de menos).
- **Contras:** sigue existiendo el hueco descripto arriba si alguna vez se necesita de verdad un feriado acotado a un turno que afecte específicamente a un taller o a educación física.

## Decisión tomada (24/07/2026)

Por ahora se deja como está (Opción 3) — el comportamiento queda documentado en el código y en este archivo para retomarlo más adelante si hace falta. No se tomó ninguna acción de código adicional a partir de esta conversación.

## Actualización (11/08/2026): mitigación práctica ya disponible

`buscarDiaSinClasesHoy()` en `AsistenciaController` había quedado borrado por
completo sin querer (commit `3befbc5`, 24/07/2026, el mismo día de la
decisión de arriba) — no bloqueaba ningún día sin clases, para ninguna
área, ni siquiera `alcance: todos`. Se restauró tal cual estaba, así que la
limitación de este documento (el `alcance` por turno no aplica a
taller/ed_fisica) sigue siendo exactamente la misma que se decidió dejar
como Opción 3 — no cambió nada de lo de acá arriba.

Lo que sí se identificó en esta misma revisión es que **ya existe** una
vía distinta, más precisa, para cubrir el caso concreto que este
documento describe (un taller/ed_fisica puntual que no debería tomar
asistencia un día u horario determinado): `ausencias_docentes`
(`POST /api/ausencias-docentes`, ver `AusenciasDocentesController` y el
docblock de `App\Models\AusenciaDocente`). Nació como "el profesor
notifica su ausencia", pero el mecanismo no le pregunta el motivo —
solo registra "este grupo, hoy, no se toma asistencia" y bloquea la
apertura de la planilla de ese grupo puntual, mismo efecto que
`DiaSinClase` pero scopeado a un solo grupo en vez de a todo un turno.
Como lo carga el propio profesor sobre su propio grupo, no depende de
que el sistema sepa en qué turno cursa ese grupo — cubre el hueco de
raíz para ese caso puntual, sin tocar el schema.

Esto no reemplaza una solución a nivel calendario (sigue sin haber forma
de que la jefa de preceptores/administración declare de antemano "mañana
no hay taller" sin pasar por el profesor), y tiene sus propias
limitaciones: solo lo puede notificar el profesor asignado al grupo (no
el preceptor de taller), solo el mismo día (no con anticipación), y solo
antes de que exista una planilla para ese grupo+fecha. Para el caso de
uso de este documento — un taller/ed_fisica que puntualmente no
corresponde un día — alcanza. Las opciones 1 y 2 de arriba siguen
abiertas si en algún momento hace falta cubrir el caso a nivel
calendario/administración en vez de a nivel profesor.
