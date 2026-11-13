import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/me.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/public/developer.dart';
import 'package:smartduan/screens/public/loan.dart';
import 'package:smartduan/screens/public/post.dart';
import 'package:smartduan/screens/public/privacy_policy.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/loan_result_cards.dart';
import 'package:smartduan/ui/project_card.dart';

import '../../api/fake_http.dart';

class DetailSession extends Session {
  DetailSession(this.status);
  final SessionStatus status;
  @override
  SessionState build() => SessionState(status);
}

class DetailMeApi extends MeApi {
  DetailMeApi(super.client);
  List<String> codes = [];
  final writes = <String>[];
  bool fail = false;
  Completer<List<String>>? pending;
  @override
  Future<List<String>> fetchSavedProjects() async => codes;
  @override
  Future<List<String>> saveProjects(List<String> value) async {
    writes.add('save:${value.join(',')}');
    if (pending case final result?) return codes = await result.future;
    if (fail) {
      throw const ApiError(500, 'server_error', 'Có lỗi, vui lòng thử lại');
    }
    return codes = [...value];
  }

  @override
  Future<List<String>> unsaveProject(String code) async {
    writes.add('unsave:$code');
    if (pending case final result?) return codes = await result.future;
    return codes = [];
  }
}

final project = PublicProject(
  id: 'id',
  code: 'SKY',
  name: 'Dự án A',
  status: 'selling',
  province: 'Hà Nội',
  provinceOld: 'Hà Tây',
  priceFrom: '2000000000',
  projectType: 'apartment',
  developer: const ProjectDeveloper(
    id: 'dev',
    name: 'Chủ đầu tư A',
    slug: 'dev',
  ),
  overviewJson: {
    'summary': 'Tổng quan mẫu',
    'usp': ['Điểm nổi bật'],
    'scale': '10 ha',
    'amenities': ['Hồ bơi'],
  },
  subdivisions: [
    const PublicSubdivision(name: 'Phân khu A', description: 'Mô tả phân khu'),
  ],
  progress: [
    const PublicProgress(
      title: 'Khởi công',
      occurredOn: '2026-01-01',
      body: 'Đang xây',
    ),
  ],
  documents: [
    const PublicDocument(name: 'Tài liệu A', url: 'https://example.vn/a.pdf'),
    const PublicDocument(name: 'Unsafe', url: 'javascript:bad'),
  ],
  faqs: [
    const PublicFaq(
      id: 'faq',
      question: 'Câu hỏi?',
      answer: 'Câu trả lời',
      position: 0,
    ),
  ],
);

