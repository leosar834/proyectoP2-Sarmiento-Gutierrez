<?php

use App\Models\Usuario;

return [

    /*
    |--------------------------------------------------------------------------
    | Authentication Defaults
    |--------------------------------------------------------------------------
    */

    'defaults' => [
        'guard' => env('AUTH_GUARD', 'web'),
        'passwords' => env('AUTH_PASSWORD_BROKER', 'usuarios'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Authentication Guards
    |--------------------------------------------------------------------------
    |
    | El guard `web` (sesión) queda para el propio Laravel (p. ej. si algún
    | día se arma un panel server-rendered) pero no lo usa ningún cliente
    | real: tanto la app Flutter como la Flutter web del administrador
    | autentican por token contra el guard `sanctum`, pegándole al mismo
    | modelo Usuario. `provider => null` es correcto acá: Sanctum resuelve
    | el usuario del token directamente vía la relación polimórfica de
    | `personal_access_tokens` (tokenable_type/tokenable_id), no a través
    | de un provider de este array.
    |
    */

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'usuarios',
        ],

        'sanctum' => [
            'driver' => 'sanctum',
            'provider' => null,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | User Providers
    |--------------------------------------------------------------------------
    |
    | El sistema no tiene tabla `users`: todo usuario que opera el sistema
    | (preceptor, profesor, administrador...) es una fila de `usuarios`
    | (ver database/sql/schema.sql y App\Models\Usuario).
    |
    */

    'providers' => [
        'usuarios' => [
            'driver' => 'eloquent',
            'model' => env('AUTH_MODEL', Usuario::class),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Resetting Passwords
    |--------------------------------------------------------------------------
    |
    | Sin flujo de autoservicio de "olvidé mi contraseña": las altas, bajas
    | y contraseñas de usuarios las gestiona jefa de preceptores /
    | administrador desde la web (RF1), no el propio usuario. Por eso
    | database/sql/schema.sql no trae `password_reset_tokens` y este
    | bloque queda vacío. Si más adelante se pide autoservicio de
    | contraseña, hay que sumar esa tabla y completar este array.
    |
    */

    'passwords' => [],

    'password_timeout' => env('AUTH_PASSWORD_TIMEOUT', 10800),

];
