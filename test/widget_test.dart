import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/main.dart';
import 'package:smartduan/ui/brand_splash.dart';

import 'router_test.dart' show FakeSession;

import 'package:smartduan/auth/session.dart';

void main() {
  testWidgets('shows branded splash with a light theme on a dark platform', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(
            () => FakeSession(SessionStatus.loading),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(BrandSplash), findsOneWidget);
    expect(find.text('Smart Dự Án'), findsOneWidget);
    expect(find.text('SMARTLAND'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Smart Dự Án');
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme, isNull);
    final context = tester.element(find.byType(BrandSplash));
    expect(
      DefaultTextHeightBehavior.of(context).leadingDistribution,
      TextLeadingDistribution.even,
    );
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFFF7F7F7));
    final spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(
      tester.widget<CircularProgressIndicator>(spinner).color,
      const Color(0xFFE6C28F),
    );
    expect(tester.getSize(spinner), const Size(16, 16));
    expect(find.image(const AssetImage('assets/splash.webp')), findsOneWidget);
    expect(
      tester.getCenter(spinner).dx,
      tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
    );
    expect(tester.takeException(), isNull);
  });
}
