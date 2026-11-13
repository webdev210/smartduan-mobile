import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/screens/app/approve_accounts.dart';
import 'package:smartduan/screens/app/approve_devices.dart';
import 'package:smartduan/screens/app/become_sales.dart';
import 'package:smartduan/screens/app/consult.dart';
import 'package:smartduan/screens/app/compare_units.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/app/interests.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/screens/app/process_page.dart';
import 'package:smartduan/screens/app/profile.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/app/project_history.dart';
import 'package:smartduan/screens/app/reports.dart';
import 'package:smartduan/screens/app/saved_projects.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/share_links.dart';
import 'package:smartduan/screens/app/team.dart';
import 'package:smartduan/screens/app/top_units.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/project_card.dart';

import 'account_content_test.dart' show KEnv;
import 'presentation_test.dart' show board, plan;
import 'task_h_fakes.dart';
import '../../realtime/fakes.dart' show BoardSocket;

Future<void> mountInventory(WidgetTester t, HEnv e, Widget child) async {
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => e.session),
        apiClientProvider.overrideWithValue(e.client),
        inventorySocketProvider('p').overrideWithValue(BoardSocket()),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String text) async {
  final finder = find.text(text);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  test('10 history translates and formats changed fields', () {
    expect(historyValue('price_list', '1500000000'), '1,5 tỷ');
    expect(
      historyValue('reserved_until', '2026-11-14T00:00:00Z'),
      '07:00 14/11/2026',
    );
    expect(historyValue('status', 'sold'), 'Đã bán');
    expect(historyValue('unknown', 'future'), 'future');
    expect(historyValue('status', null), '—');
    expect(historyValue('fund', 'F2', {'F2': 'Quỹ đại lý'}), 'Quỹ đại lý');
  });

  testWidgets('1 saved network failures remain saved and retry their project', (
    t,
  ) async {
    final e = KEnv();
    var fail = true;
    final original = e.http.respond;
    e.http.respond = (r) => switch (r.path) {
      '/me/saved-projects' => const Reply(200, {
        'codes': ['P', 'gone'],
      }),
      '/public/projects/P' =>
        fail ? const Reply(503) : const Reply(200, hProject),
      '/public/projects/gone' => const Reply(404),
      _ => original(r),
    };
    await e.mount(t, const SavedProjectsScreen());
    await t.pumpAndSettle();
    expect(find.textContaining('Chưa tải được 1 dự án'), findsOneWidget);
    expect(find.text('1 dự án hiện không còn công khai.'), findsOneWidget);
    fail = false;
    await tap(t, 'Thử lại dự án lỗi');
    expect(
      e.http.seen.where((r) => r.path == '/public/projects/P'),
      hasLength(2),
    );
    expect(find.textContaining('Chưa tải được'), findsNothing);
    expect(e.http.seen.where((r) => r.method == 'DELETE'), isEmpty);
  });

  testWidgets('3 contacts error retries only on an explicit tap', (t) async {
    final e = HEnv();
    var fail = true;
    e.http.respond = (r) => r.path.endsWith('/contacts') && fail
        ? const Reply(503, {'message': 'Lỗi đầu mối'})
        : hReply(r.path);
    expect(projectContactsProvider('p').retry, isNotNull);
    expect(projectContactsProvider('p').retry!(1, Exception()), isNull);
    await e.mount(t, const ProjectScreen(id: 'p'));
    expect(find.text('Lỗi đầu mối'), findsOneWidget);
    await t.pump(const Duration(seconds: 20));
    expect(
      e.http.seen.where((r) => r.path.endsWith('/contacts')),
      hasLength(1),
    );
    final refresh = t.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    final refreshed = refresh.onRefresh();
    await t.pumpAndSettle();
    await refreshed;
    expect(
      e.http.seen.where((r) => r.path.endsWith('/contacts')),
      hasLength(1),
    );
    fail = false;
    await tap(t, 'Thử lại');
    expect(
      e.http.seen.where((r) => r.path.endsWith('/contacts')),
      hasLength(2),
    );
  });

  testWidgets(
    '4 saved filter confirmation names the filter and cancel keeps it',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path == '/sales/units/search/saved'
          ? const Reply(200, {
              'data': [
                {
                  'id': 'f',
                  'name': 'Căn hướng Đông',
                  'params': <String, String>{},
                },
              ],
            })
          : hReply(r.path);
      await e.mount(t, const SearchUnitsScreen());
      await t.tap(find.bySemanticsLabel(RegExp('^Bộ lọc')));
      await t.pumpAndSettle();
      await tap(t, 'Xoá');
      expect(find.text('Xoá bộ lọc “Căn hướng Đông”?'), findsOneWidget);
      expect(e.http.seen.where((r) => r.method == 'DELETE'), isEmpty);
      await tap(t, 'Huỷ');
      expect(e.http.seen.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('Căn hướng Đông'), findsWidgets);
    },
  );

  testWidgets('5 back confirms dirty selections and saving stays explicit', (
    t,
  ) async {
    final e = KEnv(me: {'roles': <String>[], 'region': 'south'});
    final router = GoRouter(
      initialLocation: '/interests',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Trang trước')),
          routes: [
            GoRoute(
              path: 'interests',
              builder: (_, _) => const InterestsScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: e.container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Miền Bắc'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    await tap(t, 'Ở lại');
    expect(find.byType(InterestsScreen), findsOneWidget);
    expect(e.http.seen.where((r) => r.method != 'GET'), isEmpty);
    await t.pageBack();
    await t.pumpAndSettle();
    await tap(t, 'Bỏ thay đổi');
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('8 unit history discloses all loaded rows and the server count', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/units/u/history'
        ? Reply(200, {
            'data': List.generate(
              20,
              (i) => {
                'id': '$i',
                'field': 'status',
                'old_value': 'available',
                'new_value': 'sold',
                'changed_at': '2026-11-${i + 1}',
              },
            ),
            'total': 70,
          })
        : hReply(r.path);
    await e.mount(t, const UnitScreen(id: 'u'));
    await t.scrollUntilVisible(
      find.text('Xem thêm (5)'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hiển thị 15/70 thay đổi gần nhất'), findsOneWidget);
    await tap(t, 'Xem thêm (5)');
    expect(find.text('Hiển thị 20/70 thay đổi gần nhất'), findsOneWidget);
    expect(find.textContaining('20/11/2026 · Trạng thái:'), findsOneWidget);
  });

  testWidgets(
    '8 project history appends the next page without repeating page one',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path == '/projects/p/units/history'
          ? Reply(200, {
              'data': [
                {
                  'id': '${r.queryParameters['page']}',
                  'unit_id': 'u',
                  'field': 'status',
                  'old_value': 'available',
                  'new_value': 'sold',
                  'source': 'Trang ${r.queryParameters['page']}',
                },
              ],
              'page': r.queryParameters['page'],
              'per_page': 1,
              'total': 2,
            })
          : hReply(r.path);
      await mountInventory(t, e, const ProjectHistoryScreen(projectId: 'p'));
      await tap(t, 'Tải thêm');
      expect(find.textContaining('Trang 1'), findsOneWidget);
      expect(find.textContaining('Trang 2'), findsOneWidget);
      expect(find.text('2/2 thay đổi gần nhất'), findsOneWidget);
      expect(
        e.http.seen.where((r) => r.path.endsWith('/history')),
        hasLength(2),
      );
      expect(find.text('Tải thêm'), findsNothing);
    },
  );

  testWidgets('9 selecting another tower removes the previous unit detail', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.path.endsWith('/presentation-board')
        ? const Reply(200, board)
        : r.path.endsWith('/stack-plan')
        ? const Reply(200, plan)
        : r.path.endsWith('/units/u/detail')
        ? const Reply(200, {'id': 'u', 'code': 'Selected'})
        : hReply(r.path);
    await e.mount(t, const PresentationScreen(projectId: 'p'));
    await tap(t, 'A101');
    expect(find.text('Căn Selected'), findsOneWidget);
    await tap(t, 'Toà B');
    expect(find.text('Căn Selected'), findsNothing);
  });

  testWidgets('11 unit directions use the Vietnamese enum label', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/units/u/detail'
        ? const Reply(200, {...hUnit, 'direction': 'E'})
        : r.path == '/inventory/enums'
        ? const Reply(200, {
            'direction_labels': {'E': 'Đông'},
          })
        : hReply(r.path);
    await e.mount(t, const UnitScreen(id: 'u'));
    await t.scrollUntilVisible(
      find.text('Đông'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('E'), findsNothing);
  });

  testWidgets(
    '11 comparison directions translate known codes and retain unknown codes',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path == '/sales/me/compare'
          ? const Reply(200, {
              'units': [
                {...hUnit, 'direction': 'E'},
                {'id': 'v', 'code': 'B', 'direction': 'future'},
              ],
              'removed': <Object?>[],
            })
          : r.path == '/inventory/enums'
          ? const Reply(200, {
              'direction_labels': {'E': 'Đông'},
            })
          : hReply(r.path);
      await e.mount(t, const CompareUnitsScreen());
      expect(find.text('Đông'), findsOneWidget);
      expect(find.text('future'), findsOneWidget);
    },
  );

  testWidgets('10 report status changes have translated values and context', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/reports/recent_activity'
        ? const Reply(200, {
            'data': [
              {
                'unit_id': 'u',
                'unit_code': 'A101',
                'project': 'Mẫu',
                'old_value': 'reserved',
                'new_value': 'sold',
              },
            ],
          })
        : hReply(r.path);
    await e.mount(t, const ReportsScreen());
    expect(find.text('A101 · Mẫu · Trạng thái'), findsOneWidget);
    expect(find.textContaining('Đang giữ → Đã bán'), findsOneWidget);
  });

  testWidgets('19 long team names wrap with the status below the identity', (
    t,
  ) async {
    final e = KEnv(
      me: {
        'roles': ['manager'],
      },
    );
    const name = 'Nguyễn Thị Hồng Ánh với tên đầy đủ rất dài';
    final original = e.http.respond;
    e.http.respond = (r) => r.path == '/sales/team'
        ? const Reply(200, {
            'data': [
              {'id': 'm', 'full_name': name, 'status': 'active'},
            ],
          })
        : original(r);
    await e.mount(t, const TeamScreen());
    t.view.physicalSize = const Size(320, 900);
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.text(name)).maxLines, isNull);
    expect(
      t.getTopLeft(find.text('Hoạt động').last).dy,
      greaterThan(t.getBottomLeft(find.text(name)).dy),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('21 search semantics include price area project and direction', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/sales/units/search'
        ? const Reply(200, {
            'data': [
              {
                ...hUnit,
                'direction': 'E',
                'project': {'id': 'p', 'name': 'Dự án mẫu'},
              },
            ],
            'total': 1,
          })
        : r.path == '/inventory/enums'
        ? const Reply(200, {
            'direction_labels': {'E': 'Đông'},
          })
        : hReply(r.path);
    await e.mount(t, const SearchUnitsScreen());
    expect(
      find.bySemanticsLabel(
        RegExp('Căn P-A101.*Dự án mẫu.*50.5 m².*Đông.*400 tr'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '28 supporting enum and saved-filter failures offer explicit recovery',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path == '/inventory/enums'
          ? const Reply(503, {'message': 'Lỗi hướng'})
          : r.path == '/sales/units/search/saved'
          ? const Reply(503, {'message': 'Lỗi bộ lọc'})
          : hReply(r.path);
      await e.mount(t, const SearchUnitsScreen());
      expect(find.text('Lỗi hướng'), findsOneWidget);
      expect(find.text('Lỗi bộ lọc'), findsOneWidget);
      expect(find.text('Thử lại'), findsNWidgets(2));
      e.http.respond = (r) => hReply(r.path);
      await t.tap(find.text('Thử lại').first);
      await t.pumpAndSettle();
      expect(
        e.http.seen.where((r) => r.path == '/inventory/enums'),
        hasLength(2),
      );
    },
  );

  testWidgets('28 board enum failure can be retried without losing the board', (
    t,
  ) async {
    final e = HEnv();
    var fail = true;
    e.http.respond = (r) => r.path == '/inventory/enums' && fail
        ? const Reply(503, {'message': 'Lỗi nhãn bộ lọc'})
        : hReply(r.path);
    await mountInventory(t, e, const BoardScreen(projectId: 'p'));
    expect(find.text('Lỗi nhãn bộ lọc'), findsOneWidget);
    fail = false;
    await tap(t, 'Thử lại');
    expect(
      e.http.seen.where((r) => r.path == '/inventory/enums'),
      hasLength(2),
    );
  });

  testWidgets(
    '30 branch failures retry and an empty manager list explains recovery',
    (t) async {
      final e = KEnv(me: {'roles': <String>[]});
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/branches'
          ? const Reply(503, {'message': 'Lỗi chi nhánh'})
          : original(r);
      await e.mount(t, const BecomeSalesScreen());
      await tap(t, 'Thử lại');
      expect(e.http.seen.where((r) => r.path == '/branches'), hasLength(2));
      await t.pumpWidget(const SizedBox.shrink());
      final f2 = KEnv(
        me: {
          'roles': ['sales_free'],
        },
      );
      final f2Original = f2.http.respond;
      f2.http.respond = (r) => r.path == '/sales/managers'
          ? const Reply(200, {'data': <Object?>[]})
          : f2Original(r);
      await f2.mount(t, const BecomeSalesScreen());
      expect(
        find.textContaining('Chưa có quản lý đại lý để chọn.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('31 temporary access picks a date between today and 90 days', (
    t,
  ) async {
    final e = HEnv(roles: ['superadmin']);
    e.http.respond = (_) => const Reply(200, {
      'data': [
        {'id': 'd', 'status': 'approved', 'kind': 'mobile'},
      ],
    });
    await e.mount(t, const ApproveDevicesScreen());
    await tap(t, 'Cho thêm tạm thời đến…');
    await tap(t, 'Chọn ngày hết hạn (tối đa 90 ngày)');
    final picker = t.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    final today = DateUtils.dateOnly(DateTime.now());
    expect(picker.firstDate, today);
    expect(picker.lastDate, today.add(const Duration(days: 90)));
    await tap(t, 'Huỷ');
    expect(e.http.seen.where((r) => r.method != 'GET'), isEmpty);
  });

  for (final status in ['approved', 'pending', 'rejected']) {
    testWidgets('32 website button respects the $status process gate', (
      t,
    ) async {
      final e = KEnv();
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/process-pages/demo'
          ? Reply(200, {
              'id': 'p',
              'slug': 'demo',
              'title': 'Quy trình mẫu',
              'status': status,
            })
          : original(r);
      await e.mount(t, const ProcessPageScreen(slug: 'demo'));
      expect(find.text('Quy trình mẫu'), findsNWidgets(2));
      expect(
        find.text('Mở Smart Dự Án'),
        status == 'approved' ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets(
    '32 approved process opens only the configured site root externally',
    (t) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final e = KEnv();
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/process-pages/demo'
          ? const Reply(200, {
              'id': 'p',
              'slug': 'demo',
              'title': 'Quy trình mẫu',
              'status': 'approved',
            })
          : original(r);
      await e.mount(t, const ProcessPageScreen(slug: 'demo'));
      await tap(t, 'Mở Smart Dự Án');
      expect(
        calls.single.arguments,
        containsPair('url', 'https://smartduan.vn'),
      );
      expect(calls.single.arguments, containsPair('useWebView', false));
    },
  );

  testWidgets(
    '35 masked contact phones are readable text without button semantics',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path.endsWith('/contacts')
          ? const Reply(200, {
              'data': [
                {'full_name': 'An', 'phone': '09★★'},
              ],
            })
          : hReply(r.path);
      await e.mount(t, const ProjectScreen(id: 'p'));
      expect(find.text('09★★'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('09★★'), matching: find.byType(kit.Button)),
        findsNothing,
      );
    },
  );

  testWidgets(
    '33 uncertain delivery offers the existing hotline and never resends',
    (t) async {
      final e = KEnv();
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/sales/consult'
          ? const Reply(503, {'error': 'lead_delivery_unknown'})
          : r.path == '/public/stats'
          ? const Reply(200, {
              'data': {
                'contact': {'hotline': '19001234'},
              },
            })
          : original(r);
      await e.mount(t, const ConsultScreen());
      await tap(t, 'Tôi đồng ý để sàn liên hệ tư vấn');
      await tap(t, 'Gửi');
      expect(find.text('Gọi 19001234 để xác nhận'), findsOneWidget);
      expect(
        t.widget<kit.Button>(find.widgetWithText(kit.Button, 'Gửi')).disabled,
        isTrue,
      );
      await t.pump(const Duration(seconds: 30));
      expect(
        e.http.seen.where((r) => r.path == '/sales/consult'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    '36 only the active document shows progress while all downloads lock',
    (t) async {
      final e = HEnv();
      final pending = Completer<Reply>();
      e.http.respond = (r) => r.path == '/content/projects/p/documents'
          ? const Reply(200, {
              'data': [
                {'id': 'a', 'title': 'Tài liệu A'},
                {'id': 'b', 'title': 'Tài liệu B'},
              ],
            })
          : r.path.endsWith('/download-link')
          ? pending.future
          : hReply(r.path);
      await e.mount(t, const ProjectScreen(id: 'p'));
      final buttons = find.byWidgetPredicate(
        (w) => w is kit.Button && w.title == 'Tải',
      );
      await t.ensureVisible(buttons.first);
      await t.tap(buttons.first);
      await t.pump();
      final all = t.widgetList<kit.Button>(buttons).toList();
      expect(all.where((b) => b.loading), hasLength(1));
      expect(all.every((b) => b.disabled), isTrue);
      pending.complete(const Reply(503));
      await t.pumpAndSettle();
      expect(
        e.http.seen.where((r) => r.path.endsWith('/download-link')),
        hasLength(1),
      );
    },
  );

  testWidgets(
    '38 long overview and documents preview without losing search results',
    (t) async {
      final e = HEnv();
      final long = List.generate(12, (i) => 'Dòng tổng quan $i').join('\n');
      e.http.respond = (r) => r.path == '/projects/p'
          ? Reply(200, {...hProject, 'description': long})
          : r.path == '/content/projects/p/documents'
          ? Reply(200, {
              'data': List.generate(
                7,
                (i) => {'id': '$i', 'title': 'Tài liệu $i'},
              ),
            })
          : hReply(r.path);
      await e.mount(t, const ProjectScreen(id: 'p'));
      expect(t.widget<Text>(find.text(long)).maxLines, 6);
      expect(find.text('Tài liệu (7)'), findsOneWidget);
      expect(find.text('Tài liệu 6'), findsNothing);
      await tap(t, 'Xem thêm');
      expect(t.widget<Text>(find.text(long)).maxLines, isNull);
      await t.ensureVisible(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'Tài liệu 6');
      await t.pumpAndSettle();
      expect(find.text('Tài liệu 6', findRichText: true).last, findsOneWidget);
    },
  );

  testWidgets(
    '39 accounts mount lazily and preserve a rejection draft offscreen',
    (t) async {
      final e = HEnv(roles: ['superadmin']);
      e.http.respond = (_) => Reply(200, {
        'data': List.generate(
          100,
          (i) => {
            'id': '$i',
            'email': 'sale$i@test.vn',
            'status': 'pending',
            'phone_verified_at': '2026-01-01',
            'roles': ['agent'],
          },
        ),
      });
      await e.mount(t, const ApproveAccountsScreen());
      expect(find.text('sale29@test.vn'), findsNothing);
      await t.tap(find.text('Từ chối').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Giữ bản nháp');
      await t.scrollUntilVisible(
        find.widgetWithText(kit.Body, 'sale25@test.vn'),
        600,
        maxScrolls: 50,
        scrollable: find.byType(Scrollable).first,
      );
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      expect(find.text('Giữ bản nháp'), findsWidgets);
    },
  );

  testWidgets(
    '39 flat board mounts lazily and exposes units beyond the old cap',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path == '/projects/p/units'
          ? Reply(200, {
              'data': List.generate(
                310,
                (i) => {'id': '$i', 'code': 'Mã căn $i', 'status': 'available'},
              ),
              'total': 310,
            })
          : hReply(r.path);
      await mountInventory(t, e, const BoardScreen(projectId: 'p'));
      expect(find.text('Mã căn 299'), findsNothing);
      await t.scrollUntilVisible(
        find.text('Mã căn 309'),
        1500,
        maxScrolls: 100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mã căn 309'), findsOneWidget);
    },
  );

  testWidgets('39 share links mount lazily in server order', (t) async {
    final e = HEnv();
    e.http.respond = (_) => Reply(200, {
      'data': List.generate(
        100,
        (i) => {'id': '$i', 'token': 't$i', 'created_by_name': 'Người tạo $i'},
      ),
    });
    await e.mount(t, const ShareLinksScreen(projectId: 'p'));
    expect(find.text('Người tạo 99'), findsNothing);
    await t.scrollUntilVisible(
      find.text('Người tạo 99'),
      600,
      maxScrolls: 150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Người tạo 99'), findsOneWidget);
  });

  testWidgets('39 top units mount lazily while all remain reachable', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (_) => Reply(200, {
      'groups': [
        {
          'unit_type': 'Căn hộ',
          'available': 100,
          'units': List.generate(100, (i) => {'id': '$i', 'code': 'Căn số $i'}),
        },
      ],
    });
    await e.mount(t, const TopUnitsScreen(projectId: 'p'));
    expect(find.textContaining('Căn số 99'), findsNothing);
    await t.scrollUntilVisible(
      find.textContaining('Căn số 99'),
      500,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Căn số 99'), findsOneWidget);
  });

  testWidgets('39 reports bound long groups and expose their full count', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/reports/inventory'
        ? Reply(200, {
            'data': List.generate(
              100,
              (i) => {'project_id': '$i', 'project': 'Dự án $i', 'total': 0},
            ),
          })
        : hReply(r.path);
    await e.mount(t, const ReportsScreen());
    expect(find.text('Dự án 5'), findsNothing);
    expect(find.text('100 dòng · Hiển thị 5 dòng đầu'), findsOneWidget);
    await tap(t, 'Xem thêm (95)');
    expect(find.text('100 dòng · Vuốt để xem tất cả'), findsOneWidget);
    expect(find.text('Dự án 99'), findsNothing);
  });

  testWidgets(
    '41 download preview labels recent entries and expands all loaded rows',
    (t) async {
      final e = KEnv();
      final original = e.http.respond;
      e.http.respond = (r) => r.path == '/sales/profile/downloads'
          ? Reply(200, {
              'data': List.generate(
                12,
                (i) => {'id': '$i', 'document_title': 'Tệp $i'},
              ),
            })
          : original(r);
      await e.mount(t, const ProfileScreen());
      expect(find.text('Hiển thị 10/12 lượt tải gần nhất'), findsOneWidget);
      expect(find.text('Tệp 11'), findsNothing);
      await tap(t, 'Xem thêm (2)');
      expect(find.text('Tệp 11'), findsOneWidget);
    },
  );

  testWidgets('44 home rail cards have matched heights with uneven names', (
    t,
  ) async {
    final e = KEnv();
    final original = e.http.respond;
    e.http.respond = (r) => r.path == '/projects'
        ? const Reply(200, {
            'data': [
              hProject,
              {
                'id': 'p2',
                'code': 'P2',
                'name': 'Tên dự án rất dài xuống hai dòng cùng địa chỉ và chủ đầu tư',
                'address': 'Địa chỉ dài',
                'developer_name': 'Chủ đầu tư',
              },
            ],
            'total': 2,
          })
        : original(r);
    await e.mount(t, const Scaffold(body: HomeScreen()));
    final cards = find.byType(ProjectCard);
    expect(cards, findsNWidgets(2));
    expect(t.getSize(cards.first).height, t.getSize(cards.last).height);
    expect(t.takeException(), isNull);
  });

  testWidgets('44 narrow home supports doubled text without rail overflow', (
    t,
  ) async {
    final e = KEnv();
    final original = e.http.respond;
    e.http.respond = (r) => r.path == '/projects'
        ? const Reply(200, {
            'data': [hProject],
            'total': 1,
          })
        : original(r);
    await e.mount(
      t,
      MediaQuery.withClampedTextScaling(
        minScaleFactor: 2,
        maxScaleFactor: 2,
        child: const Scaffold(body: HomeScreen()),
      ),
    );
    t.view.physicalSize = const Size(320, 900);
    await t.pumpAndSettle();
    expect(find.byType(ProjectCard), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('22 tapping consent sentence toggles the labelled switch', (
    t,
  ) async {
    await KEnv().mount(t, const ConsultScreen());
    await t.tap(find.text('Tôi đồng ý để sàn liên hệ tư vấn'));
    await t.pumpAndSettle();
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(
      find.bySemanticsLabel('Tôi đồng ý để sàn liên hệ tư vấn'),
      findsOneWidget,
    );
  });

  testWidgets('29 verification guidance contains a usable support next step', (
    t,
  ) async {
    await KEnv(me: {'roles': <String>[]}).mount(t, const BecomeSalesScreen());
    expect(find.textContaining('phone_not_verified'), findsNothing);
    expect(find.textContaining('Liên hệ quản lý'), findsOneWidget);
  });
}
