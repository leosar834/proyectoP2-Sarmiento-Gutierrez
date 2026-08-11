<?php

namespace Database\Seeders;

use App\Models\Rol;
use App\Models\Usuario;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

/**
 * Bootstrap de DESARROLLO: el catálogo institucional (ver
 * `CatalogoSeeder` — permisos + los 8 roles de la EETN.° 1) más un
 * usuario administrador de prueba, para no tener que pasar por el
 * registro público cada vez que se resetea la base mientras se
 * desarrolla.
 *
 * En una instalación real NO correspondería este seeder tal cual —
 * `CatalogoSeeder` solo (sin usuario de prueba) es lo que hace falta:
 * el administrador real se da de alta desde la pantalla de login
 * ("Registrá la primera cuenta de administrador acá" →
 * `POST /registro-administrador`), no queda un usuario/contraseña
 * hardcodeado (`admin@sistema-asistencia.test` / `password`) dando
 * vueltas en producción.
 */
class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $this->call(CatalogoSeeder::class);
        $this->seedUsuarioDePrueba();
    }

    private function seedUsuarioDePrueba(): void
    {
        $administrador = Rol::where('nombre', 'administrador_sistema')->firstOrFail();

        $usuario = Usuario::create([
            'nombre' => 'Admin',
            'apellido' => 'Sistema',
            'email' => 'admin@sistema-asistencia.test',
            'password' => 'password',
            'activo' => true,
        ]);

        $usuario->roles()->attach($administrador->id_rol);
    }
}
