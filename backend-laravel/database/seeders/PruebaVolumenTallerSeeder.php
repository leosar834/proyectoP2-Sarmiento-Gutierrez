<?php

namespace Database\Seeders;

use App\Models\Alumno;
use App\Models\CicloLectivo;
use App\Models\Curso;
use App\Models\Especialidad;
use App\Models\GrupoEdFisica;
use App\Models\GrupoTaller;
use App\Models\Inscripcion;
use App\Models\MateriaTaller;
use App\Models\Nivel;
use App\Models\Rol;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * SEEDER DE PRUEBA — NO forma parte de la instalación limpia del sistema.
 * A diferencia de `CatalogoSeeder` (configuración institucional real) o
 * `DatabaseSeeder` (bootstrap de desarrollo con el usuario admin de
 * prueba), esto es puramente para validar que la app aguanta un volumen
 * de datos parecido al real, ANTES de la puesta en producción real. Por
 * eso `DatabaseSeeder::run()` NO lo llama — se corre a mano, una sola vez,
 * cuando hace falta.
 *
 * Requiere que YA existan niveles/divisiones/cursos/ciclo lectivo (solo
 * agrega materias/grupos/alumnos sobre esa base) — si estás arrancando
 * desde una base recién creada con `migrate:fresh` y no tenés nada de
 * eso todavía, corré `PruebaEstructuraCompletaSeeder` en cambio: arma
 * toda la estructura base y al final llama a este seeder solo.
 *
 *   php artisan db:seed --class=PruebaVolumenTallerSeeder
 *
 * Para deshacerlo por completo (vuelve a dejar exactamente lo que había
 * antes de correr esto, siempre que no se haya tomado asistencia real
 * sobre los grupos/alumnos de prueba mientras tanto — ver el docblock de
 * `LimpiarPruebaVolumenTallerSeeder`):
 *
 *   php artisan db:seed --class=LimpiarPruebaVolumenTallerSeeder
 *
 * Qué agrega (NO toca niveles/divisiones/cursos/especialidades ya
 * cargados, solo lee sobre ellos):
 *   - Por cada nivel existente (1° a 6° año): 4 materias de taller
 *     nuevas, cada una con 3 grupos de taller ("Grupo A/B/C") en el
 *     ciclo lectivo abierto. Especialidad NULL para 1°/2° año (ciclo
 *     básico — a propósito, para probar el cambio reciente que la
 *     habilita opcional), rotando entre las especialidades ya cargadas
 *     para 3° a 6° (ciclo superior).
 *   - Por cada nivel existente: 2 grupos de educación física ("Varones"
 *     / "Mujeres"), si hay al menos un usuario con rol
 *     `profesor_ed_fisica` cargado (si no hay ninguno, se salteta esta
 *     parte con un aviso — `grupos_ed_fisica.profesor_id` es obligatorio
 *     y este seeder no crea usuarios).
 *   - Alumnos + inscripciones para completar (no duplicar: si un curso
 *     ya tiene inscripciones activas, solo agrega lo que falta) cada
 *     curso existente hasta el volumen pedido: ~30 alumnos por división
 *     en 1er año, ~25 en 2do/3er año, entre 15 y 20 en 4to/5to/6to año.
 *     `Inscripcion.especialidad_id` queda NULL (no simula la
 *     distribución de especialidades del ciclo superior — eso es la
 *     responsabilidad de `DistribucionEspecialidadesController`, fuera
 *     del alcance de esta prueba).
 *
 * Todo lo que crea queda marcado sin ambigüedad para poder identificarlo
 * y limpiarlo después sin tocar un solo dato real cargado a mano:
 *   - Alumnos: DNI numérico entre 90000000 y 90999999 (fuera de
 *     cualquier rango real de DNI argentino actual) + apellido con
 *     sufijo " (PRUEBA)".
 *   - Materias de taller: nombre con prefijo "[PRUEBA] ".
 *   - Grupos de educación física: nombre_grupo con prefijo "[PRUEBA] ".
 *   - Grupos de taller: no llevan marca propia — se identifican siempre
 *     a través de su materia (que si está marcada).
 */
