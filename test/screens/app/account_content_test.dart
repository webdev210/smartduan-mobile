import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/screens/app/account_routes.dart';
import 'package:smartduan/screens/app/become_sales.dart';
import 'package:smartduan/screens/app/consult.dart';
import 'package:smartduan/screens/app/interests.dart';
import 'package:smartduan/screens/app/profile.dart';
import 'package:smartduan/screens/app/process_page.dart';
import 'package:smartduan/screens/app/team.dart';
import 'package:smartduan/screens/app/announcement.dart';
import 'package:smartduan/screens/app/announcements.dart';
import 'package:smartduan/screens/app/process_pages.dart';
import 'package:smartduan/screens/app/saved_projects.dart';
import 'package:smartduan/ui/favorite_button.dart';
import 'package:smartduan/ui/post_body.dart';
import 'package:smartduan/ui/project_browser.dart';
import 'package:smartduan/ui/kit.dart' show Button;
import 'package:smartduan/ui/kit.dart' as kit;

import '../../api/fake_http.dart';
import '../../auth/token_store_test.dart' show MemoryStorage;

class KSession extends Session {
  KSession(this.me);
  final Map<String, dynamic> me;
  int refreshed = 0;
  Map<String, dynamic>? nextMe;
  final signOuts = <bool>[];
  @override
  SessionState build() => SessionState(SessionStatus.signedIn, me: me);
  @override
  Future<void> refreshMe() async {
    refreshed++;
    if (nextMe != null) {
      state = SessionState(SessionStatus.signedIn, me: nextMe);
    }
  }

  @override
  Future<void> signOut({bool everywhere = false}) async {
    signOuts.add(everywhere);
  }
}

class KEnv {
  KEnv({
    Map<String, dynamic> me = const {
      'roles': ['agent'],
    },
  }) {
    session = KSession(me);
    http = FakeHttp((r) {
      if (r.path == '/sales/profile') {
        return const Reply(200, {
          'id': 'me',
          'email': 'a@b.vn',
          'full_name': 'Nguyễn An',
        });
      }
      if (r.path == '/me/devices') {
        return const Reply(200, {
          'data': [
            {'id': 'd', 'label': 'Máy của tôi', 'status': 'approved'},
          ],
        });
      }
      if (r.path == '/sales/profile/downloads') {
        return const Reply(200, {
          'data': [
            {'id': 'dl', 'document_title': 'Tài liệu mẫu'},
          ],
        });
      }
      if (r.path == '/sales/managers') {
        return const Reply(200, {
          'data': [
            {
              'id': 'm',
              'full_name': 'Quản lý An',
              'sales_unit': {'id': 's', 'name': 'Đại lý A'},
            },
          ],
        });
      }
      if (r.path == '/process-pages/demo') {
        return const Reply(200, {
          'id': 'p',
          'slug': 'demo',
          'title': 'Quy trình mẫu',
          'status': 'rejected',
        });
      }
      if (r.path == '/projects') {
        return const Reply(200, {
          'data': [
            {'id': 'p', 'code': 'P', 'name': 'Dự án mẫu'},
          ],
          'total': 1,
        });
      }
      return const Reply(200, {'data': <Object?>[], 'codes': <Object?>[]});
    });
    client = ApiClient(
      adapter: http,
      tokens: SecureValue('k', storage: MemoryStorage()),
    );
    container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => session),
        apiClientProvider.overrideWithValue(client),
      ],
      retry: (_, _) => null,
    );
    addTearDown(client.close);
    addTearDown(container.dispose);
  }
  late final KSession session;
  late final FakeHttp http;
  late final ApiClient client;
  late final ProviderContainer container;
  Future<void> mount(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        GoRoute(
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('Back')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
  }
}

