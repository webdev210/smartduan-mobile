import 'dart:async';

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/public/home.dart';
import 'package:smartduan/ui/kit.dart' show Skeleton;

import '../../api/fake_http.dart';
import '../../api/public_test.dart' show projectJson;

class GuestSession extends Session {
  GuestSession([this.reason]);
  final String? reason;
  @override
  SessionState build() =>
      SessionState(SessionStatus.guest, endedReason: reason);
}

Future<GoRouter> mountHome(
  WidgetTester tester,
  FakeHttp http, {
  String? reason,
}) async {
  final client = ApiClient(adapter: http);
  addTearDown(client.close);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PublicHome()),
      for (final path in [
        '/kham-pha',
        '/dang-nhap',
        '/dang-ky',
        '/tinh-lai-vay',
        '/chinh-sach-bao-mat',
        '/cong-khai/:code',
        '/bai-viet/:slug',
        '/chu-dau-tu/:slug',
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => GuestSession(reason)),
        publicApiProvider.overrideWithValue(PublicApi(client)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Reply homeReply(String path) => switch (path) {
  '/public/stats' => const Reply(200, {
    'data': {
      'developers': 2,
      'projects_selling': 3,
      'activity_7d_total': 0,
      'contact': {
        'hotline': '0901234567',
        'zalo_url': 'https://zalo.me/0901234567',
      },
    },
  }),
  _ => const Reply(200, {
    'data': <Object?>[],
    'page': 1,
    'per_page': 50,
    'total': 0,
  }),
};

void main() {
  testWidgets(
    'contact buttons hand telephone and Zalo to the external launcher',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await mountHome(tester, FakeHttp((c) => homeReply(c.path)));
      await tester.ensureVisible(find.text('0901234567'));
      await tester.pump();
      await tester.tap(find.text('0901234567'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat Zalo'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => (c.arguments as Map<Object?, Object?>)['url']), [
        'tel:0901234567',
        'https://zalo.me/0901234567',
      ]);
      expect(
        calls.every(
          (c) => (c.arguments as Map<Object?, Object?>)['useWebView'] == false,
        ),
        isTrue,
      );
    },
  );
  testWidgets(
    'hero, posts, footer type and developer blocks keep RN order and destinations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final http = FakeHttp((c) {
        if (c.path == '/public/projects') {
          return Reply(200, {
            'data': [
              {...projectJson('sky'), 'name': 'Sky Park', 'province': 'Hà Nội'},
            ],
            'page': 1,
            'per_page': 50,
            'total': 1,
          });
        }
        if (c.path == '/public/posts') {
          return Reply(200, {
            'data': [
              {
                'id': c.queryParameters['kind'],
                'kind': c.queryParameters['kind'],
                'title': c.queryParameters['kind'] == 'news'
                    ? 'Tin dự án'
                    : 'Lễ ra mắt',
                'slug': c.queryParameters['kind'],
                'published_at': '2026-11-12',
              },
            ],
            'page': 1,
            'per_page': 3,
            'total': 1,
          });
        }
        if (c.path == '/public/developers') {
          return const Reply(200, {
            'data': [
              {
                'id': 'sun',
                'name': 'Sun Group',
                'slug': 'sun-group',
                'logo_url': null,
                'website': null,
                'description': null,
                'badges': <String>[],
              },
            ],
            'page': 1,
            'per_page': 200,
            'total': 1,
          });
        }
        if (c.path == '/public/footer-links') {
          return const Reply(200, {
            'data': [
              {
                'label': 'Dự án căn hộ',
                'href': '/du-an?project_type=apartment',
                'count': 1,
              },
              {'label': 'Ngoài danh mục', 'href': '/other', 'count': 0},
            ],
          });
        }
        return homeReply(c.path);
      });
      final router = await mountHome(tester, http);
      final titles = [
        'Dự án nổi bật',
        'Dự án theo khu vực',
        'Tin mới',
        'Sự kiện',
        'Theo khu vực',
        'Theo loại hình',
        'Theo chủ đầu tư',
      ];
      for (var i = 1; i < titles.length; i++) {
        expect(
          tester.getTopLeft(find.text(titles[i])).dy,
          greaterThan(tester.getTopLeft(find.text(titles[i - 1])).dy),
        );
      }
      expect(find.text('Ngoài danh mục'), findsNothing);
      await tester.ensureVisible(find.text('Căn hộ · 1'));
      await tester.pump();
      await tester.tap(find.text('Căn hộ · 1'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/kham-pha');
      expect(router.state.uri.queryParameters, {'project_type': 'apartment'});
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sun Group').last);
      await tester.pump();
      await tester.tap(find.text('Sun Group').last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/chu-dau-tu/sun-group');
    },
  );
  testWidgets(
    'RN publicHome: page two appears in the region rail and province counts include all 51 projects',
    (tester) async {
      final http = FakeHttp((c) {
        if (c.path != '/public/projects') return homeReply(c.path);
        if (c.queryParameters['hot'] != null) return homeReply('');
        final page = c.queryParameters['page'];
        return Reply(200, {
          'data': page == 1
              ? List.generate(
                  50,
                  (i) => {
                    ...projectJson('p$i'),
                    'status': 'sold_out',
                    'province': 'TP. Hồ Chí Minh',
                  },
                )
              : [
                  {
                    ...projectJson('p50'),
                    'name': 'Dự án trang hai',
                    'status': 'sold_out',
                    'province': 'Hà Nội',
                  },
                ],
          'page': page,
          'per_page': 50,
          'total': 51,
        });
      });
      await mountHome(tester, http);
      expect(find.text('Dự án trang hai'), findsOneWidget);
      expect(find.text('Hà Nội · 1'), findsOneWidget);
      expect(find.text('TP.HCM · 50'), findsOneWidget);
      expect(find.text('giao dịch 7 ngày'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search entry opens catalogue with the trimmed query', (
    tester,
  ) async {
    final router = await mountHome(tester, FakeHttp((c) => homeReply(c.path)));
    await tester.enterText(find.byType(TextField), '  ha noi  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/kham-pha');
    expect(router.state.uri.queryParameters, {'q': 'ha noi'});
  });
  testWidgets('home empty state, session banner and guest menu routes', (
    tester,
  ) async {
    final router = await mountHome(
      tester,
      FakeHttp((c) => homeReply(c.path)),
      reason: 'locked',
    );
    expect(find.text('Tài khoản bị khoá'), findsOneWidget);
    expect(find.text('Chưa có dự án nào đang mở bán.'), findsOneWidget);
    expect(find.text('Chưa có dự án tại khu vực này.'), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả dự án'), findsOneWidget);
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/dang-ky');
  });
  testWidgets(
    'failed catalogue offers retry and pull refresh reloads all home feeds',
    (tester) async {
      var failed = true;
      final http = FakeHttp(
        (c) =>
            c.path == '/public/projects' &&
                c.queryParameters['hot'] == null &&
                failed
            ? const Reply(503, {'error': 'unavailable'})
            : homeReply(c.path),
      );
      await mountHome(tester, http);
      expect(find.text('Thử lại'), findsOneWidget);
      failed = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      http.seen.clear();
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 450));
      await tester.pumpAndSettle();
      expect(
        http.seen.map((c) => c.path).toSet(),
        containsAll([
          '/public/projects',
          '/public/stats',
          '/public/posts',
          '/public/provinces',
          '/public/footer-links',
          '/public/developers',
        ]),
      );
    },
  );
  testWidgets('pending catalogue shows a skeleton', (tester) async {
    final pending = Completer<Reply>();
    final http = FakeHttp(
      (c) => c.path == '/public/projects' ? pending.future : homeReply(c.path),
    );
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(GuestSession.new),
          publicApiProvider.overrideWithValue(PublicApi(client)),
        ],
        child: const MaterialApp(home: PublicHome()),
      ),
    );
    expect(find.byType(Skeleton), findsWidgets);
    pending.complete(homeReply(''));
    await tester.pumpAndSettle();
  });
}