class PruebaVolumenTallerSeeder extends Seeder
{
    use WithoutModelEvents;

    public const MARCA = '[PRUEBA] ';
    public const DNI_DESDE = 90000000;
    public const DNI_HASTA = 90999999;

    private const NOMBRES = [
        'Juan', 'Sofía', 'Mateo', 'Valentina', 'Lucas', 'Martina', 'Tomás', 'Camila',
        'Bautista', 'Julieta', 'Benjamín', 'Catalina', 'Santiago', 'Delfina', 'Agustín',
        'Emilia', 'Franco', 'Renata', 'Ignacio', 'Milagros',
    ];

    private const APELLIDOS = [
        'González', 'Rodríguez', 'Fernández', 'López', 'Martínez', 'Díaz', 'Pérez',
        'Sánchez', 'Romero', 'Álvarez', 'Torres', 'Ruiz', 'Ramírez', 'Flores', 'Acosta',
        'Benítez', 'Medina', 'Herrera', 'Aguirre', 'Silva',
    ];

    private int $contadorAlumnos = 0;

    public function run(): void
    {
        if (MateriaTaller::withTrashed()->where('nombre', 'like', self::MARCA.'%')->exists()) {
            $this->command?->error(
                'Ya existen materias de taller marcadas como "'.self::MARCA.'"'
                .' — parece que este seeder ya corrió antes. Corré primero '
                .'"php artisan db:seed --class=LimpiarPruebaVolumenTallerSeeder" '
                .'si querés volver a generar los datos de prueba desde cero '
                .'(si no, esto termina fallando a mitad de camino por los '
                .'grupos de educación física, que no admiten nombres duplicados).'
            );
            return;
        }

        $ciclo = CicloLectivo::where('estado', 'abierto')->first();
        if (! $ciclo) {
            $this->command?->error('No hay ningún ciclo lectivo abierto — no se puede seedear. Abrí un ciclo lectivo primero.');
            return;
        }

        $niveles = Nivel::whereBetween('numero_orden', [1, 6])->orderBy('numero_orden')->get();
        if ($niveles->isEmpty()) {
            $this->command?->warn('No hay niveles con numero_orden entre 1 y 6 cargados — nada para hacer.');
            return;
        }

        $especialidades = Especialidad::orderBy('id_especialidad')->get();
        if ($especialidades->isEmpty()) {
            $this->command?->warn('No hay especialidades cargadas — todas las materias de taller de ciclo superior quedarán igual sin especialidad, no solo las de ciclo básico.');
        }

        $profesoresEdFisica = $this->obtenerProfesoresEdFisica();
        if ($profesoresEdFisica->isEmpty()) {
            $this->command?->warn('No hay ningún usuario con rol "profesor_ed_fisica" — se saltea la creación de grupos de educación física (profesor_id es obligatorio y este seeder no crea usuarios).');
        }

        $siguienteDni = $this->obtenerSiguienteDni();

        DB::transaction(function () use ($ciclo, $niveles, $especialidades, $profesoresEdFisica, &$siguienteDni) {
            $totalMaterias = 0;
            $totalGruposTaller = 0;
            $totalAlumnosNuevos = 0;
            $totalGruposEdFisica = 0;

            foreach ($niveles as $nivel) {
                [$materias, $grupos] = $this->crearMateriasYGruposDeTaller($nivel, $ciclo, $especialidades);
                $totalMaterias += $materias;
                $totalGruposTaller += $grupos;

                $totalAlumnosNuevos += $this->completarAlumnosDeCursos($nivel, $ciclo, $siguienteDni);

                if ($profesoresEdFisica->isNotEmpty()) {
                    $totalGruposEdFisica += $this->crearGruposEdFisica($nivel, $ciclo, $profesoresEdFisica);
                }
            }

            $this->command?->info("Materias de taller creadas: {$totalMaterias}");
            $this->command?->info("Grupos de taller creados: {$totalGruposTaller}");
            $this->command?->info("Grupos de educación física creados: {$totalGruposEdFisica}");
            $this->command?->info("Alumnos + inscripciones nuevas: {$totalAlumnosNuevos}");
        });

        $this->command?->info('Listo. Para deshacer todo: php artisan db:seed --class=LimpiarPruebaVolumenTallerSeeder');
    }

