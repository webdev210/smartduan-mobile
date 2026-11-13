import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart' hide Card, SearchBar, Chip;
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/models.dart' as models;
import 'package:smartduan/api/sales.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/app/menu_tab.dart';
import 'package:smartduan/screens/app/notifications.dart';
import 'package:smartduan/screens/app/projects_tab.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/tab_routes.dart';
import 'package:smartduan/ui/kit.dart' hide Row;
import 'package:smartduan/ui/favorite_button.dart';
import 'package:smartduan/ui/menu.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/project_compare_kit.dart';
import 'package:smartduan/ui/theme.dart';

import '../../api/fake_http.dart';
import '../../auth/token_store_test.dart' show MemoryStorage;

class TabSession extends Session {
  TabSession(this.roles);
  final List<String> roles;
  bool? everywhere;
  @override
  SessionState build() => SessionState(
    SessionStatus.signedIn,
    me: {
      'roles': roles,
      'full_name': 'Nguyễn An',
      'email': 'an@example.test',
      'region': 'south',
    },
  );
  @override
  Future<void> signOut({bool everywhere = false}) async {
    this.everywhere = everywhere;
    state = const SessionState(SessionStatus.guest);
  }

  void end() => state = const SessionState(SessionStatus.guest);
}

Reply emptyReply(String path) => switch (path) {
  '/sales/survey' => const Reply(200, {
    'data': {'due': false},
  }),
  '/sales/notifications' => const Reply(200, {
    'data': <Object?>[],
    'unread': 0,
  }),
  '/enums' => const Reply(200, {}),
  _ => const Reply(200, {
    'data': <Object?>[],
    'total': 0,
    'page': 1,
    'per_page': 30,
  }),
};

