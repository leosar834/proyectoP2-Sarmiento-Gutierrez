<?php

namespace Database\Seeders;

use App\Models\CicloLectivo;
use App\Models\Curso;
use App\Models\Division;
use App\Models\Especialidad;
use App\Models\Nivel;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * SEEDER DE PRUEBA — arma TODA la estructura académica base desde una
 * base vacía (pensado para correr después de `migrate:fresh` +
 * `db:seed --class=CatalogoSeeder`, ver el docblock de ese último):
 * niveles, divisiones, ciclo lectivo, cursos y especialidades. Al
 * final, delega en `PruebaVolumenTallerSeeder` para las materias/grupos
 * de taller y los alumnos por curso — esa parte no se duplica acá, se
 * reusa tal cual (mismos criterios: especialidad NULL en 1°/2° año,
 * 4 materias × 3 grupos por nivel, 30/25/15-20 alumnos por curso según
 * el año).
 *
 * NO crea institución ni usuarios — eso es a propósito responsabilidad
 * de "Registrá la primera cuenta de administrador acá" en la pantalla
 * de login (`RegistroAdministradorController`), para que cualquier
 * institución que instale el sistema pase por ese alta real, no por un
 * seeder con credenciales hardcodeadas. Da igual el orden respecto a
 * este seeder — `ciclos_lectivos`/`cursos`/etc. no tienen FK a
 * `institucion`, así que podés correr esto antes o después de
 * registrar al administrador.
 *
 *   php artisan db:seed --class=PruebaEstructuraCompletaSeeder
 *
 * Cada pieza de la estructura base se crea SOLO si falta (chequeo por
 * nombre/numero_orden, no un guard de "todo o nada" como en
 * `PruebaVolumenTallerSeeder`) — correrlo de nuevo después de agregar
 * algo más a mano no duplica lo que ya existe. La única parte que sí
 * puede fallar en una segunda corrida es la delegación final a
 * `PruebaVolumenTallerSeeder`, que mantiene su propio guard (ver su
 * docblock) — corré `LimpiarPruebaVolumenTallerSeeder` antes si querés
 * repetir esa parte sin tocar la estructura base.
 *
 * Ojo: si algo quedó dado de baja lógicamente (nivel/división/
 * especialidad borrados) con el mismo nombre que este seeder necesita
 * crear, `firstOrCreate` no lo va a encontrar (excluye borrados por
 * default) y el `INSERT` va a chocar contra la unique key — que acá no
 * excluye `deleted_at`, mismo criterio que en el resto del sistema. En
 * ese caso hay que restaurarlo a mano en vez de correr esto.
 *
 * Para volver a cero por completo (incluida esta estructura base, que
 * no tiene una marca "[PRUEBA]" como sí tienen las materias y los
 * alumnos, así que no hay un cleanup granular para ella):
 * `php artisan migrate:fresh` + `db:seed --class=CatalogoSeeder` de
 * nuevo — el mismo camino que ya se venía usando.
 *
 * Genera:
 *   - 6 niveles (1° a 6° año).
 *   - 3 divisiones ("1a", "2a", "3a" — mismo criterio de nombre que el
 *     docblock de `App\Models\Division`, reutilizables entre todos los
 *     niveles vía `Curso`).
 *   - Un ciclo lectivo abierto para el año actual, SI no hay ninguno
 *     abierto ya (si hay uno cerrado del mismo año, avisa y no sigue —
 *     no se puede abrir dos ciclos con el mismo año, `uq_ciclos_lectivos_anio`).
 *   - 18 cursos (6 niveles × 3 divisiones), turno "mañana".
 *   - 3 especialidades (Electromecánica, Maestro Mayor de Obra,
 *     Electrónica — los mismos ejemplos que ya usa el docblock de
 *     `App\Models\Especialidad` para esta institución).
 *   - Todo lo que arma `PruebaVolumenTallerSeeder` sobre esa base.
 */
class PruebaEstructuraCompletaSeeder extends Seeder
{
    use WithoutModelEvents;

    private const NIVELES = [
        [1, '1er año'],
        [2, '2do año'],
        [3, '3er año'],
        [4, '4to año'],
        [5, '5to año'],
        [6, '6to año'],
    ];

    private const DIVISIONES = ['1a', '2a', '3a'];

