<?php

namespace App\Imports;

use App\Models\Alumno;
use App\Models\Curso;
use App\Models\Division;
use App\Models\Inscripcion;
use App\Models\Nivel;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Concerns\WithHeadingRow;
use Maatwebsite\Excel\Concerns\ToCollection;
use PhpOffice\PhpSpreadsheet\Shared\Date as FechaExcel;

/**
 * Importación masiva de alumnos (legajo + inscripción juntos, mismo
 * criterio que `IngresantesController::crear` pero sin la restricción a
 * primer año — acá cubre cualquier nivel, porque el caso de uso real es
 * cargar de una todo el alumnado existente de la institución al poner
 * el sistema en marcha, no solo los ingresantes nuevos de este ciclo).
 * `IngresantesController` ya venía documentando esto como "mejora
 * pendiente sobre el mismo endpoint" — se resuelve acá como un
 * controlador aparte en vez de extender aquel, porque la regla de
 * "solo nivel 1" de `IngresantesController` es intencional para ESE
 * caso de uso (alta de ingresantes de ESTE ciclo) y no debe aflojarse
 * ahí solo para que la importación pueda reusarlo.
 *
 * `ToCollection` (no `ToModel`) a propósito: cada fila necesita resolver
 * nivel/división/curso, chequear el DNI contra la base, y decidir si
 * se saltea o se crea — lógica de negocio real, no un mapeo directo de
 * columnas a un modelo. `WithHeadingRow` deja usar el nombre de cada
 * columna (`$fila['dni']`, etc.) en vez de su posición, así que si el
 * usuario reordena columnas en su Excel no rompe nada.
 *
 * Nunca lanza una excepción por una fila mala: cada fila se resuelve a
 * 'creado' o 'salteado' con un motivo legible, y el archivo entero se
 * procesa de punta a punta — así una sola fila con un DNI repetido o un
 * curso inexistente no tira abajo la importación completa (decisión
 * tomada explícitamente: "saltear esa fila y avisar").
 */
class AlumnosImport implements ToCollection, WithHeadingRow
{
    /** @var array<int, array{fila: int, estado: string, motivo: ?string, alumno: ?string}> */
    public array $resultados = [];

    public function __construct(private readonly int $cicloLectivoId)
    {
    }

    public function collection(Collection $filas): void
    {
        foreach ($filas as $indice => $fila) {
            // +2: la fila 1 del Excel es el encabezado (ya consumido por
            // `WithHeadingRow`), y los índices de `$filas` arrancan en 0.
            $numeroFila = $indice + 2;

            try {
                $this->procesarFila($numeroFila, $fila);
            } catch (\Throwable $error) {
                $this->salteada($numeroFila, 'Error inesperado procesando la fila: '.$error->getMessage());
            }
        }
    }

    private function procesarFila(int $numeroFila, Collection $fila): void
    {
        $nombre = trim((string) ($fila['nombre'] ?? ''));
        $apellido = trim((string) ($fila['apellido'] ?? ''));
        $dni = trim((string) ($fila['dni'] ?? ''));
        $nivelNumero = $fila['nivel'] ?? null;
        $divisionNombre = trim((string) ($fila['division'] ?? ''));

        if ($nombre === '' || $apellido === '' || $dni === '') {
            $this->salteada($numeroFila, 'Faltan datos obligatorios (nombre, apellido o DNI).');

            return;
        }

        // `uq_alumnos_dni` no excluye borrados lógicos (ver nota en el
        // modelo Alumno) — un DNI de un legajo dado de baja también
        // cuenta como "ya existe" acá, mismo criterio que
        // `IngresantesController`/`AlumnosController`.
        if (Alumno::withTrashed()->where('dni', $dni)->exists()) {
            $this->salteada($numeroFila, "Ya existe un alumno con DNI {$dni}.");

            return;
        }

        if ($nivelNumero === null || $nivelNumero === '') {
            $this->salteada($numeroFila, 'Falta el nivel (año).');

            return;
        }

        $nivel = Nivel::where('numero_orden', (int) $nivelNumero)->first();
        if ($nivel === null) {
            $this->salteada($numeroFila, "No existe un nivel con número {$nivelNumero}.");

            return;
        }

        if ($divisionNombre === '') {
            $this->salteada($numeroFila, 'Falta la división.');

            return;
        }

        $division = Division::whereRaw('LOWER(nombre) = ?', [mb_strtolower($divisionNombre)])->first();
        if ($division === null) {
            $this->salteada($numeroFila, "No existe la división \"{$divisionNombre}\".");

            return;
        }

        $curso = Curso::where('nivel_id', $nivel->id_nivel)
            ->where('division_id', $division->id_division)
            ->where('ciclo_lectivo_id', $this->cicloLectivoId)
            ->first();

        if ($curso === null) {
            $this->salteada($numeroFila, "No existe el curso {$nivel->nombre} {$division->nombre} en el ciclo lectivo abierto.");

            return;
        }

        $fechaNacimiento = $this->parsearFecha($fila['fecha_nacimiento'] ?? null);
        $fechaIngreso = $this->parsearFecha($fila['fecha_ingreso'] ?? null);

        if ($fechaIngreso === null) {
            $this->salteada($numeroFila, 'Falta la fecha de ingreso, o no tiene un formato de fecha válido.');

            return;
        }

        DB::transaction(function () use ($nombre, $apellido, $dni, $fechaNacimiento, $fechaIngreso, $curso) {
            $alumno = Alumno::create([
                'nombre' => $nombre,
                'apellido' => $apellido,
                'dni' => $dni,
                'fecha_nacimiento' => $fechaNacimiento,
                'fecha_ingreso_institucion' => $fechaIngreso,
            ]);

            Inscripcion::create([
                'alumno_id' => $alumno->id_alumno,
                'curso_id' => $curso->id_curso,
                'ciclo_lectivo_id' => $curso->ciclo_lectivo_id,
                'especialidad_id' => null,
                'condicion' => 'regular',
                'estado' => 'activo',
            ]);
        });

        $this->resultados[] = [
            'fila' => $numeroFila,
            'estado' => 'creado',
            'motivo' => null,
            'alumno' => "{$apellido}, {$nombre} (DNI {$dni})",
        ];
    }

    private function salteada(int $numeroFila, string $motivo): void
    {
        $this->resultados[] = [
            'fila' => $numeroFila,
            'estado' => 'salteado',
            'motivo' => $motivo,
            'alumno' => null,
        ];
    }

    /**
     * Excel guarda una fecha como número de serie (días desde
     * 1899-12-30) cuando la celda tiene formato de fecha — sin esta
     * conversión, una fecha de nacimiento cargada normal en Excel llega
     * acá como, por ejemplo, `40269` en vez de una fecha. Si la celda es
     * texto libre (alguien tipeó "15/03/2010" a mano en una celda de
     * texto), se intenta interpretar igual con `Carbon::parse`. Cualquier
     * valor que no se pueda interpretar de ninguna de las dos formas
     * devuelve `null` en vez de romper la fila entera.
     */
    private function parsearFecha(mixed $valor): ?string
    {
        if ($valor === null || $valor === '') {
            return null;
        }

        if (is_numeric($valor)) {
            try {
                return FechaExcel::excelToDateTimeObject((float) $valor)->format('Y-m-d');
            } catch (\Throwable) {
                return null;
            }
        }

        try {
            return Carbon::parse((string) $valor)->format('Y-m-d');
        } catch (\Throwable) {
            return null;
        }
    }
}