Future<({ProviderContainer container, TabSession session})> mount(
  WidgetTester tester,
  Widget child,
  FakeHttp http, {
  List<String> roles = const ['agent'],
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session = TabSession(roles);
  final client = ApiClient(
    adapter: http,
    tokens: SecureValue('tabs', storage: MemoryStorage()),
  );
  addTearDown(client.close);
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      sessionProvider.overrideWith(() => session),
      apiClientProvider.overrideWithValue(client),
    ],
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/can/:id',
        builder: (_, s) =>
            Scaffold(body: Text('unit ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/bang-tin/:id',
        builder: (_, s) =>
            Scaffold(body: Text('news ${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, session: session);
}

void main() {
  test('registry contains exactly the five tabs', () {
    expect(appTabScreens.keys, [
      '/',
      '/du-an',
      '/tim-can',
      '/thong-bao',
      '/menu',
    ]);
  });
  test('saved params trim values and split sorting; empty saved status stays empty', () {
    expect(
      const UnitSearchFilters(
        q: ' A1 ',
        unitType: ' 2PN ',
        direction: ' E ',
        sort: 'price_list:desc',
      ).toParams(),
      {
        'q': 'A1',
        'status': 'available',
        'unit_type': '2PN',
        'direction': 'E',
        'sort': 'price_list',
        'dir': 'desc',
      },
    );
    expect(
      UnitSearchFilters.fromParams({
        'q': 'B',
        'sort': 'area_gross',
        'unknown': 'ignored',
      }).toParams(),
      {'q': 'B', 'sort': 'area_gross', 'dir': 'asc'},
    );
    expect(UnitSearchFilters.fromParams({}).toParams(), isEmpty);
  });
  test('browser adapter preserves public gates and internal metadata', () {
    final p = TabProject(
      const models.Project(
        id: 'p',
        code: 'P',
        name: 'Dự án',
        developerName: 'Smartland',
        inventoryUpdatedAt: '2026-11-12',
      ),
    );
    expect(p.isPublic, false);
    expect(p.developerName, 'Smartland');
    expect(p.inventoryUpdatedAt, '2026-11-12');
  });
  test('notification links only dispatch supported RN targets', () {
    expect(notificationRoute('/sales/bang-tin/a?x=1'), '/bang-tin/a');
    expect(notificationRoute('/sales/ho-so'), '/ho-so');
    expect(notificationRoute('/sales/bang-tin'), '/bang-tin');
    expect(notificationRoute('https://example.test/unknown'), isNull);
    expect(notificationRoute(null), isNull);
  });
  for (final role in [
    '',
    'agent',
    'manager',
    'admin',
    'superadmin',
    'sales_free',
    'sales_partner',
  ]) {
    testWidgets(
      'menu visible entries follow role $role and hide disabled features',
      (tester) async {
        final roles = role.isEmpty ? <String>[] : [role];
        await mount(
          tester,
          const MenuTab(),
          FakeHttp((r) => emptyReply(r.path)),
          roles: roles,
        );
        for (final group in menuGroups(roles)) {
          for (final item in group.items) {
            expect(
              find.text(item.label),
              findsWidgets,
              reason: '$role: ${item.key}',
            );
          }
        }
        expect(find.text('Booking'), findsNothing);
        expect(find.text('Tạo tin đăng'), findsNothing);
        expect(find.text('Mặt bằng'), findsNothing);
        expect(
          find.text('Đội của tôi'),
          role == 'manager' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('menu omits sign out everywhere', (tester) async {
    await mount(tester, const MenuTab(), FakeHttp((r) => emptyReply(r.path)));
    expect(find.text('Đăng xuất trên mọi thiết bị'), findsNothing);
  });
  for (final everywhere in [false]) {
    testWidgets('menu signs out everywhere=$everywhere', (tester) async {
      final http = FakeHttp(
        (r) =>
            r.path == '/auth/ws-token' ? const Reply(503) : emptyReply(r.path),
      );
      final env = await mount(tester, const MenuTab(), http);
      final channel = env.container.listen(
        inventoryChannelProvider('p'),
        (_, _) {},
      );
      addTearDown(channel.close);
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất trên mọi thiết bị'), findsNothing);
      expect(http.seen.where((r) => r.path == '/auth/ws-token'), hasLength(1));
      final label = everywhere ? 'Đăng xuất trên mọi thiết bị' : 'Đăng xuất';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(env.session.everywhere, everywhere);
      expect(env.container.read(inventoryChannelProvider('p')).live, isFalse);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(http.seen.where((r) => r.path == '/auth/ws-token'), hasLength(1));
    });
  }
  testWidgets('menu search has an actionable empty state', (tester) async {
    await mount(tester, const MenuTab(), FakeHttp((r) => emptyReply(r.path)));
    await tester.ensureVisible(find.byType(SearchBar));
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Không có tính năng nào khớp “zzzz”.'), findsOneWidget);
    expect(find.byIcon(Ionicons.searchOutline), findsOneWidget);
  });
  testWidgets('home falls back to public empty projects and has compare dock', (
    tester,
  ) async {
    await mount(
      tester,
      const HomeScreen(),
      FakeHttp((r) => emptyReply(r.path)),
      roles: [],
    );
    expect(find.text('Dự án nổi bật trên sàn'), findsOneWidget);
    expect(find.text('Chưa có dự án nổi bật.'), findsOneWidget);
    expect(find.byType(CompareDock), findsOneWidget);
    expect(find.text('Bảng tin mới'), findsNothing);
  });
  testWidgets('home assigned projects retain quick find and public actions', (
    tester,
  ) async {
    final env = await mount(
      tester,
      const HomeScreen(),
      FakeHttp(
        (r) => r.path == '/projects'
            ? const Reply(200, {
                'data': [
                  {
                    'id': 'p',
                    'name': 'Dự án An',
                    'code': 'P',
                    'is_public': true,
                  },
                ],
                'total': 1,
              })
            : emptyReply(r.path),
      ),
    );
    expect(find.text('Dự án của bạn'), findsOneWidget);
    expect(find.byType(CompareChip), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'An');
    await tester.pumpAndSettle();
    expect(find.text('Xem tất cả 1 kết quả'), findsOneWidget);
    env.container.read(projectCompareProvider.notifier).toggle('P');
    await tester.pumpAndSettle();
    expect(find.text('So sánh'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('home project errors offer retry', (tester) async {
    await mount(
      tester,
      const HomeScreen(),
      FakeHttp(
        (r) => r.path == '/projects' ? const Reply(403) : emptyReply(r.path),
      ),
    );
    expect(find.byType(ErrorBox), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
  testWidgets('projects free sales banner and empty state', (tester) async {
    await mount(
      tester,
      const ProjectsTab(),
      FakeHttp((r) => emptyReply(r.path)),
      roles: ['sales_free'],
    );
    expect(find.widgetWithText(AppBar, 'Dự án'), findsOneWidget);
    expect(
      find.text('Sale tự do chỉ thấy danh mục dự án công khai.'),
      findsOneWidget,
    );
    expect(
      find.text('Chưa có dự án nào được phân bổ cho bạn.'),
      findsOneWidget,
    );
  });
  testWidgets('projects errors offer retry', (tester) async {
    await mount(
      tester,
      const ProjectsTab(),
      FakeHttp(
        (r) => r.path == '/projects' ? const Reply(403) : emptyReply(r.path),
      ),
    );
    expect(find.byType(ErrorBox), findsOneWidget);
  });
  testWidgets('search waits 400ms and replaces pending edits', (tester) async {
    final http = FakeHttp((r) => emptyReply(r.path));
    await mount(tester, const SearchUnitsScreen(), http);
    expect(find.widgetWithText(AppBar, 'Tìm căn'), findsOneWidget);
    final initial = http.seen
        .where((r) => r.path == '/sales/units/search')
        .length;
    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'A12');
    await tester.pump(const Duration(milliseconds: 399));
    expect(
      http.seen.where((r) => r.path == '/sales/units/search').length,
      initial,
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    final searches = http.seen
        .where((r) => r.path == '/sales/units/search')
        .toList();
    expect(searches.length, initial + 1);
    expect(searches.last.queryParameters['q'], 'A12');
    expect(searches.last.queryParameters['per_page'], 30);
    expect(
      find.text('Không có căn phù hợp. Thử mã ngắn hơn hoặc đổi trạng thái.'),
      findsOneWidget,
    );
  });
  testWidgets('search saved filter applies, creates and deletes once', (
    tester,
  ) async {
    var saved = true;
    final http = FakeHttp((r) {
      if (r.path == '/sales/units/search/saved') {
        if (r.method == 'POST') {
          return const Reply(200, {
            'id': 's',
            'name': 'Mới',
            'params': <String, String>{},
          });
        }
        return Reply(200, {
          'data': [
            if (saved)
              {
                'id': 's',
                'name': 'Đã lưu',
                'params': {'q': 'P1', 'sort': 'price_list', 'dir': 'desc'},
              },
          ],
        });
      }
      if (r.method == 'DELETE') {
        saved = false;
        return const Reply(200);
      }
      return emptyReply(r.path);
    });
    await mount(tester, const SearchUnitsScreen(), http);
    await tester.tap(find.text('Đã lưu'));
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
    expect(
      http.seen
          .where((r) => r.path == '/sales/units/search')
          .last
          .queryParameters,
      containsPair('sort', 'price_list'),
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^Bộ lọc')));
    await tester.pumpAndSettle();
    final name = find.descendant(
      of: find.byType(Field),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(name);
    await tester.enterText(name, ' Mới ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu bộ lọc'));
    await tester.tap(find.text('Lưu bộ lọc'));
    await tester.pumpAndSettle();
    final post = http.seen.where((r) => r.method == 'POST').single;
    expect(post.data, {
      'name': 'Mới',
      'params': {'q': 'P1', 'sort': 'price_list', 'dir': 'desc'},
    });
    await tester.ensureVisible(find.text('Xoá'));
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(http.seen.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(find.text('Đã lưu'), findsNothing);
  });
  testWidgets('search tolerant row shows decimal strings and navigates', (
    tester,
  ) async {
    await mount(
      tester,
      const SearchUnitsScreen(),
      FakeHttp(
        (r) => r.path == '/sales/units/search'
            ? const Reply(200, {
                'data': [
                  {
                    'id': 'u',
                    'code': 'A1',
                    'area_net': '50.5',
                    'price_list': '400000000',
                    'status': 'available',
                  },
                ],
                'total': 1,
                'page': 1,
                'per_page': 30,
              })
            : emptyReply(r.path),
      ),
    );
    expect(find.textContaining('50.5 m²'), findsOneWidget);
    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    expect(find.text('unit u'), findsOneWidget);
  });
  testWidgets('search error has retry and debounce timer is disposed', (
    tester,
  ) async {
    final http = FakeHttp(
      (r) => r.path == '/sales/units/search'
          ? const Reply(403)
          : emptyReply(r.path),
    );
    await mount(tester, const SearchUnitsScreen(), http);
    expect(find.byType(ErrorBox), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'P');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(searchDebounce);
    expect(
      http.seen.where((r) => r.path == '/sales/units/search'),
      hasLength(1),
    );
  });
  for (final all in [false, true]) {
    testWidgets('mark notifications all=$all refreshes badge provider', (
      tester,
    ) async {
      var unread = 2;
      final http = FakeHttp((r) {
        if (r.path == '/sales/notifications/read') {
          unread = all ? 0 : 1;
          return const Reply(200, {'updated': 1});
        }
        if (r.path == '/sales/notifications') {
          return Reply(200, {
            'data': [
              {
                'id': 'n1',
                'title': 'Chính sách mới',
                'read_at': unread < 2 ? '2026-11-12' : null,
              },
              {
                'id': 'n2',
                'title': 'Tài liệu mới',
                'read_at': unread == 0 ? '2026-11-12' : null,
              },
            ],
            'unread': unread,
          });
        }
        return emptyReply(r.path);
      });
      final env = await mount(tester, const NotificationsScreen(), http);
      final subscription = env.container.listen(
        fetchNotificationsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await tester.tap(
        find.text(all ? 'Đánh dấu đã đọc tất cả' : 'Chính sách mới'),
      );
      await tester.pumpAndSettle();
      expect(
        env.container.read(fetchNotificationsProvider).value?.unread,
        all ? 0 : 1,
      );
      final post = http.seen.where((r) => r.method == 'POST').single;
      expect(
        post.data,
        all
            ? <String, Object?>{}
            : {
                'ids': ['n1'],
              },
      );
    });
  }
  testWidgets('notifications empty and error states', (tester) async {
    final http = FakeHttp((r) => emptyReply(r.path));
    final env = await mount(tester, const NotificationsScreen(), http);
    expect(find.widgetWithText(AppBar, 'Thông báo'), findsOneWidget);
    expect(find.text('Chưa có thông báo.'), findsOneWidget);
    http.respond = (_) => const Reply(403);
    env.container.invalidate(fetchNotificationsProvider);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorBox), findsOneWidget);
  });
  testWidgets('notification mark failure preserves unread state', (
    tester,
  ) async {
    final http = FakeHttp(
      (r) => r.path == '/sales/notifications/read'
          ? const Reply(403)
          : const Reply(200, {
              'data': [
                {'id': 'n', 'title': 'Tin mới'},
              ],
              'unread': 1,
            }),
    );
    final env = await mount(tester, const NotificationsScreen(), http);
    await tester.tap(find.text('Tin mới'));
    await tester.pumpAndSettle();
    expect(env.container.read(fetchNotificationsProvider).value?.unread, 1);
    expect(find.byType(Notice), findsOneWidget);
    expect(http.seen.where((r) => r.method == 'POST'), hasLength(1));
  });
  testWidgets('search pagination appends without refetching earlier pages', (
    tester,
  ) async {
    final http = FakeHttp((r) {
      if (r.path != '/sales/units/search') return emptyReply(r.path);
      final page = r.queryParameters['page'] as int;
      return Reply(200, {
        'data': [
          {'id': 'u$page', 'code': 'A$page'},
        ],
        'total': 2,
        'page': page,
        'per_page': 1,
      });
    });
    await mount(tester, const SearchUnitsScreen(), http);
    await tester.ensureVisible(find.text('Tải thêm'));
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(
      http.seen.where((r) => r.path == '/sales/units/search'),
      hasLength(2),
    );
  });
  testWidgets('failed saved-filter create keeps name and does not retry', (
    tester,
  ) async {
    final http = FakeHttp(
      (r) => r.method == 'POST' ? const Reply(403) : emptyReply(r.path),
    );
    await mount(tester, const SearchUnitsScreen(), http);
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle();
    final name = find.descendant(
      of: find.byType(Field),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Giữ tên');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu bộ lọc'));
    await tester.tap(find.text('Lưu bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Giữ tên'), findsOneWidget);
    expect(find.byType(Notice), findsOneWidget);
    expect(http.seen.where((r) => r.method == 'POST'), hasLength(1));
  });
  testWidgets('notifications fold Vietnamese search and filter unread', (
    tester,
  ) async {
    await mount(
      tester,
      const NotificationsScreen(),
      FakeHttp(
        (r) => const Reply(200, {
          'data': [
            {'id': '1', 'title': 'Chính sách mới'},
            {'id': '2', 'title': 'Đã xác nhận', 'read_at': '2026-11-12'},
          ],
          'unread': 1,
        }),
      ),
    );
    await tester.enterText(find.byType(TextField), 'chinh sach');
    await tester.pumpAndSettle();
    expect(find.text('Chính sách mới'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa đọc · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Chính sách mới'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsNothing);
  });
  testWidgets('survey submits exact answers and disappears after refetch', (
    tester,
  ) async {
    var due = true;
    final http = FakeHttp((r) {
      if (r.path == '/sales/survey') {
        if (r.method == 'POST') due = false;
        return Reply(200, {
          'data': {'due': due},
        });
      }
      return emptyReply(r.path);
    });
    await mount(tester, const HomeScreen(), http, roles: []);
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('Có'));
    await tester.tap(find.text('Có'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi'));
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(http.seen.where((r) => r.method == 'POST').single.data, {
      'ease_score': 5,
      'would_refer': true,
    });
    expect(find.text('Góp ý nhanh'), findsNothing);
  });
  testWidgets('survey user-data provider drops previous session data', (
    tester,
  ) async {
    final env = await mount(
      tester,
      const HomeScreen(),
      FakeHttp(
        (r) => r.path == '/sales/survey'
            ? const Reply(200, {
                'data': {'due': true},
              })
            : emptyReply(r.path),
      ),
      roles: [],
    );
    expect(env.container.read(tabSurveyProvider).value, true);
    env.session.end();
    await tester.pumpAndSettle();
    expect(env.container.read(tabSurveyProvider).value, isNull);
    expect(find.text('Góp ý nhanh'), findsNothing);
  });
  testWidgets('home favourite reuses the saved-project command', (
    tester,
  ) async {
    final http = FakeHttp((r) {
      if (r.path == '/projects') {
        return const Reply(200, {
          'data': [
            {'id': 'p', 'code': 'P', 'name': 'Dự án An', 'is_public': true},
          ],
          'total': 1,
        });
      }
      if (r.path == '/me/saved-projects') {
        return Reply(200, {
          'codes': r.method == 'POST' ? ['P'] : <String>[],
        });
      }
      return emptyReply(r.path);
    });
    final env = await mount(tester, const HomeScreen(), http);
    await tester.tap(find.bySemanticsLabel('Yêu thích Dự án An'));
    await tester.pumpAndSettle();
    expect(env.container.read(savedProjectsProvider).value, ['P']);
    expect(http.seen.where((r) => r.method == 'POST').single.data, {
      'codes': ['P'],
    });
  });
}
