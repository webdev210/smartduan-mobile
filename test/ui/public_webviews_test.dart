// ignore_for_file: depend_on_referenced_packages
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/screens/public/privacy_policy.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:smartduan/ui/map_embed.dart';
import 'package:smartduan/ui/tour_frame.dart';

import 'detail_webview_fake.dart';

void main() {
  late DetailWebViewPlatform platform;
  late List<String> launched;
  setUp(() {
    platform = DetailWebViewPlatform();
    WebViewPlatform.instance = platform;
    launched = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
  });
  Future<GoRouter> mount(WidgetTester tester, Widget child) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/xem',
          builder: (_, s) => Text(s.uri.queryParameters['url']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fetchFullPolicyProvider.overrideWith(
            (_) async => const FullPolicy(
              version: '1',
              body: '<p>x</p>',
              title: null,
              effectiveFrom: null,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    return router;
  }

  for (final kind in ['subresource', 'main', 'redirect', 'html']) {
    testWidgets('HTTP errors distinguish $kind documents and retry', (
      tester,
    ) async {
      const initial = 'https://example.vn/page#start';
      await mount(
        tester,
        PublicWebView(
          url: kind == 'html' ? null : initial,
          html: kind == 'html' ? '<p>Map</p>' : null,
          baseUrl: 'https://example.vn/page',
          title: 'Page',
          navigation: (url, top) =>
              url.startsWith('https:') ? 'allow' : 'block',
        ),
      );
      final nav = platform.controllers.single.navigation!;
      nav.finished!(initial);
      if (kind == 'redirect') {
        await nav.navigate('https://example.vn/next#section');
        await nav.navigate('https://example.vn/image', false);
        await nav.navigate('file:///blocked');
      }
      final url = switch (kind) {
        'subresource' => 'https://example.vn/favicon.ico',
        'redirect' => 'https://example.vn/next',
        _ => 'https://example.vn/page',
      };
      nav.httpError!(
        HttpResponseError(
          request: WebResourceRequest(uri: Uri.parse(url)),
          response: WebResourceResponse(
            uri: Uri.parse(url),
            statusCode: kind == 'subresource' ? 404 : 500,
          ),
        ),
      );
      await tester.pump();
      if (kind == 'subresource' || kind == 'html') {
        expect(find.text('Thử lại'), findsNothing);
        expect(find.bySemanticsLabel('Page'), findsOneWidget);
      } else {
        expect(
          find.text('Không tải được trang. Kiểm tra mạng rồi thử lại.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Thử lại'));
        await tester.pump();
        await tester.pump();
        expect(platform.controllers, hasLength(2));
        expect(platform.controllers.last.loaded, [initial]);
      }
    });
  }

  for (final kind in ['map', 'tour', 'privacy', 'viewer']) {
    testWidgets(
      '$kind blocks local/script URLs and sends tel to the launcher',
      (tester) async {
        await mount(tester, switch (kind) {
          'map' => const MapEmbed(
            lat: '10.7769',
            lng: '106.7009',
            name: 'Dự án A',
          ),
          'tour' => const TourFrame(
            url: 'https://360.smartrealtors.vn/share/collection/7H1b3',
            title: 'Tour',
          ),
          'privacy' => const PrivacyPolicyScreen(),
          _ => const ViewerScreen(
            url: 'https://dev.smartduan.vn/dang-ky',
            title: 'Đăng ký',
          ),
        });
        final controller = platform.controllers.single;
        final nav = controller.navigation!;
        for (final url in [
          'file:///secret',
          'content://secret',
          'javascript:alert(1)',
        ]) {
          expect(await nav.navigate(url), NavigationDecision.prevent);
          expect(controller.loaded, isNot(contains(url)));
        }
        expect(launched, isEmpty);
        expect(
          await nav.navigate('tel:0909123456'),
          NavigationDecision.prevent,
        );
        await tester.pump();
        expect(launched, ['tel:0909123456']);
        expect(
          controller.javascript,
          kind == 'privacy'
              ? JavaScriptMode.disabled
              : JavaScriptMode.unrestricted,
        );
      },
    );
  }
  testWidgets(
    'map loads iframe HTML and keeps subframes separate from top navigation',
    (tester) async {
      final router = await mount(
        tester,
        const MapEmbed(lat: '10.7769', lng: '106.7009', name: 'Dự án A'),
      );
      final c = platform.controllers.single;
      expect(c.loaded, isEmpty);
      expect(
        c.html,
        contains(
          'src="https://maps.google.com/maps?q=10.7769,106.7009&amp;z=16&amp;output=embed"',
        ),
      );
      expect(
        await c.navigation!.navigate(c.baseUrl!),
        NavigationDecision.navigate,
      );
      expect(
        await c.navigation!.navigate(
          'https://www.google.com/maps/embed?pb=x',
          false,
        ),
        NavigationDecision.navigate,
      );
      expect(
        await c.navigation!.navigate('intent://x#Intent;end', false),
        NavigationDecision.prevent,
      );
      expect(
        await c.navigation!.navigate('https://www.google.com/maps/place/x'),
        NavigationDecision.prevent,
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/xem');
      expect(launched, isEmpty);
    },
  );
  for (final kind in ['privacy', 'tour']) {
    testWidgets('$kind blocks intent and opens HTTP links inside the app', (
      tester,
    ) async {
      final router = await mount(
        tester,
        kind == 'privacy'
            ? const PrivacyPolicyScreen()
            : const TourFrame(
                url: 'https://360.smartrealtors.vn/share/collection/7H1b3',
                title: 'Tour',
              ),
      );
      final nav = platform.controllers.single.navigation!;
      expect(
        await nav.navigate('intent://x#Intent;end'),
        NavigationDecision.prevent,
      );
      expect(
        await nav.navigate(
          kind == 'privacy'
              ? 'about:blank'
              : 'https://360.smartrealtors.vn/share/scene/2',
        ),
        NavigationDecision.navigate,
      );
      expect(
        await nav.navigate('https://smartduan.vn/lien-he'),
        NavigationDecision.prevent,
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/xem');
      expect(launched, isEmpty);
    });
  }
  testWidgets('viewer allows web navigation and hands zalo to the OS', (
    tester,
  ) async {
    await mount(
      tester,
      const ViewerScreen(url: 'https://dev.smartduan.vn/dang-ky'),
    );
    final nav = platform.controllers.single.navigation!;
    expect(
      await nav.navigate('https://www.youtube-nocookie.com/embed/x'),
      NavigationDecision.navigate,
    );
    expect(await nav.navigate('zalo://chat'), NavigationDecision.prevent);
    await tester.pump();
    expect(launched, ['zalo://chat']);
  });
  for (final url in ['javascript:alert(1)', 'file:///secret', 'https://']) {
    testWidgets('viewer rejects route parameter $url without a WebView', (
      tester,
    ) async {
      await mount(tester, ViewerScreen(url: url));
      expect(find.text('Link không hợp lệ.'), findsOneWidget);
      expect(platform.controllers, isEmpty);
    });
  }
  testWidgets('tour rejects an untrusted initial URL before native loading', (
    tester,
  ) async {
    await mount(
      tester,
      const TourFrame(url: 'https://evil.vn/', title: 'Tour'),
    );
    expect(platform.controllers, isEmpty);
  });
  testWidgets('invalid map coordinates create no WebView', (tester) async {
    await mount(tester, const MapEmbed(lat: '91', lng: '2', name: 'X'));
    expect(platform.controllers, isEmpty);
  });
  testWidgets('tour load error presents retry and recreates the view', (
    tester,
  ) async {
    await mount(
      tester,
      const TourFrame(url: 'https://360.smartrealtors.vn/x', title: 'Tour'),
    );
    platform.controllers.single.navigation!.error!(
      const WebResourceError(
        errorCode: -1,
        description: 'offline',
        isForMainFrame: true,
      ),
    );
    await tester.pump();
    expect(find.text('Không tải được tour 360°'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump();
    expect(platform.controllers, hasLength(2));
  });
}
