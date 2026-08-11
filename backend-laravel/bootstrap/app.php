<?php

use App\Http\Middleware\VerificarPermiso;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'permiso' => VerificarPermiso::class,
        ]);

        // Este backend es 100% API (no hay vistas ni ruta 'login' web). Sin
        // esto, Laravel intenta redirigir a `route('login')` cuando el
        // cliente no manda "Accept: application/json" (la mayoría de los
        // clientes HTTP, incluido el paquete http/dio de Flutter, no lo
        // mandan por defecto) y como esa ruta no existe, revienta con un 500
        // "Route [login] not defined" en vez de devolver un 401 limpio.
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );

        // Refuerzo del fix de arriba: el manejador por defecto de
        // AuthenticationException también cae en `route('login')` como
        // fallback cuando expectsJson() da false. Para /api/* siempre
        // devolvemos JSON acá directamente, sin pasar por esa rama.
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'No autenticado.'], 401);
            }
        });
    })->create();