    /**
     * 4 materias de taller para este nivel (2 anuales + 2 semestrales,
     * para tener variedad de régimen de cursada en la prueba), cada una
     * con 3 grupos (A/B/C). Especialidad NULL en 1°/2° año a propósito
     * — es exactamente el caso que la migración
     * `make_especialidad_nullable_en_materias_taller` habilitó.
     *
     * @return array{0: int, 1: int} [materias creadas, grupos creados]
     */
    private function crearMateriasYGruposDeTaller(Nivel $nivel, CicloLectivo $ciclo, Collection $especialidades): array
    {
        $esCicloBasico = $nivel->numero_orden <= 2;
        $materiasCreadas = 0;
        $gruposCreados = 0;

        for ($i = 1; $i <= 4; $i++) {
            $especialidadId = null;
            if (! $esCicloBasico && $especialidades->isNotEmpty()) {
                $especialidadId = $especialidades[($i - 1) % $especialidades->count()]->id_especialidad;
            }

            $materia = MateriaTaller::create([
                'especialidad_id' => $especialidadId,
                'nombre' => self::MARCA."Taller {$nivel->nombre} - Materia {$i}",
                'regimen_cursada' => $i <= 2 ? 'anual' : 'semestral',
            ]);
            $materiasCreadas++;

            foreach (['Grupo A', 'Grupo B', 'Grupo C'] as $nombreGrupo) {
                GrupoTaller::create([
                    'materia_taller_id' => $materia->id_materia_taller,
                    'nivel_id' => $nivel->id_nivel,
                    'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
                    'nombre_grupo' => $nombreGrupo,
                ]);
                $gruposCreados++;
            }
        }

        return [$materiasCreadas, $gruposCreados];
    }

    /**
     * 2 grupos de educación física por nivel: Varones y Mujeres. El
     * schema no tiene columna de género ni de nivel en
     * `grupos_ed_fisica` (ver el docblock del modelo) — el año queda
     * reflejado únicamente en `nombre_grupo`, la asignación real de
     * alumnos a cada uno se hace a mano después (no hay dato de género
     * en `Alumno` para automatizarlo).
     */
    private function crearGruposEdFisica(Nivel $nivel, CicloLectivo $ciclo, Collection $profesores): int
    {
        $creados = 0;

        foreach (['Varones', 'Mujeres'] as $indice => $genero) {
            $profesor = $profesores[($nivel->numero_orden + $indice) % $profesores->count()];

            GrupoEdFisica::create([
                'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
                'nombre_grupo' => self::MARCA."{$nivel->nombre} - {$genero}",
                'regimen_cursada' => 'anual',
                'profesor_id' => $profesor->id_usuario,
            ]);
            $creados++;
        }

        return $creados;
    }

