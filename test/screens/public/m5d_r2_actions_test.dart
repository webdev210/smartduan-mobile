import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/screens/auth/login.dart';
import 'package:smartduan/screens/public/developer.dart';
import 'package:smartduan/screens/public/project_compare.dart';
import 'package:smartduan/screens/public/tour_360.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:smartduan/ui/project_compare.dart';
// Installed by webview_flutter.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../ui/detail_webview_fake.dart';
import '../auth/auth_fakes.dart';
import '../auth/login_test.dart' show ConnectionApi;
import '../../support/responsive.dart';
import 'm5d_r2_responsive_test.dart' show longName, tourUrl;

void main() {
  setUp(() => WebViewPlatform.instance = DetailWebViewPlatform());
  testWidgets(
    'connection check semantic target stays tappable across the matrix',
    (tester) async {
      await expectResponsive(tester, () async {
        final api = ConnectionApi(null);
        final auth = TestAuth();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [publicApiProvider.overrideWithValue(api)],
            child: authApp(const LoginScreen(), auth, TestSession()),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.bySemanticsLabel('Kiểm tra kết nối');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(api.calls, ['health', 'provinces']);
        await tester.pumpWidget(const SizedBox());
        api.client.close();
        auth.client.close();
      });
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final tour in [false, true]) {
      testWidgets(
        '$platform ${tour ? 'tour' : 'viewer'} blocks system/edge back, explicit back exits',
        (tester) async {
          tester.view
            ..physicalSize = const Size(393, 852)
            ..devicePixelRatio = 1
            ..padding = const FakeViewPadding(top: 59, bottom: 34);
          addTearDown(tester.view.reset);
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Home')),
              ),
              GoRoute(
                path: '/embed',
                builder: (_, _) => tour
                    ? const Tour360Screen(url: tourUrl, name: longName)
                    : const ViewerScreen(
                        url: 'https://example.vn/page',
                        title: longName,
                      ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: ThemeData(platform: platform),
            ),
          );
          router.push('/embed');
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final route = ModalRoute.of(
            tester.element(find.byType(tour ? Tour360Screen : ViewerScreen)),
          );
          expect(route!.popGestureEnabled, isFalse);
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(router.state.uri.path, '/embed');
          await tester.dragFrom(const Offset(1, 250), const Offset(300, 0));
          await tester.pump();
          expect(router.state.uri.path, '/embed');
          final back = tour
              ? find.byTooltip('Đóng tour 360°')
              : find.byTooltip('Quay lại');
          expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
          expect(tester.getTopLeft(back).dy, greaterThanOrEqualTo(59));
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/');
        },
      );
    }
    testWidgets(
      '$platform document share failure offers retry using cached file',
      (tester) async {
        var downloads = 0, shares = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (_) async {
            shares++;
            throw PlatformException(code: 'unavailable');
          },
        );
        final container = ProviderContainer.test(
          overrides: [
            viewerFileProvider('https://example.vn/a.pdf')
                .overrideWith((_) async {
                  downloads++;
                  return '/tmp/document.pdf';
                }),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const ViewerScreen(url: 'https://example.vn/a.pdf'),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (platform == TargetPlatform.iOS) {
          expect(downloads, 0);
          expect(
            (WebViewPlatform.instance as DetailWebViewPlatform).controllers,
            isNotEmpty,
          );
          await tester.tap(find.byTooltip('Chia sẻ tài liệu'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text(
            'Đã tải file; chưa mở được chia sẻ. Thử lại bằng file đã tải.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Mở hoặc chia sẻ tài liệu'));
        await tester.pumpAndSettle();
        expect(downloads, 1);
        expect(shares, 2);
      },
    );
  }
  for (final failed in [false, true]) {
    testWidgets(
      'comparison reserves selected-code slots while first request waits; failed=$failed',
      (tester) async {
        final pending = Completer<PublicProject>();
        final container = ProviderContainer.test(
          overrides: [
            fetchPublicProjectProvider('A').overrideWith((_) => pending.future),
            fetchPublicProjectProvider('B').overrideWith(
              (_) async => PublicProject(
                id: 'B',
                code: 'B',
                name: longName,
                status: 'selling',
              ),
            ),
          ],
        );
        container.read(projectCompareProvider.notifier)
          ..add('A')
          ..add('B');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProjectCompareScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();
        final before = tester.getTopLeft(find.text(longName));
        expect(find.byKey(const ValueKey('compare-A')), findsOneWidget);
        if (failed) {
          pending.completeError(const ApiError(503, 'unavailable', 'Thử lại'));
        } else {
          pending.complete(
            PublicProject(
              id: 'A',
              code: 'A',
              name: 'Dự án A',
              status: 'selling',
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text(longName)), before);
      },
    );
  }
  testWidgets('pending login contact is actionable and retry remains manual', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    final api = TestAuth()
      ..failure = const ApiError(
        202,
        'device_pending',
        '',
        body: {
          'contact': {'name': longName, 'phone': '0901234567'},
        },
      );
    addTearDown(api.client.close);
    await tester.pumpWidget(authApp(const LoginScreen(), api, TestSession()));
    await tester.enterText(find.byType(TextField).first, 'a@example.vn');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(api.logins, hasLength(1));
    expect(find.text('Gọi người duyệt'), findsOneWidget);
    await tester.ensureVisible(find.text('Sao chép'));
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle();
    expect(copied, ['0901234567']);
    expect(find.text('Đăng nhập lại sau duyệt'), findsOneWidget);
    expect(api.logins, hasLength(1));
  });
  testWidgets('developer website precedes the full description', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        fetchPublicDeveloperProvider('dev').overrideWith(
          (_) async => PublicDeveloper(
            id: 'dev',
            slug: 'dev',
            name: longName,
            website: 'https://example.vn',
            description: 'Mô tả chủ đầu tư',
            badges: [],
          ),
        ),
        listPublicProjectsProvider(
          const PublicFilters(developerId: 'dev', perPage: 50),
        ).overrideWith(
          (_) async => Paged(data: [], page: 1, perPage: 50, total: 0),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeveloperScreen(slug: 'dev')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Website chủ đầu tư')).dy,
      lessThan(tester.getTopLeft(find.text('Mô tả chủ đầu tư')).dy),
    );
  });
}
