// ignore_for_file: depend_on_referenced_packages
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:smartduan/screens/public/tour_360.dart';

import '../../ui/detail_webview_fake.dart';

void main() {
  testWidgets('fullscreen close clears Dynamic Island and returns to project', (
    tester,
  ) async {
    final platform = DetailWebViewPlatform();
    WebViewPlatform.instance = platform;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Project')),
        GoRoute(
          path: '/tour-360',
          builder: (_, _) => const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: 59, bottom: 34)),
            child: Tour360Screen(
              url: 'https://360.smartrealtors.vn/share/collection/7H1b3',
              name: 'Charmora City',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/tour-360');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final close = find.bySemanticsLabel('Đóng tour 360°');
    expect(tester.getTopLeft(close).dy, greaterThanOrEqualTo(59));
    expect(platform.controllers.single.loaded, [
      'https://360.smartrealtors.vn/share/collection/7H1b3',
    ]);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Project'), findsOneWidget);
  });
  testWidgets(
    'invalid fullscreen deep link never creates a WebView and close goes home',
    (tester) async {
      final platform = DetailWebViewPlatform();
      WebViewPlatform.instance = platform;
      final router = GoRouter(
        initialLocation: '/tour-360',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('Home')),
          GoRoute(
            path: '/tour-360',
            builder: (_, _) => const Tour360Screen(url: 'https://evil.vn/'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(platform.controllers, isEmpty);
      await tester.tap(find.bySemanticsLabel('Đóng tour 360°'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );
}
