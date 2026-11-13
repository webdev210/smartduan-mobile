// Uses the platform interface already installed by webview_flutter.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/config.dart';
import 'package:smartduan/screens/app/basket.dart';
import 'package:smartduan/screens/app/share_routes.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../ui/detail_webview_fake.dart';
import 'task_h_fakes.dart';

class BasketPlatform extends DetailWebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = BasketController(params);
    controllers.add(controller);
    return controller;
  }

  BasketController get last => controllers.last as BasketController;
}

class BasketController extends DetailWebController {
  BasketController(super.params);
  late JavaScriptChannelParams bridge;
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    bridge = params;
  }

  void message(Object value) =>
      bridge.onMessageReceived(JavaScriptMessage(message: jsonEncode(value)));
}

void main() {
  late BasketPlatform platform;
  setUp(() {
    platform = BasketPlatform();
    WebViewPlatform.instance = platform;
  });

  Future<(HEnv, GoRouter)> mount(WidgetTester tester, {Reply? reply}) async {
    final env = HEnv();
    var minted = 0;
    env.http.respond = (r) => r.path == '/auth/basket-token'
        ? reply ?? Reply(200, {'token': 'secret-${++minted}'})
        : hReply(r.path);
    final router = await env.mount(
      tester,
      const BasketScreen(projectId: 'p', url: 'https://ro-hang.smartland.vn/'),
      settle: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (env, router);
  }

  testWidgets('loads parent HTML with bridge and waits for ready', (
    tester,
  ) async {
    final (env, _) = await mount(tester);
    expect(platform.last.baseUrl, webUrl);
    expect(platform.last.html, contains('<iframe'));
    expect(platform.last.html, contains('#sd_token=secret-1'));
    expect(platform.last.bridge.name, 'ReactNativeWebView');
    expect(platform.last.javascript, JavaScriptMode.unrestricted);
    expect(
      appShareScreens.keys,
      containsAll([
        '/ro-hang',
        '/trinh-chieu/:projectId',
        '/chia-se/:projectId',
      ]),
    );
    expect(env.http.seen.single.data, {'project_id': 'p', 'presenting': false});
    platform.last.navigation!.finished?.call(webUrl);
    await tester.pump();
    expect(find.text('Đang kết nối rổ hàng…'), findsOneWidget);
    platform.last.message({'type': 'sd:ready'});
    await tester.pump();
    expect(find.text('Đang kết nối rổ hàng…'), findsNothing);
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('timeout retry mints a new token and ignores old bridge', (
    tester,
  ) async {
    final (env, _) = await mount(tester);
    final old = platform.last;
    await tester.pump(const Duration(seconds: 15));
    expect(
      find.text('Không nhúng được rổ hàng. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.http.seen.length, 2);
    expect(platform.last.html, contains('secret-2'));
    expect(platform.last.html, isNot(old.html));
    old.message({'type': 'sd:ready'});
    await tester.pump();
    expect(find.text('Đang kết nối rổ hàng…'), findsOneWidget);
    platform.last.message({'type': 'sd:ready'});
    await tester.pump();
  });

  for (final entry in {
    403: 'Bạn không có quyền xem rổ hàng này',
    404: 'Không tìm thấy rổ hàng hoặc tính năng đã tắt',
    409: 'Dự án chưa cấu hình rổ hàng',
  }.entries) {
    testWidgets('mint ${entry.key} has exact text and no retry', (
      tester,
    ) async {
      final (env, _) = await mount(tester, reply: Reply(entry.key));
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(platform.controllers, isEmpty);
      expect(env.http.seen.length, 1);
    });
  }

  testWidgets('other mint errors are manually retryable, never auto-retried', (
    tester,
  ) async {
    final (env, _) = await mount(tester, reply: const Reply(503));
    await tester.pump(const Duration(seconds: 30));
    expect(env.http.seen.length, 1);
    await tester.tap(find.text('Thử lại'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.http.seen.length, 2);
  });

  for (final message in ['', 'Phiên đã hết hạn', 'secret-1']) {
    testWidgets('bridge error handles message "$message" safely', (
      tester,
    ) async {
      await mount(tester);
      platform.last.message({'type': 'sd:error', 'message': message});
      await tester.pump();
      expect(
        find.text(
          message.isEmpty || message == 'secret-1'
              ? 'Rổ hàng từ chối phiên đăng nhập'
              : message,
        ),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('secret-1'), findsNothing);
      await tester.pump(const Duration(seconds: 16));
      expect(
        find.text('Không nhúng được rổ hàng. Kiểm tra mạng rồi thử lại.'),
        findsNothing,
      );
    });
  }

  testWidgets('invalid bridge JSON ignored; WebView error is retryable', (
    tester,
  ) async {
    await mount(tester);
    platform.last.bridge.onMessageReceived(
      const JavaScriptMessage(message: 'invalid'),
    );
    await tester.pump();
    expect(find.text('Đang kết nối rổ hàng…'), findsOneWidget);
    platform.last.navigation!.error!(
      WebResourceError(
        errorCode: -1,
        description: 'secret-1',
        isForMainFrame: true,
      ),
    );
    await tester.pump();
    expect(
      find.text('Không tải được rổ hàng. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret-1'), findsNothing);
  });

  testWidgets(
    'navigation allows frames, blocks schemes, opens external link in app',
    (tester) async {
      final (_, router) = await mount(tester);
      final nav = platform.last.navigation!;
      expect(
        await nav.navigate('https://example.vn/#sd_token=secret-1'),
        NavigationDecision.prevent,
      );
      expect(router.state.uri.path, '/');
      for (final url in ['about:blank', webUrl]) {
        expect(await nav.navigate(url), NavigationDecision.navigate);
      }
      expect(
        await nav.navigate('https://example.vn/frame', false),
        NavigationDecision.navigate,
      );
      for (final url in [
        'intent://x#Intent;end',
        'file:///secret',
        'content://secret',
        'javascript:alert(1)',
      ]) {
        expect(await nav.navigate(url), NavigationDecision.prevent);
        expect(await nav.navigate(url, false), NavigationDecision.prevent);
        expect(router.state.uri.path, '/');
      }
      expect(
        await nav.navigate('https://example.vn/link'),
        NavigationDecision.prevent,
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/xem');
      expect(
        router.state.uri.queryParameters['url'],
        'https://example.vn/link',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('invalid route does not mint', (tester) async {
    final env = HEnv();
    await env.mount(
      tester,
      const BasketScreen(projectId: 'p', url: 'file:///x'),
    );
    expect(find.text('Link rổ hàng không hợp lệ.'), findsOneWidget);
    expect(env.http.seen, isEmpty);
  });

  testWidgets('bottom safe area is preserved and session end drops the frame', (
    tester,
  ) async {
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetViewPadding);
    final (env, _) = await mount(tester);
    platform.last.message({'type': 'sd:ready'});
    await tester.pump();
    final padding = tester.widgetList<Padding>(find.byType(Padding));
    expect(
      padding.any((p) => p.padding == const EdgeInsets.only(bottom: 34)),
      isTrue,
    );
    final old = platform.last;
    env.session.endSession();
    await tester.pump();
    old.message({'type': 'sd:error', 'message': 'Old account'});
    await tester.pump();
    expect(find.text('Old account'), findsNothing);
    expect(find.text('Đang kết nối rổ hàng…'), findsNothing);
    expect(env.http.seen.length, 1);
  });

  testWidgets('missing token is an error, not an embedded empty credential', (
    tester,
  ) async {
    await mount(tester, reply: const Reply(200));
    expect(platform.controllers, isEmpty);
    expect(find.text('Có lỗi xảy ra, thử lại sau'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets(
    'system back swallowed; explicit back works; reopen mints again',
    (tester) async {
      final env = HEnv();
      env.http.respond = (_) => const Reply(200, {'token': 'fresh'});
      final router = await env.mount(
        tester,
        const Scaffold(body: Text('Home')),
      );
      router.push('/ro-hang');
      await tester.pumpAndSettle();
      // Use the real screen on an imperative full-screen route, as the registry does.
      final context = tester.element(find.byType(Scaffold).last);
      final navigator = Navigator.of(context);
      void open() => navigator.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const BasketScreen(
            projectId: 'p',
            url: 'https://ro-hang.smartland.vn/',
          ),
        ),
      );
      open();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        ModalRoute.of(tester.element(find.byType(BasketScreen)))!
            .fullscreenDialog,
        isTrue,
      );
      expect(await navigator.maybePop(), isTrue);
      await tester.pump();
      expect(find.byType(BasketScreen), findsOneWidget);
      platform.last.message({'type': 'sd:ready'});
      await tester.pump();
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(BasketScreen), findsNothing);
      open();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(env.http.seen.length, 2);
      platform.last.message({'type': 'sd:ready'});
      await tester.pump();
    },
  );
}
