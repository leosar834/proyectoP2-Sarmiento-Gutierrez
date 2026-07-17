<?php

use Laravel\Sanctum\Sanctum;

return [

    /*
    |--------------------------------------------------------------------------
    | Stateful Domains
    |--------------------------------------------------------------------------
    |
    | No se usa: este apunte NO hace login por cookie/sesión de SPA
    | (EnsureFrontendRequestsAreStateful no está en ningún grupo de
    | middleware). Tanto la app Flutter como la Flutter web autentican
    | mandando "Authorization: Bearer <token>" en cada request, que
    | funciona igual sin importar el origen — evita tener que mantener
    | esta lista de dominios sincronizada entre entornos de desarrollo,
    | staging y cada institución con su propio dominio de despliegue.
    | Se deja el default de Sanctum sin tocar por si algún día hiciera
    | falta.
    |
    */

    'stateful' => explode(',', (string) env('SANCTUM_STATEFUL_DOMAINS', sprintf(
        '%s%s',
        'localhost,localhost:3000,127.0.0.1,127.0.0.1:8000,::1',
        Sanctum::currentApplicationUrlWithPort()
    ))),

    'guard' => ['web'],

    /*
    |--------------------------------------------------------------------------
    | Expiration Minutes
    |--------------------------------------------------------------------------
    |
    | 14 días. Un dispositivo de un preceptor/profesor puede perderse o
    | cambiar de manos; sin expiración, un token robado queda válido para
    | siempre hasta que alguien lo revoque a mano. Con este valor, en el
    | peor caso el token deja de servir solo con el paso del tiempo. Ajustar
    | si 14 días resulta muy corto para el uso real (forzaría reloguear
    | seguido) o muy largo.
    |
    */

    'expiration' => 60 * 24 * 14,

    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),

    'middleware' => [
        'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
        'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
        'validate_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
    ],

];
