// Smoke test básico de arranque de la app.
//
// El stub que genera `flutter create` prueba un contador que nunca
// existió acá (referenciaba `MyApp`, una clase que no existe en este
// proyecto — la raíz real es `AsistenciaApp`, ver lib/main.dart). Este
// test lo reemplaza por algo mínimo pero real: que la app arranca sin
// tirar una excepción y que, antes de que `AuthProvider` resuelva si hay
// sesión guardada (`AuthStatus.desconocido`), se ve el loading inicial
// (`CircularProgressIndicator` dentro de `SplashScreen`).
//
// A propósito NO se usa `tester.pumpAndSettle()`: `AuthProvider` dispara
// una petición HTTP real post-frame (`cargarSesionGuardada`), y en el
// entorno de test no hay backend — `pumpAndSettle` se quedaría esperando
// esa petición. Un solo `pump()` alcanza para ver el estado inicial.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_flutter/main.dart';

void main() {
  testWidgets('La app arranca y muestra el loading inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const AsistenciaApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
