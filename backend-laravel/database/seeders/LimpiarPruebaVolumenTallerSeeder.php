<?php

namespace Database\Seeders;

use App\Models\Alumno;
use App\Models\GrupoEdFisica;
use App\Models\GrupoTaller;
use App\Models\Inscripcion;
use App\Models\MateriaTaller;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Deshace exactamente lo que crea `PruebaVolumenTallerSeeder` — identifica
 * cada fila por las mismas marcas (rango de DNI 90000000-90999999 +
 * sufijo " (PRUEBA)" en alumnos, prefijo "[PRUEBA] " en materias de
 * taller y grupos de educación física) y no toca ningún otro dato.
 *
 *   php artisan db:seed --class=LimpiarPruebaVolumenTallerSeeder
 *
 * OJO — esto hace un borrado FÍSICO (forceDelete/DELETE), no lógico.
 * Todo corre dentro de una transacción: si algo bloquea el borrado (por
 * ejemplo, se tomó asistencia real sobre alguno de estos grupos/alumnos
 * de prueba mientras se probaba la app — quedarían `planillas_asistencia`
 * o `ausencias_docentes` reales apuntando a un grupo de taller marcado),
 * MySQL rechaza esa fila puntual por la foreign key (protección
 * RESTRICT, no hay ON DELETE CASCADE en esas tablas) y la transacción
 * entera se revierte sin dejar nada a medio borrar — no corrompe ni deja
 * huérfano nada. En ese caso hay que decidir a mano qué hacer con esa
 * asistencia antes de volver a correr esto.
 */
class LimpiarPruebaVolumenTallerSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        DB::transaction(function () {
            $alumnoIds = Alumno::withTrashed()
                ->whereRaw('CAST(dni AS UNSIGNED) BETWEEN ? AND ?', [
                    PruebaVolumenTallerSeeder::DNI_DESDE,
                    PruebaVolumenTallerSeeder::DNI_HASTA,
                ])
                ->where('apellido', 'like', '%(PRUEBA)')
                ->pluck('id_alumno');

            $materiaIds = MateriaTaller::withTrashed()
                ->where('nombre', 'like', PruebaVolumenTallerSeeder::MARCA.'%')
                ->pluck('id_materia_taller');

            $grupoTallerIds = GrupoTaller::withTrashed()
                ->whereIn('materia_taller_id', $materiaIds)
                ->pluck('id_grupo_taller');

            $grupoEdFisicaIds = GrupoEdFisica::withTrashed()
                ->where('nombre_grupo', 'like', PruebaVolumenTallerSeeder::MARCA.'%')
                ->pluck('id_grupo_ed_fisica');

            $inscripcionIds = Inscripcion::whereIn('alumno_id', $alumnoIds)->pluck('id_inscripcion');

            // Tablas puente primero (no tienen soft delete, y nada más
            // depende de ellas).
            DB::table('alumnos_grupos_taller')->whereIn('grupo_taller_id', $grupoTallerIds)->delete();
            DB::table('alumnos_grupos_taller')->whereIn('inscripcion_id', $inscripcionIds)->delete();
            DB::table('alumnos_grupos_ed_fisica')->whereIn('grupo_ed_fisica_id', $grupoEdFisicaIds)->delete();
            DB::table('alumnos_grupos_ed_fisica')->whereIn('inscripcion_id', $inscripcionIds)->delete();

            // `usuarios_grupos_taller` (asignación de profesor/preceptor a
            // estos grupos de taller de prueba) tiene ON DELETE CASCADE
            // desde grupos_taller — desaparece solo al borrar el grupo,
            // no hace falta tocarla acá.

            // Inscripciones antes que alumnos (FK inscripciones.alumno_id).
            // Si hay planillas/detalles de asistencia reales colgando de
            // alguna de estas inscripciones, esta línea es la que va a
            // fallar con un error de foreign key — ver el docblock.
            Inscripcion::whereIn('id_inscripcion', $inscripcionIds)->delete();

            // Alumnos (legajo) — borrado físico real, no lógico.
            Alumno::withTrashed()->whereIn('id_alumno', $alumnoIds)->forceDelete();

            // Grupos de taller antes que su materia (FK materia_taller_id).
            GrupoTaller::withTrashed()->whereIn('id_grupo_taller', $grupoTallerIds)->forceDelete();
            MateriaTaller::withTrashed()->whereIn('id_materia_taller', $materiaIds)->forceDelete();

            GrupoEdFisica::withTrashed()->whereIn('id_grupo_ed_fisica', $grupoEdFisicaIds)->forceDelete();

            $this->command?->info('Borrados: '.$alumnoIds->count().' alumnos, '.$inscripcionIds->count().' inscripciones, '
                .$materiaIds->count().' materias de taller, '.$grupoTallerIds->count().' grupos de taller, '
                .$grupoEdFisicaIds->count().' grupos de educación física.');
        });

        $this->command?->info('Listo — la base quedó como estaba antes de correr PruebaVolumenTallerSeeder.');
    }
}
