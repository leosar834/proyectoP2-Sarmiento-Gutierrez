<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Ficha de identificación de la (única) institución que corre este
 * sistema — tabla `institucion`, fila única (`id_institucion` siempre
 * 1; mismo patrón que `configuraciones`: `CHECK` a nivel de base impide
 * una segunda fila). No es un parámetro de comportamiento del sistema,
 * es simplemente el dato con el que el administrador identifica el
 * establecimiento que está gestionando: nombre, domicilio, CUE (Clave
 * Única de Establecimiento) y ubicación — pensado para mostrarse en el
 * panel de administración y en reportes/planillas impresas.
 *
 * Se crea una única vez, junto con el primer administrador, dentro de
 * la misma transacción de `RegistroAdministradorController::crear()` —
 * por eso el sistema pide estos datos ahí mismo en vez de en un paso de
 * alta de institución separado (ya descartado explícitamente: el
 * sistema no soporta multi-institución). Después de esa alta inicial,
 * la fila se EDITA — nunca se vuelve a crear — desde
 * `InstitucionController::actualizar()` (`permiso:gestionar_sistema`).
 *
 * `$incrementing = false`: `id_institucion` no es AUTO_INCREMENT en la
 * base (tiene `DEFAULT 1` + `CHECK id_institucion = 1`), así que
 * Eloquent no debe intentar resolverlo con `LAST_INSERT_ID()` después
 * del insert — se fija explícitamente en 1 al crearla (ver
 * `RegistroAdministradorController::crear()`).
 */
class Institucion extends Model
{
    protected $table = 'institucion';

    protected $primaryKey = 'id_institucion';

    public $incrementing = false;

    protected $keyType = 'int';

    protected $fillable = [
        'id_institucion',
        'nombre',
        'domicilio',
        'cue',
        'localidad',
        'provincia',
    ];
}
