<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DetalleAsistenciaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id_detalle' => $this->id_detalle,
            'inscripcion_id' => $this->inscripcion_id,
            'alumno' => $this->whenLoaded('inscripcion', fn () => [
                'id_alumno' => $this->inscripcion->alumno->id_alumno,
                'nombre' => $this->inscripcion->alumno->nombre,
                'apellido' => $this->inscripcion->alumno->apellido,
                'dni' => $this->inscripcion->alumno->dni,
            ]),
            'estado' => $this->estado,
            'hora_registro' => $this->hora_registro,
            'observaciones' => $this->observaciones,
        ];
    }
}
