<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AlertaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id_alerta' => $this->id_alerta,
            'tipo' => $this->tipo,
            'fecha_generacion' => $this->fecha_generacion,
            'detalle' => $this->detalle,
            'estado' => $this->estado,
            'alumno' => $this->whenLoaded('inscripcion', fn () => [
                'id_alumno' => $this->inscripcion->alumno->id_alumno,
                'nombre' => $this->inscripcion->alumno->nombre,
                'apellido' => $this->inscripcion->alumno->apellido,
                'dni' => $this->inscripcion->alumno->dni,
                'curso' => "{$this->inscripcion->curso->nivel->nombre} {$this->inscripcion->curso->division->nombre}",
            ]),
        ];
    }
}