Future<void> press(WidgetTester t, String title) async {
  final f = find.widgetWithText(Button, title);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('manager lookup error retries visibly and preserves form input', (
    t,
  ) async {
    final e = KEnv(
      me: {
        'roles': ['sales_free'],
      },
    );
    final original = e.http.respond;
    e.http.respond = (r) => r.path == '/sales/managers'
        ? const Reply(503, {'message': 'Lookup failed'})
        : original(r);
    await e.mount(t, const BecomeSalesScreen());
    expect(find.text('Lookup failed'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Name kept');
    final pending = Completer<Reply>();
    e.http.respond = (r) =>
        r.path == '/sales/managers' ? pending.future : original(r);
    await t.tap(find.text('Thử lại'));
    await t.pump();
    expect(find.byType(kit.Loading), findsOneWidget);
    expect(find.text('Name kept'), findsOneWidget);
    pending.complete(
      const Reply(200, {
        'data': [
          {'id': 'm', 'full_name': 'Manager'},
        ],
      }),
    );
    await t.pumpAndSettle();
    await press(t, 'Chọn quản lý');
    expect(find.text('Manager'), findsOneWidget);
    await t.tap(find.text('Manager'));
    await t.pumpAndSettle();
    expect(find.text('Name kept'), findsOneWidget);
  });
  testWidgets(
    'interest card without metadata is compact and vertically centred',
    (t) async {
      final e = KEnv();
      e.http.respond = (_) => const Reply(200, {
        'data': [
          {'id': 'a', 'code': 'A', 'name': 'The Global City'},
          {
            'id': 'b',
            'code': 'B',
            'name': 'With location',
            'province': 'Hồ Chí Minh',
          },
        ],
        'total': 2,
      });
      await e.mount(t, const InterestsScreen());
      final title = find.text('The Global City');
      final compact = t.getRect(
        find.ancestor(of: title, matching: find.byType(kit.Card)),
      );
      final full = t.getRect(
        find.ancestor(
          of: find.text('With location'),
          matching: find.byType(kit.Card),
        ),
      );
      expect(compact.height, lessThan(full.height));
      expect(t.getCenter(title).dy, compact.center.dy);
      expect(
        find.descendant(
          of: find.ancestor(of: title, matching: find.byType(kit.Card)),
          matching: find.byType(kit.Muted),
        ),
        findsNothing,
      );
      await t.enterText(find.byType(TextField), 'khongkhop');
      await t.pumpAndSettle();
      expect(find.byIcon(Ionicons.searchOutline), findsOneWidget);
    },
  );
  testWidgets('profile translates device status without exposing raw status', (
    t,
  ) async {
    final e = KEnv();
    await e.mount(t, const ProfileScreen());
    expect(find.textContaining('Đã duyệt · lần cuối'), findsOneWidget);
    expect(find.textContaining('approved'), findsNothing);
  });
  testWidgets('team date and time stay in one unbreakable run', (t) async {
    final e = KEnv(
      me: {
        'roles': ['manager'],
      },
    );
    final original = e.http.respond;
    e.http.respond = (r) => r.path == '/sales/team'
        ? const Reply(200, {
            'data': [
              {
                'id': 'm',
                'full_name': 'Nguyễn An',
                'status': 'active',
                'last_login_at': '2026-11-13T00:02:00',
              },
            ],
          })
        : original(r);
    await e.mount(t, const TeamScreen());
    expect(
      find.text('Đăng nhập gần nhất: 00:02\u00a013/11/2026'),
      findsOneWidget,
    );
  });
  testWidgets('refresh me changes free sales into the F2 request flow', (
    t,
  ) async {
    final e = KEnv(
      me: {'roles': <String>[], 'phone_verified_at': '2026-11-13'},
    );
    e.session.nextMe = {
      'roles': ['sales_free'],
    };
    await e.mount(t, const BecomeSalesScreen());
    await press(t, 'Đăng ký làm sale');
    expect(find.text('Bước 2: Xin xác nhận F2'), findsOneWidget);
    expect(e.session.refreshed, 1);
  });
  testWidgets('F2 success refreshes the pending request state', (t) async {
    final e = KEnv(
      me: {
        'roles': ['sales_free'],
        'full_name': 'Nguyễn An',
        'address': 'Hà Nội',
        'referred_manager_id': 'm',
      },
    );
    e.session.nextMe = {
      'roles': ['sales_free'],
      'f2_requested_at': '2026-11-12',
      'requested_sales_unit_name': 'Đại lý A',
    };
    await e.mount(t, const BecomeSalesScreen());
    await press(t, 'Gửi yêu cầu F2');
    expect(find.text('Đang chờ duyệt F2'), findsOneWidget);
    expect(find.text('Gửi yêu cầu F2'), findsNothing);
  });
  testWidgets('profile downloads and logout confirmations', (t) async {
    final e = KEnv();
    await e.mount(t, const ProfileScreen());
    expect(find.text('Tài liệu mẫu'), findsOneWidget);
    await press(t, 'Đăng xuất mọi thiết bị');
    expect(e.session.signOuts, isEmpty);
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(e.session.signOuts, isEmpty);
    await press(t, 'Đăng xuất mọi thiết bị');
    await t.tap(find.text('Đăng xuất hết'));
    await t.pumpAndSettle();
    expect(e.session.signOuts, [true]);
    await press(t, 'Đăng xuất');
    expect(e.session.signOuts, [true, false]);
  });
  testWidgets('interests without project permission never fetches projects', (
    t,
  ) async {
    final e = KEnv(
      me: {
        'roles': <String>[],
        'region': 'bac',
        'interested_project_ids': List.generate(51, (i) => '$i'),
      },
    );
    await e.mount(t, const InterestsScreen());
    expect(e.http.seen.where((r) => r.path == '/projects'), isEmpty);
    expect(
      t.widget<Button>(find.widgetWithText(Button, 'Lưu')).disabled,
      isTrue,
    );
  });
  for (final status in ['pending', 'approved']) {
    testWidgets('process $status cannot request access again', (t) async {
      final e = KEnv();
      e.http.respond = (_) => Reply(200, {
        'id': 'p',
        'slug': 'demo',
        'title': 'Quy trình mẫu',
        'status': status,
      });
      await e.mount(t, const ProcessPageScreen(slug: 'demo'));
      expect(find.text('Xin quyền truy cập'), findsNothing);
      expect(
        find.text('Xem nội dung đầy đủ của trang này trên web Smart Dự Án.'),
        findsOneWidget,
      );
    });
  }
  testWidgets(
    'saved projects loads public cards with FavoriteButton and unavailable count',
    (t) async {
      final e = KEnv();
      final original = e.http.respond;
      e.http.respond = (r) => switch (r.path) {
        '/me/saved-projects' => const Reply(200, {
          'codes': ['P', 'gone'],
        }),
        '/public/projects/P' => const Reply(200, {
          'id': 'p',
          'code': 'P',
          'name': 'Dự án mẫu',
        }),
        '/public/projects/gone' => const Reply(404, {
          'error': 'not_found',
          'message': 'Đã ẩn',
        }),
        _ => original(r),
      };
      await e.mount(t, const SavedProjectsScreen());
      // Public queries start only after the saved codes rebuild this screen.
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      await t.pumpAndSettle();
      expect(e.http.seen.map((r) => r.path), contains('/public/projects/P'));
      expect(find.text('Dự án yêu thích'), findsOneWidget);
      expect(e.container.read(savedProjectsProvider).value, ['P', 'gone']);
      expect(
        t
            .widget<ProjectBrowser>(find.byType(ProjectBrowser))
            .projects
            ?.map((p) => p.name),
        ['Dự án mẫu'],
      );
      expect(find.text('1 dự án hiện không còn công khai.'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Dự án mẫu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dự án mẫu'), findsOneWidget);
      expect(find.byType(FavoriteButton), findsOneWidget);
    },
  );
  testWidgets('saved projects empty guidance', (t) async {
    final e = KEnv();
    await e.mount(t, const SavedProjectsScreen());
    expect(
      find.text(
        'Chưa có dự án yêu thích. Bấm trái tim trên thẻ hoặc trang dự án để thêm.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('announcement detail renders HTML through PostBody', (t) async {
    final e = KEnv();
    e.http.respond = (_) => const Reply(200, {
      'data': {
        'id': 'a',
        'title': 'Thông tin mới',
        'body': '<h2>Tiêu đề</h2><p>Nội dung &amp; thông báo</p>',
      },
    });
    await e.mount(t, const AnnouncementScreen(id: 'a'));
    expect(find.byType(PostBody), findsOneWidget);
    expect(find.text('Tiêu đề'), findsOneWidget);
    expect(find.text('Nội dung & thông báo'), findsOneWidget);
  });
  testWidgets(
    'announcement pagination keeps loaded data on failure and resets on session change',
    (t) async {
      final e = KEnv();
      var secondFails = true;
      e.http.respond = (r) {
        final page = int.parse('${r.queryParameters['page']}');
        if (page == 2 && secondFails) {
          return const Reply(503, {
            'error': 'server_error',
            'message': 'Không tải được trang sau',
          });
        }
        return Reply(200, {
          'data': [
            {'id': '$page', 'title': 'Tin số $page'},
          ],
          'page': page,
          'per_page': 1,
          'total': 2,
        });
      };
      await e.mount(t, const AnnouncementsScreen());
      await t.enterText(find.byType(TextField), 'Tin');
      await t.pumpAndSettle();
      expect(
        find.text('Đang tìm trong 1 tin đã tải — bấm “Tải thêm” để tìm tiếp.'),
        findsOneWidget,
      );
      await press(t, 'Tải thêm');
      expect(find.text('Tin số 1'), findsOneWidget);
      expect(find.text('Không tải được trang sau'), findsOneWidget);
      secondFails = false;
      await press(t, 'Thử lại');
      expect(find.text('Tin số 1'), findsOneWidget);
      expect(find.text('Tin số 2'), findsOneWidget);
      e.session.nextMe = {
        'roles': ['agent'],
        'id': 'other',
      };
      await e.session.refreshMe();
      await t.pumpAndSettle();
      expect(find.text('Tin số 2'), findsNothing);
    },
  );
  testWidgets('process pages search and project scope retain metadata', (
    t,
  ) async {
    final e = KEnv();
    e.http.respond = (_) => const Reply(200, {
      'data': [
        {'id': '1', 'slug': 'chung', 'title': 'Đào tạo chung'},
        {
          'id': '2',
          'slug': 'mau',
          'title': 'Quy trình mẫu',
          'project_name': 'Dự án A',
        },
      ],
    });
    await e.mount(t, const ProcessPagesScreen());
    await t.tap(find.text('Dự án A'));
    await t.pumpAndSettle();
    expect(find.text('Đào tạo chung'), findsNothing);
    expect(find.text('Quy trình mẫu'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'khongkhop');
    await t.pumpAndSettle();
    expect(find.text('Không có trang nào khớp.'), findsOneWidget);
  });
  test('all ten account routes are registered', () {
    expect(appAccountScreens.keys.toSet(), {
      '/ho-so',
      '/da-luu',
      '/quan-tam',
      '/doi-cua-toi',
      '/len-sale',
      '/tu-van',
      '/quy-trinh',
      '/quy-trinh/:slug',
      '/bang-tin',
      '/bang-tin/:id',
    });
  });
  for (final result in ['success', 'failure', 'unknown']) {
    testWidgets('consult $result sends once and preserves input', (t) async {
      final e = KEnv();
      var calls = 0;
      final original = e.http.respond;
      e.http.respond = (r) {
        if (r.path == '/sales/consult') {
          calls++;
          expect(r.data, {
            'consent': true,
            'project_id': 'p',
            'message': 'Tư vấn giúp tôi',
          });
          return switch (result) {
            'success' => const Reply(200, {'ok': true}),
            'unknown' => const Reply(503, {
              'error': 'lead_delivery_unknown',
              'message': 'unknown',
            }),
            _ => const Reply(422, {
              'error': 'invalid',
              'message': 'Không gửi được',
            }),
          };
        }
        return original(r);
      };
      await e.mount(t, const ConsultScreen(projectId: 'p', name: 'Dự án mẫu'));
      expect(
        t.widget<Button>(find.widgetWithText(Button, 'Gửi')).disabled,
        isTrue,
      );
      await t.enterText(find.byType(TextField), 'Tư vấn giúp tôi');
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await press(t, 'Gửi');
      await t.pump(const Duration(seconds: 30));
      expect(calls, 1);
      expect(find.text('Tư vấn giúp tôi'), findsOneWidget);
      expect(
        find.text(switch (result) {
          'success' => 'Đã gửi yêu cầu. Sàn sẽ liên hệ bạn sớm.',
          'unknown' => 'Chưa chắc yêu cầu đã tới sàn. Đừng gửi lại ngay — gọi hotline để xác nhận.',
          _ => 'Không gửi được',
        }),
        findsOneWidget,
      );
      expect(
        t.widget<Button>(find.widgetWithText(Button, 'Gửi')).disabled,
        result != 'failure',
      );
    });
  }
  for (final success in [true, false]) {
    testWidgets(
      'process access ${success ? 'success reloads' : 'cooldown preserves backend message'}',
      (t) async {
        final e = KEnv();
        final original = e.http.respond;
        var writes = 0, reads = 0;
        e.http.respond = (r) {
          if (r.path == '/process-pages/demo') reads++;
          if (r.path == '/process-pages/demo/request') {
            writes++;
            return success
                ? const Reply(200, {'status': 'pending'})
                : const Reply(429, {
                    'error': 'cooldown',
                    'message': 'Vui lòng chờ 24 giờ trước khi xin lại.',
                  });
          }
          return original(r);
        };
        await e.mount(t, const ProcessPageScreen(slug: 'demo'));
        await press(t, 'Xin quyền truy cập');
        expect(writes, 1);
        if (success) {
          expect(reads, 2);
        } else {
          expect(
            find.text('Vui lòng chờ 24 giờ trước khi xin lại.'),
            findsOneWidget,
          );
        }
      },
    );
  }
  for (final roles in [
    <String>[],
    ['agent'],
    ['manager'],
  ]) {
    testWidgets('team gate $roles', (t) async {
      final e = KEnv(me: {'roles': roles});
      await e.mount(t, const TeamScreen());
      expect(
        e.http.seen.where((r) => r.path == '/sales/team').length,
        roles.contains('manager') ? 1 : 0,
      );
    });
  }
  testWidgets('F2 partner and pending states', (t) async {
    final e = KEnv(
      me: {
        'roles': ['sales_partner'],
      },
    );
    await e.mount(t, const BecomeSalesScreen());
    expect(find.text('Bạn đã là đại lý F2.'), findsOneWidget);
    expect(e.http.seen, isEmpty);
  });
  for (final success in [true, false]) {
    testWidgets('become sales mutation $success', (t) async {
      final e = KEnv(
        me: {'roles': <String>[], 'phone_verified_at': '2026-11-13'},
      );
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/sales/become-sales'
          ? (success
                ? const Reply(200, {
                    'roles': ['sales_free'],
                  })
                : const Reply(403, {
                    'error': 'phone_not_verified',
                    'message': 'Chưa xác thực điện thoại',
                  }))
          : original(r);
      await e.mount(t, const BecomeSalesScreen());
      await press(t, 'Đăng ký làm sale');
      expect(e.session.refreshed, success ? 1 : 0);
      expect(
        find.text(
          success
              ? 'Đã thành sale tự do. Nếu app báo phiên hết hạn, hãy đăng nhập lại để dùng quyền mới.'
              : 'Chưa xác thực điện thoại',
        ),
        findsOneWidget,
      );
    });
    testWidgets('F2 request mutation $success', (t) async {
      final e = KEnv(
        me: {
          'roles': ['sales_free'],
          'full_name': 'Nguyễn An',
          'address': 'Hà Nội',
          'referred_manager_id': 'm',
        },
      );
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/sales/request-f2'
          ? (success
                ? const Reply(200, {'f2_requested_at': '2026-11-12'})
                : const Reply(422, {
                    'error': 'invalid',
                    'message': 'Không gửi được F2',
                  }))
          : original(r);
      await e.mount(t, const BecomeSalesScreen());
      await press(t, 'Gửi yêu cầu F2');
      expect(e.session.refreshed, success ? 1 : 0);
      if (!success) expect(find.text('Không gửi được F2'), findsOneWidget);
    });
    testWidgets('remove own device $success', (t) async {
      final e = KEnv();
      final original = e.http.respond;
      var removes = 0;
      e.http.respond = (r) {
        if (r.path == '/me/devices/d') {
          removes++;
          return success
              ? const Reply(200, {})
              : const Reply(422, {
                  'error': 'invalid',
                  'message': 'Không gỡ được',
                });
        }
        return original(r);
      };
      await e.mount(t, const ProfileScreen());
      expect(find.text('Nguyễn An'), findsOneWidget);
      await press(t, 'Gỡ');
      expect(removes, 0);
      await t.tap(find.widgetWithText(TextButton, 'Gỡ'));
      await t.pumpAndSettle();
      expect(removes, 1);
      if (!success) expect(find.text('Không gỡ được'), findsOneWidget);
    });
    testWidgets('save interests $success', (t) async {
      final e = KEnv();
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/sales/interests'
          ? (success
                ? const Reply(200, {
                    'region': 'bac',
                    'interested_project_ids': <String>[],
                  })
                : const Reply(422, {
                    'error': 'invalid',
                    'message': 'Không lưu được',
                  }))
          : original(r);
      await e.mount(t, const InterestsScreen());
      expect(
        t.widget<Button>(find.widgetWithText(Button, 'Lưu')).disabled,
        isTrue,
      );
      await t.tap(find.text('Miền Bắc'));
      await t.pumpAndSettle();
      await press(t, 'Lưu');
      expect(e.session.refreshed, success ? 1 : 0);
      if (!success) expect(find.text('Không lưu được'), findsOneWidget);
    });
  }
}