    private const ESPECIALIDADES = ['Electromecánica', 'Maestro Mayor de Obra', 'Electrónica'];

    public function run(): void
    {
        $huboError = false;

        DB::transaction(function () use (&$huboError) {
            $niveles = $this->crearNiveles();
            $divisiones = $this->crearDivisiones();
            $ciclo = $this->resolverCicloLectivo();

            if ($ciclo === null) {
                $huboError = true;
                return;
            }

            $cursosCreados = $this->crearCursos($niveles, $divisiones, $ciclo);
            $especialidadesCreadas = $this->crearEspecialidades();

            $this->command?->info("Niveles disponibles: {$niveles->count()}.");
            $this->command?->info("Divisiones disponibles: {$divisiones->count()}.");
            $this->command?->info("Ciclo lectivo abierto: {$ciclo->anio}.");
            $this->command?->info("Cursos nuevos creados: {$cursosCreados}.");
            $this->command?->info("Especialidades nuevas creadas: {$especialidadesCreadas}.");
        });

        if ($huboError) {
            return;
        }

        $this->command?->info('Estructura base lista — sigue PruebaVolumenTallerSeeder (materias, grupos, alumnos)...');
        $this->call(PruebaVolumenTallerSeeder::class);
    }

    private function crearNiveles(): Collection
    {
        foreach (self::NIVELES as [$orden, $nombre]) {
            Nivel::firstOrCreate(['numero_orden' => $orden], ['nombre' => $nombre]);
        }

        return Nivel::whereIn('numero_orden', array_column(self::NIVELES, 0))
            ->orderBy('numero_orden')
            ->get();
    }

    private function crearDivisiones(): Collection
    {
        foreach (self::DIVISIONES as $nombre) {
            Division::firstOrCreate(['nombre' => $nombre]);
        }

        return Division::whereIn('nombre', self::DIVISIONES)->get();
    }

    /**
     * Usa el ciclo lectivo abierto si ya hay uno. Si no hay ninguno
     * abierto pero SÍ existe uno (cerrado) para el año actual, no se
     * puede abrir otro con el mismo año — en ese caso avisa y no sigue;
     * hay que abrir uno a mano para otro año desde "Ciclo lectivo".
     */
    private function resolverCicloLectivo(): ?CicloLectivo
    {
        $abierto = CicloLectivo::where('estado', 'abierto')->first();
        if ($abierto) {
            return $abierto;
        }

        $anioActual = Carbon::now()->year;
        if (CicloLectivo::where('anio', $anioActual)->exists()) {
            $this->command?->error(
                "Ya existe un ciclo lectivo para {$anioActual} pero está cerrado, y no "
                .'hay ningún otro abierto — no se puede abrir uno nuevo para el mismo '
                .'año. Abrí uno a mano para otro año desde "Ciclo lectivo" y corré este '
                .'seeder de nuevo.'
            );
            return null;
        }

        $ciclo = CicloLectivo::create([
            'anio' => $anioActual,
            'fecha_inicio' => Carbon::create($anioActual, 3, 1)->format('Y-m-d'),
            'estado' => 'abierto',
        ]);

        $this->command?->info("No había ningún ciclo lectivo abierto — se abrió uno nuevo para {$anioActual}.");

        return $ciclo;
    }

    private function crearCursos(Collection $niveles, Collection $divisiones, CicloLectivo $ciclo): int
    {
        $creados = 0;

        foreach ($niveles as $nivel) {
            foreach ($divisiones as $division) {
                $existe = Curso::where('nivel_id', $nivel->id_nivel)
                    ->where('division_id', $division->id_division)
                    ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
                    ->exists();

                if ($existe) {
                    continue;
                }

                Curso::create([
                    'nivel_id' => $nivel->id_nivel,
                    'division_id' => $division->id_division,
                    'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
                    'turno' => 'mañana',
                ]);
                $creados++;
            }
        }

        return $creados;
    }

    private function crearEspecialidades(): int
    {
        $creadas = 0;

        foreach (self::ESPECIALIDADES as $nombre) {
            $especialidad = Especialidad::firstOrCreate(['nombre' => $nombre]);
            if ($especialidad->wasRecentlyCreated) {
                $creadas++;
            }
        }

        return $creadas;
    }
}
