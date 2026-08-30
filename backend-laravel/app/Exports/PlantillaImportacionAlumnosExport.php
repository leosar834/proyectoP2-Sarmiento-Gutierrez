<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;

/**
 * Plantilla vacía (con dos filas de ejemplo) para la importación masiva
 * de alumnos — ver `AlumnosImport`. Los encabezados acá tienen que
 * coincidir EXACTO con lo que `AlumnosImport` espera después de pasar
 * por `Str::slug()` (heading "Nivel" -> clave `nivel`, etc.) — si se
 * renombra una columna acá, hay que actualizar `AlumnosImport` en el
 * mismo cambio.
 *
 * Las dos filas de ejemplo no son datos reales — están para que quede
 * claro de un vistazo el formato esperado de cada columna (fechas en
 * AAAA-MM-DD, nivel como número de 1 a 6 según `numero_orden`, no el
 * nombre del año). Quien complete la plantilla las borra antes de
 * subir el archivo; si no las borra, la fila con DNI "00000000" no va
 * a encontrar ese nivel/división en una instalación real y
 * simplemente se va a saltear con su motivo, sin romper el resto.
 */
class PlantillaImportacionAlumnosExport implements FromArray, WithHeadings, ShouldAutoSize
{
    public function array(): array
    {
        return [
            ['Juan', 'Pérez', '30111222', '2010-03-15', '2022-03-01', 1, 'A'],
            ['Ejemplo', 'Borrar esta fila', '00000000', '2009-07-20', '2022-03-01', 1, 'A'],
        ];
    }

    public function headings(): array
    {
        return [
            'Nombre',
            'Apellido',
            'DNI',
            'Fecha nacimiento',
            'Fecha ingreso',
            'Nivel',
            'Division',
        ];
    }
}