void main() {
  Future<GoRouter> mount(
    WidgetTester tester,
    Widget child,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        for (final path in [
          '/dang-nhap',
          '/dang-ky',
          '/xem',
          '/chu-dau-tu/:slug',
          '/du-an/:id',
          '/cong-khai/:code',
        ])
          GoRoute(
            path: path,
            builder: (_, s) => Text('destination:${s.uri.path}'),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'project renders source sections, expands FAQ, and opens developer projects',
    (tester) async {
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(
            () => DetailSession(SessionStatus.guest),
          ),
          fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
        ],
      );
      final router = await mount(
        tester,
        const ProjectDetailScreen(code: 'SKY'),
        container,
      );
      for (final label in [
        'Tổng quan',
        'Thông tin dự án',
        'Tiện ích',
        'Phân khu',
        'Tiến độ',
        'Tài liệu',
        'Hỏi đáp',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Unsafe'), findsNothing);
      expect(find.byIcon(Ionicons.chevronDown), findsOneWidget);
      expect(find.textContaining('trước đây: Hà Tây'), findsOneWidget);
      await tester.ensureVisible(find.text('Câu hỏi?'));
      await tester.tap(find.text('Câu hỏi?'));
      await tester.pumpAndSettle();
      expect(find.text('Câu trả lời'), findsOneWidget);
      expect(find.byIcon(Ionicons.chevronUp), findsOneWidget);
      expect(find.byIcon(Ionicons.chevronDown), findsNothing);
      await tester.ensureVisible(find.text('Dự án khác'));
      await tester.tap(find.text('Dự án khác'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/chu-dau-tu/dev');
    },
  );
  testWidgets('guest board CTA beacons once and opens login', (tester) async {
    final http = FakeHttp((_) => const Reply(200));
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => DetailSession(SessionStatus.guest)),
        publicApiProvider.overrideWithValue(PublicApi(client)),
        fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
      ],
    );
    final router = await mount(
      tester,
      const ProjectDetailScreen(code: 'SKY'),
      container,
    );
    expect(find.byTooltip('Yêu thích Dự án A'), findsOneWidget);
    expect(find.byIcon(Ionicons.lockOpenOutline), findsOneWidget);
    expect(find.byIcon(Ionicons.callOutline), findsOneWidget);
    await tester.tap(find.text('Xem bảng hàng'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/dang-nhap');
    expect(http.seen.single.data, {'project_id': 'id', 'event': 'cta_click'});
  });
  testWidgets(
    'signed-in project saves and unsaves and board opens internal route',
    (tester) async {
      final client = ApiClient();
      addTearDown(client.close);
      final me = DetailMeApi(client);
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(
            () => DetailSession(SessionStatus.signedIn),
          ),
          meApiProvider.overrideWithValue(me),
          fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
        ],
      );
      final router = await mount(
        tester,
        const ProjectDetailScreen(code: 'SKY'),
        container,
      );
      await tester.tap(find.byTooltip('Yêu thích Dự án A'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bỏ yêu thích Dự án A'), findsOneWidget);
      await tester.tap(find.byTooltip('Bỏ yêu thích Dự án A'));
      await tester.pumpAndSettle();
      expect(me.writes, ['save:SKY', 'unsave:SKY']);
      await tester.tap(find.text('Xem bảng hàng'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/du-an/id');
    },
  );
  testWidgets(
    'failed save preserves unsaved state and reports error without retrying',
    (tester) async {
      final client = ApiClient();
      addTearDown(client.close);
      final me = DetailMeApi(client)..fail = true;
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(
            () => DetailSession(SessionStatus.signedIn),
          ),
          meApiProvider.overrideWithValue(me),
          fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
        ],
      );
      await mount(tester, const ProjectDetailScreen(code: 'SKY'), container);
      await tester.tap(find.byTooltip('Yêu thích Dự án A'));
      await tester.pumpAndSettle();
      expect(find.text('Không lưu được'), findsOneWidget);
      expect(me.writes, ['save:SKY']);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Yêu thích Dự án A'), findsOneWidget);
    },
  );
  for (final saved in [false, true]) {
    for (final fails in [false, true]) {
      testWidgets(
        'signed-in ${saved ? "unsave" : "save"} pending then ${fails ? "failure" : "success"} follows RN state',
        (tester) async {
          final client = ApiClient();
          addTearDown(client.close);
          final pending = Completer<List<String>>();
          final me = DetailMeApi(client)
            ..codes = saved ? ['SKY'] : []
            ..pending = pending;
          final container = ProviderContainer.test(
            overrides: [
              sessionProvider.overrideWith(
                () => DetailSession(SessionStatus.signedIn),
              ),
              meApiProvider.overrideWithValue(me),
              fetchPublicProjectProvider('SKY')
                  .overrideWith((_) async => project),
            ],
          );
          await mount(
            tester,
            const ProjectDetailScreen(code: 'SKY'),
            container,
          );
          final before = saved ? 'Bỏ yêu thích Dự án A' : 'Yêu thích Dự án A';
          final after = saved ? 'Yêu thích Dự án A' : 'Bỏ yêu thích Dự án A';
          await tester.tap(find.byTooltip(before));
          await tester.pump();
          // Upstream heart updates optimistically while the write is pending.
          expect(find.byTooltip(after), findsOneWidget);
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == after,
                  ),
                )
                .onPressed,
            isNull,
          );
          if (fails) {
            pending.completeError(
              const ApiError(500, 'server_error', 'Có lỗi, vui lòng thử lại'),
            );
          } else {
            pending.complete(saved ? [] : ['SKY']);
          }
          await tester.pumpAndSettle();
          if (fails) {
            expect(find.text('Không lưu được'), findsOneWidget);
            expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
            await tester.tap(find.text('OK'));
            await tester.pumpAndSettle();
          }
          expect(find.byTooltip(fails ? before : after), findsOneWidget);
          expect(me.writes, [saved ? 'unsave:SKY' : 'save:SKY']);
        },
      );
    }
  }
  testWidgets('project 404 displays backend text and explicit retry', (
    tester,
  ) async {
    var calls = 0;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => DetailSession(SessionStatus.guest)),
        fetchPublicProjectProvider('missing').overrideWith((_) async {
          calls++;
          throw const ApiError(404, 'not_found', 'Không tìm thấy dự án');
        }),
      ],
    );
    await mount(tester, const ProjectDetailScreen(code: 'missing'), container);
    expect(find.text('Không tìm thấy dự án'), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
  testWidgets('privacy server 503 stays recoverable', (tester) async {
    var calls = 0;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        fetchFullPolicyProvider.overrideWith((_) async {
          calls++;
          throw const ApiError(503, 'server_error', 'Có lỗi, vui lòng thử lại');
        }),
      ],
    );
    await mount(tester, const PrivacyPolicyScreen(), container);
    expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
  testWidgets('post renders native blocks and links associated project', (
    tester,
  ) async {
    final p = PublicPost.fromJson({
      'id': '1',
      'slug': 'post',
      'kind': 'event',
      'title': 'Sự kiện mẫu',
      'body': '<h2>Tiêu đề</h2><p>Nội dung <b>đậm</b></p><ol><li>Một</li><li>Hai</li></ol><blockquote>Trích dẫn</blockquote><hr>',
      'project': {'id': 'id', 'code': 'SKY', 'name': 'Dự án A'},
    });
    final container = ProviderContainer.test(
      overrides: [fetchPublicPostProvider('post').overrideWith((_) async => p)],
    );
    final router = await mount(
      tester,
      const PostScreen(slug: 'post'),
      container,
    );
    expect(find.text('Tiêu đề', findRichText: true), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    await tester.ensureVisible(find.text('Dự án A'));
    await tester.tap(find.text('Dự án A'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/cong-khai/SKY');
  });
  testWidgets(
    'developer filters accent-insensitively and clears empty search',
    (tester) async {
      final filter = const PublicFilters(developerId: 'dev', perPage: 50);
      final container = ProviderContainer.test(
        overrides: [
          fetchPublicDeveloperProvider('dev').overrideWith(
            (_) async => PublicDeveloper.fromJson({
              'id': 'dev',
              'name': 'Chủ đầu tư A',
              'badges': ['Uy tín'],
            }),
          ),
          listPublicProjectsProvider(filter).overrideWith(
            (_) async => Paged(
              data: List.generate(
                5,
                (i) => PublicProject(
                  id: '$i',
                  code: '$i',
                  name: i == 0 ? 'Hồ Tây' : 'Dự án $i',
                  status: 'selling',
                ),
              ),
              page: 1,
              perPage: 50,
              total: 5,
            ),
          ),
        ],
      );
      await mount(tester, const DeveloperScreen(slug: 'dev'), container);
      expect(find.text('Uy tín'), findsOneWidget);
      expect(find.byType(ProjectCard), findsNWidgets(5));
      await tester.enterText(find.byType(TextField), 'ho tay');
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'khong co');
      await tester.pumpAndSettle();
      expect(find.text('Không có dự án nào khớp.'), findsOneWidget);
      expect(find.byIcon(Ionicons.searchOutline), findsOneWidget);
      await tester.ensureVisible(find.text('Xoá từ khoá'));
      await tester.tap(find.text('Xoá từ khoá'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(5));
    },
  );
  testWidgets('developer empty collection has no search field', (tester) async {
    final container = ProviderContainer.test(
      overrides: [
        fetchPublicDeveloperProvider('dev').overrideWith(
          (_) async => PublicDeveloper.fromJson({
            'id': 'dev',
            'name': 'Chủ đầu tư A',
            'badges': <String>[],
          }),
        ),
        listPublicProjectsProvider(
          const PublicFilters(developerId: 'dev', perPage: 50),
        ).overrideWith(
          (_) async =>
              Paged<PublicProject>(data: [], page: 1, perPage: 50, total: 0),
        ),
      ],
    );
    await mount(tester, const DeveloperScreen(slug: 'dev'), container);
    expect(find.text('Chưa có dự án công khai.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets(
    'loan normalizes numbers, posts once, and renders first 12 periods',
    (tester) async {
      final http = FakeHttp(
        (_) => Reply(200, {
          'price': 2000000000,
          'loan_amount': 1400000000,
          'loan_ratio': 0.7,
          'term_months': 240,
          'grace_months': 0,
          'supported_rate': 0.085,
          'floating_rate': 0.1,
          'monthly_payment': 10000000,
          'totals': {
            'principal': 1400000000,
            'interest': 100000000,
            'total': 1500000000,
          },
          'schedule': List.generate(
            14,
            (i) => {
              'period': i + 1,
              'principal': 100,
              'interest': 20,
              'total': 120,
              'remaining': 1000,
            },
          ),
        }),
      );
      final client = ApiClient(adapter: http);
      addTearDown(client.close);
      final container = ProviderContainer.test(
        overrides: [publicApiProvider.overrideWithValue(PublicApi(client))],
      );
      await mount(tester, const LoanScreen(), container);
      expect(
        tester
            .widget<kit.Button>(find.widgetWithText(kit.Button, 'Tính'))
            .disabled,
        isTrue,
      );
      await tester.enterText(find.byType(TextField).at(0), '2.000.000.000');
      await tester.enterText(find.byType(TextField).at(3), '8,5');
      await tester.ensureVisible(find.text('Tính'));
      await tester.tap(find.text('Tính'));
      await tester.pumpAndSettle();
      expect(http.seen.single.data, {
        'price': '2000000000',
        'loan_ratio': 70,
        'term_months': 240,
        'annual_rate': 8.5,
      });
      expect(find.byType(LoanResultCards), findsOneWidget);
      expect(find.text('Kỳ 12'), findsNothing);
      await tester.ensureVisible(find.text('Xem lịch trả 12 kỳ đầu'));
      await tester.tap(find.text('Xem lịch trả 12 kỳ đầu'));
      await tester.pumpAndSettle();
      expect(find.text('Kỳ 12'), findsOneWidget);
      expect(find.text('Kỳ 13'), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), '60');
      await tester.pump();
      expect(find.byType(LoanResultCards), findsNothing);
      expect(http.seen, hasLength(1));
    },
  );
  testWidgets(
    'loan failure maps price field error and does not auto-retry POST',
    (tester) async {
      final http = FakeHttp(
        (_) => const Reply(422, {
          'error': 'validation',
          'message': 'Dữ liệu không hợp lệ',
          'details': {
            'price': ['Giá không hợp lệ'],
          },
        }),
      );
      final client = ApiClient(adapter: http);
      addTearDown(client.close);
      final container = ProviderContainer.test(
        overrides: [publicApiProvider.overrideWithValue(PublicApi(client))],
      );
      await mount(tester, const LoanScreen(), container);
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.pump();
      await tester.ensureVisible(find.text('Tính'));
      await tester.tap(find.text('Tính'));
      await tester.pumpAndSettle();
      expect(http.seen, hasLength(1));
      expect(find.text('Dữ liệu không hợp lệ'), findsOneWidget);
      expect(find.text('Giá không hợp lệ'), findsOneWidget);
    },
  );
  testWidgets(
    'loan API failure is shown without rendering results or retrying',
    (tester) async {
      final http = FakeHttp(
        (_) => const Reply(500, {
          'error': 'server_error',
          'message': 'Có lỗi, vui lòng thử lại',
        }),
      );
      final client = ApiClient(adapter: http);
      addTearDown(client.close);
      final container = ProviderContainer.test(
        overrides: [publicApiProvider.overrideWithValue(PublicApi(client))],
      );
      await mount(tester, const LoanScreen(), container);
      await tester.enterText(find.byType(TextField).first, '2000000000');
      await tester.pump();
      await tester.ensureVisible(find.text('Tính'));
      await tester.tap(find.text('Tính'));
      await tester.pumpAndSettle();
      expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
      expect(find.byType(LoanResultCards), findsNothing);
      expect(http.seen, hasLength(1));
    },
  );
  testWidgets('project loading is visible until data arrives', (tester) async {
    final pending = Completer<PublicProject>();
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => DetailSession(SessionStatus.guest)),
        fetchPublicProjectProvider('SKY').overrideWith((_) => pending.future),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectDetailScreen(code: 'SKY')),
      ),
    );
    expect(find.byType(kit.Loading), findsOneWidget);
    pending.complete(project);
    await tester.pumpAndSettle();
    expect(find.text('Dự án A'), findsNWidgets(2));
  });
}
