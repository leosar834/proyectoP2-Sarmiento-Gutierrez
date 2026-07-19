<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PlanillaAsistenciaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id_planilla' => $this->id_planilla,
            'area' => $this->area,
            'grupo' => $this->nombreGrupo(),
            'fecha' => $this->fecha->toDateString(),
            'estado' => $this->estado,
            'hora_confirmacion' => $this->hora_confirmacion,
            'detalles' => DetalleAsistenciaResource::collection($this->whenLoaded('detalles')),
        ];
    }

    /**
     * Etiqueta legible del curso/grupo real de la planilla, cualquiera
     * sea el área — evita que el cliente tenga que saber a qué columna
     * mirar según `area`.
     */
    private function nombreGrupo(): ?string
    {
        $grupo = $this->grupo();

        return match (true) {
            $grupo instanceof \App\Models\Curso => "{$grupo->nivel->nombre} {$grupo->division->nombre} ({$grupo->turno})",
            $grupo instanceof \App\Models\GrupoTaller => "{$grupo->materiaTaller->nombre} — {$grupo->nombre_grupo}",
            $grupo instanceof \App\Models\GrupoEdFisica => $grupo->nombre_grupo,
            default => null,
        };
    }
}