    /**
     * Completa (no duplica) cada curso existente de este nivel, en el
     * ciclo lectivo abierto, hasta el volumen pedido. Si el curso ya
     * tiene inscripciones activas (reales o de una corrida anterior de
     * este mismo seeder), solo agrega lo que falta para llegar al
     * objetivo — así correrlo dos veces no duplica alumnos de más.
     */
    private function completarAlumnosDeCursos(Nivel $nivel, CicloLectivo $ciclo, int &$siguienteDni): int
    {
        $objetivo = match (true) {
            $nivel->numero_orden === 1 => 30,
            in_array($nivel->numero_orden, [2, 3], true) => 25,
            in_array($nivel->numero_orden, [4, 5, 6], true) => rand(15, 20),
            default => null,
        };

        if ($objetivo === null) {
            return 0;
        }

        $cursos = Curso::where('nivel_id', $nivel->id_nivel)
            ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->get();

        if ($cursos->isEmpty()) {
            $this->command?->warn("{$nivel->nombre}: no hay ningún curso/división cargado en el ciclo lectivo abierto — no se pueden agregar alumnos ahí.");
            return 0;
        }

        $nuevos = 0;

        foreach ($cursos as $curso) {
            $actuales = Inscripcion::where('curso_id', $curso->id_curso)
                ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
                ->where('estado', 'activo')
                ->count();

            $faltan = max(0, $objetivo - $actuales);

            for ($n = 0; $n < $faltan; $n++) {
                $this->crearAlumnoEInscripcion($curso, $ciclo, $nivel, $siguienteDni);
                $siguienteDni++;
                $nuevos++;
            }
        }

        return $nuevos;
    }

    private function crearAlumnoEInscripcion(Curso $curso, CicloLectivo $ciclo, Nivel $nivel, int $dni): void
    {
        $indice = $this->contadorAlumnos++;
        $nombre = self::NOMBRES[$indice % count(self::NOMBRES)];
        $apellido = self::APELLIDOS[($indice * 7) % count(self::APELLIDOS)];

        // Edad aproximada acorde al año que cursa (1er año ronda los 12-13,
        // sumando un año por cada año de nivel), solo para que las fechas
        // de nacimiento generadas sean plausibles, no un dato exacto real.
        $edadAprox = 11 + $nivel->numero_orden;
        $mes = ($indice % 12) + 1;
        $dia = ($indice % 28) + 1;
        $fechaNacimiento = Carbon::create($ciclo->anio - $edadAprox, $mes, $dia);

        $fechaIngreso = $ciclo->fecha_inicio
            ? Carbon::parse($ciclo->fecha_inicio)->subYears($nivel->numero_orden - 1)
            : Carbon::create($ciclo->anio - ($nivel->numero_orden - 1), 3, 1);

        $alumno = Alumno::create([
            'nombre' => $nombre,
            'apellido' => $apellido.' (PRUEBA)',
            'dni' => (string) $dni,
            'fecha_nacimiento' => $fechaNacimiento->format('Y-m-d'),
            'fecha_ingreso_institucion' => $fechaIngreso->format('Y-m-d'),
        ]);

        Inscripcion::create([
            'alumno_id' => $alumno->id_alumno,
            'curso_id' => $curso->id_curso,
            'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            'especialidad_id' => null,
            'condicion' => 'regular',
            'estado' => 'activo',
        ]);
    }

    private function obtenerProfesoresEdFisica(): Collection
    {
        $rol = Rol::where('nombre', 'profesor_ed_fisica')->first();
        if (! $rol) {
            return collect();
        }

        return $rol->usuarios()->where('activo', true)->get();
    }

    /**
     * Primer DNI sintético libre — sigue desde el máximo ya usado en el
     * rango de prueba (incluidos alumnos borrados lógicamente, porque
     * `uq_alumnos_dni` no excluye `deleted_at`), para que correr este
     * seeder varias veces no choque con un DNI ya asignado por una
     * corrida anterior.
     */
    private function obtenerSiguienteDni(): int
    {
        $max = Alumno::withTrashed()
            ->whereRaw('CAST(dni AS UNSIGNED) BETWEEN ? AND ?', [self::DNI_DESDE, self::DNI_HASTA])
            ->selectRaw('MAX(CAST(dni AS UNSIGNED)) AS maximo')
            ->value('maximo');

        return $max ? ((int) $max) + 1 : self::DNI_DESDE;
    }
}
