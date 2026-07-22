<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class JustificacionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id_justificacion' => $this->id_justificacion,
            'inscripcion_id' => $this->inscripcion_id,
            'alumno' => $this->whenLoaded('inscripcion', fn () => [
                'id_alumno' => $this->inscripcion->alumno->id_alumno,
                'nombre' => $this->inscripcion->alumno->nombre,
                'apellido' => $this->inscripcion->alumno->apellido,
                'dni' => $this->inscripcion->alumno->dni,
            ]),
            'fecha_inicio' => $this->fecha_inicio->toDateString(),
            'fecha_fin' => $this->fecha_fin->toDateString(),
            'tipo' => $this->tipo,
            'fecha_presentacion' => $this->fecha_presentacion->toDateString(),
            'area_receptora' => $this->area_receptora,
            'receptor' => $this->whenLoaded('usuarioReceptor', fn () => [
                'id_usuario' => $this->usuarioReceptor->id_usuario,
                'nombre' => $this->usuarioReceptor->nombre,
                'apellido' => $this->usuarioReceptor->apellido,
            ]),
            'estado_notificacion' => $this->estado_notificacion,
            'fecha_notificacion' => $this->fecha_notificacion,
        ];
    }
}
