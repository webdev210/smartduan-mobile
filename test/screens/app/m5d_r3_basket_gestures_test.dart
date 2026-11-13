// Uses the platform interface already installed by webview_flutter.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/screens/app/basket.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'basket_test.dart' show BasketPlatform;
import 'task_h_fakes.dart';

void main() {
  for (final target in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$target basket swipes and system back stay; toolbar exits', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = target;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final platform = BasketPlatform();
      WebViewPlatform.instance = platform;
      final env = HEnv();
      env.http.respond = (_) => const Reply(200, {'token': 'fixture'});
      await env.mount(tester, const Scaffold(body: Text('Home')));
      final navigator = Navigator.of(tester.element(find.text('Home')));
      final route = MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const BasketScreen(
          projectId: 'p',
          url: 'https://ro-hang.smartland.vn/',
        ),
      );
      navigator.push(route);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      platform.last.message({'type': 'sd:ready'});
      await tester.pump();
      expect(route.popGestureEnabled, isFalse);
      await tester.dragFrom(
        tester.getCenter(find.byType(WebViewWidget)),
        const Offset(280, 0),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(1, 200), const Offset(280, 0));
      await tester.pumpAndSettle();
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(BasketScreen), findsOneWidget);
      final back = find.byTooltip('Quay lại');
      expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(BasketScreen), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  }
}
