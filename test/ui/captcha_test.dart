import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/captcha.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../screens/auth/fakes.dart';

void main() {
  late FakeWebViewPlatform platform;
  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  for (final mainFrame in [false, true, null]) {
    testWidgets('resource error with main-frame flag $mainFrame', (
      tester,
    ) async {
      final tokens = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Captcha(action: 'register', onToken: tokens.add),
        ),
      );
      await tester.pumpAndSettle();
      final c = platform.latest;
      c.message('{"type":"turnstile","token":"tok"}');
      await tester.pumpAndSettle();
      expect(tokens, ['tok']);
      c.delegate.error(
        WebResourceError(
          errorCode: -1,
          description: 'offline',
          isForMainFrame: mainFrame,
        ),
      );
      await tester.pumpAndSettle();
      expect(tokens, mainFrame == false ? ['tok'] : ['tok', null]);
      expect(
        find.text('Không tải được trang xác minh.'),
        mainFrame == false ? findsNothing : findsOneWidget,
      );
    });
  }

  for (final (url, status, fails) in <(String?, int, bool)>[
    ('https://smartduan.vn/favicon.ico', 404, false),
    ('https://challenges.cloudflare.com/asset.js', 404, false),
    ('https://smartduan.vn/xac-minh-app?action=forgot-password', 500, false),
    (null, 500, false),
    ('https://smartduan.vn/xac-minh-app?action=register', 500, true),
    ('https://smartduan.vn/xac-minh-app?action=register#challenge', 500, true),
  ]) {
    testWidgets('HTTP $status for $url only fails verification document', (
      tester,
    ) async {
      final tokens = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Captcha(action: 'register', onToken: tokens.add),
        ),
      );
      await tester.pumpAndSettle();
      final c = platform.latest;
      c.message('{"type":"turnstile","token":"tok"}');
      await tester.pumpAndSettle();
      expect(tokens, ['tok']);
      final uri = url == null ? null : Uri.parse(url);
      c.delegate.httpError(
        HttpResponseError(
          request: uri == null ? null : WebResourceRequest(uri: uri),
          response: WebResourceResponse(uri: uri, statusCode: status),
        ),
      );
      await tester.pumpAndSettle();
      expect(tokens, fails ? ['tok', null] : ['tok']);
      expect(
        find.text('Không tải được trang xác minh.'),
        fails ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('captcha delegate restricts top frame and subframes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Captcha(action: 'register', onToken: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    final c = platform.latest;
    expect(c.loads, ['https://smartduan.vn/xac-minh-app?action=register']);
    expect(c.javaScriptMode, JavaScriptMode.unrestricted);
    expect(c.zoom, false);
    for (final (url, top, expected) in [
      (
        'https://smartduan.vn/xac-minh-app?action=register',
        true,
        NavigationDecision.navigate,
      ),
      ('https://smartduan.vn/dang-nhap', true, NavigationDecision.prevent),
      ('intent://x', true, NavigationDecision.prevent),
      ('file:///secret', false, NavigationDecision.prevent),
      ('https://challenges.cloudflare.com', false, NavigationDecision.navigate),
      ('about:blank', false, NavigationDecision.navigate),
    ]) {
      expect(
        await c.delegate.navigate(
          NavigationRequest(url: url, isMainFrame: top),
        ),
        expected,
      );
    }
    expect(c.loads.length, 1);
  });
  testWidgets(
    'channel accepts page token, ignores wrong origin, clears errors and retries',
    (tester) async {
      final tokens = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Captcha(action: 'register', onToken: tokens.add),
        ),
      );
      await tester.pumpAndSettle();
      final c = platform.latest;
      expect(c.channel.name, 'ReactNativeWebView');
      c.url = 'https://evil.vn/';
      c.message('{"type":"turnstile","token":"wrong"}');
      await tester.pumpAndSettle();
      expect(tokens, isEmpty);
      c.url = c.loads.single;
      c.message('{"type":"turnstile","token":"tok"}');
      await tester.pumpAndSettle();
      expect(tokens, ['tok']);
      c.message('{"type":"turnstile-error"}');
      await tester.pumpAndSettle();
      expect(tokens, ['tok', null]);
      expect(find.text('Xác minh lỗi hoặc đã hết hạn.'), findsOneWidget);
      await tapText(tester, 'Xác minh lại');
      expect(platform.controllers.length, 2);
      c.message('{"type":"turnstile","token":"stale"}');
      await tester.pumpAndSettle();
      expect(tokens, ['tok', null]);
    },
  );
  testWidgets('load errors clear token and show retry', (tester) async {
    final tokens = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Captcha(action: 'forgot-password', onToken: tokens.add),
      ),
    );
    await tester.pumpAndSettle();
    platform.latest.delegate.error(
      const WebResourceError(
        errorCode: -1,
        description: 'offline',
        isForMainFrame: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tokens, [null]);
    expect(find.text('Không tải được trang xác minh.'), findsOneWidget);
    await tapText(tester, 'Xác minh lại');
    expect(platform.latest.loads.single, endsWith('action=forgot-password'));
  });
}
