<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Auth\RegistroAdministradorRequest;
use App\Http\Resources\UsuarioResource;
use App\Models\Institucion;
use App\Models\Rol;
use App\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Alta pública del primer administrador del sistema (pantalla de login
 * de escritorio, boceto "Registro del Administrador"). No sustituye a
 * `UsuariosController::crear()` — ese sigue siendo el alta normal, hecha
 * por un administrador ya logueado (`permiso:gestionar_sistema`). Este
 * endpoint es exclusivamente la salida de emergencia para el instante
 * "todavía no hay NADIE con quien loguearse": sin auth, y por eso
 * bloqueado con la guarda más estricta posible.
 *
 * `DatabaseSeeder` ya crea un usuario administrador de prueba
 * (`admin@sistema-asistencia.test` / `password`) junto con los 8 roles
 * de la EETN.° 1 — ese dato sirve para desarrollo, pero no es
 * apropiado dejarlo en una instalación real. Este endpoint es la forma
 * de que la institución cargue sus propias credenciales sin depender de
 * `php artisan tinker`, PERO solo tiene sentido correr los seeders de
 * catálogo (permisos + roles) sin la fila de usuario de prueba — ver
 * nota de guarda de roles más abajo.
 *
 * Además de la cuenta, este mismo alta crea la ficha de la institución
 * (tabla `institucion`, ver App\Models\Institucion) con los datos que
 * llegan anidados en `institucion.*` — así el establecimiento queda
 * identificado (nombre, domicilio, CUE, localidad, provincia) desde el
 * primer momento, sin necesidad de un paso de alta de institución
 * separado. Después de esta única creación, se edita desde
 * `InstitucionController::actualizar()`.
 */
class RegistroAdministradorController extends Controller
{
    public function crear(RegistroAdministradorRequest $request): JsonResponse
    {
        // Guarda de "primera vez": una vez que existió CUALQUIER usuario
        // (incluso borrado — `withTrashed()`), esta puerta se cierra para
        // siempre. Es pública y sin permiso, así que no puede depender de
        // nada más blando que "el sistema nunca tuvo usuarios" — de lo
        // contrario, cualquiera podría autopromoverse a administrador
        // más adelante.
        if (Usuario::withTrashed()->exists()) {
            throw ValidationException::withMessages([
                'email' => ['El sistema ya tiene usuarios configurados. Iniciá sesión o pedile a un administrador que te dé de alta.'],
            ]);
        }

        $rolAdministrador = Rol::where('nombre', 'administrador_sistema')->first();

        if ($rolAdministrador === null) {
            // No debería pasar en una instalación normal — el rol viene
            // del seeder de catálogo, que es infraestructura, no algo
            // que arma un usuario final. Si falta, el problema real es
            // que faltó correr `php artisan db:seed` (o el seeder de
            // catálogo específico), no algo que este formulario pueda
            // resolver por su cuenta.
            throw ValidationException::withMessages([
                'email' => ['Falta la configuración inicial del sistema (roles y permisos) — contactá a soporte técnico antes de continuar.'],
            ]);
        }

        $usuario = DB::transaction(function () use ($request, $rolAdministrador) {
            $usuario = Usuario::create([
                'nombre' => $request->validated('nombre'),
                'apellido' => $request->validated('apellido'),
                'email' => $request->validated('email'),
                'password' => $request->validated('password'),
                'activo' => true,
            ]);

            $usuario->roles()->attach($rolAdministrador->id_rol);

            // Fila única de `institucion` (id fijo 1 — ver el docblock
            // de App\Models\Institucion). Va en la misma transacción que
            // el alta del administrador: si algo falla acá, tampoco
            // queda un administrador sin institución cargada.
            Institucion::create([
                'id_institucion' => 1,
                'nombre' => $request->validated('institucion.nombre'),
                'domicilio' => $request->validated('institucion.domicilio'),
                'cue' => $request->validated('institucion.cue'),
                'localidad' => $request->validated('institucion.localidad'),
                'provincia' => $request->validated('institucion.provincia'),
            ]);

            return $usuario;
        });

        // Igual que AuthController::login(): se devuelve token +
        // usuario ya armados, para que el cliente pueda quedar logueado
        // de una sin pedirle que vuelva a escribir sus credenciales.
        // Siempre 'escritorio' — este formulario solo existe en esa
        // plataforma (ver el enlace condicional en el login de Flutter).
        $token = $usuario->createToken(
            $request->userAgent() ?? 'token',
            ['plataforma:escritorio']
        );

        return response()->json([
            'token' => $token->plainTextToken,
            'plataforma' => 'escritorio',
            'usuario' => new UsuarioResource($usuario->load('roles')),
        ], 201);
    }
}
