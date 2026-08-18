<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstitucionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'nombre' => $this->nombre,
            'domicilio' => $this->domicilio,
            'cue' => $this->cue,
            'localidad' => $this->localidad,
            'provincia' => $this->provincia,
            'modalidad' => $this->modalidad,
        ];
    }
}
