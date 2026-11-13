// ignore_for_file: depend_on_referenced_packages
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:smartduan/ui/tour360.dart';

import 'detail_webview_fake.dart';

const tour = 'https://360.smartrealtors.vn/share/collection/7H1b3';
void main() {
  late DetailWebViewPlatform platform;
  setUp(() {
    platform = DetailWebViewPlatform();
    WebViewPlatform.instance = platform;
  });
  testWidgets('tour is lazy, plays inline, and closes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Tour360(url: tour, name: 'Charmora City', cover: null),
          ),
        ),
      ),
    );
    expect(platform.controllers, isEmpty);
    expect(find.byIcon(Ionicons.play), findsOneWidget);
    expect(find.byIcon(Ionicons.close), findsNothing);
    await tester.tap(find.bySemanticsLabel('Xem tour 360° Charmora City'));
    await tester.pump();
    await tester.pump();
    expect(platform.controllers.single.loaded, [tour]);
    expect(find.byIcon(Ionicons.play), findsNothing);
    expect(find.byIcon(Ionicons.close), findsOneWidget);
    expect(find.byIcon(Ionicons.expandOutline), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Đóng tour 360°'));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Xem tour 360° Charmora City'),
      findsOneWidget,
    );
  });
  for (final external in [false, true]) {
    testWidgets(
      external
          ? 'untrusted tour opens viewer without embedding'
          : 'fullscreen stays inside app',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Tour360(
                  url: external ? 'https://kuula.co/share/x' : tour,
                  name: 'X',
                  cover: null,
                ),
              ),
            ),
            GoRoute(
              path: '/xem',
              builder: (_, s) => Text(s.uri.queryParameters['url']!),
            ),
            GoRoute(
              path: '/tour-360',
              builder: (_, s) => Text(s.uri.queryParameters['url']!),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        expect(find.byIcon(Ionicons.cubeOutline), findsOneWidget);
        await tester.tap(
          external
              ? find.text('Xem tour 360°')
              : find.bySemanticsLabel('Xem tour 360° toàn màn hình'),
        );
        await tester.pumpAndSettle();
        expect(router.state.uri.path, external ? '/xem' : '/tour-360');
        expect(platform.controllers, isEmpty);
      },
    );
  }
}
