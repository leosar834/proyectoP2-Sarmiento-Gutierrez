<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UsuarioResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id_usuario' => $this->id_usuario,
            'nombre' => $this->nombre,
            'apellido' => $this->apellido,
            'email' => $this->email,
            'activo' => $this->activo,
            'roles' => $this->whenLoaded('roles', fn () => $this->roles->pluck('nombre')),
        ];
    }
}
