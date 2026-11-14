import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/screens/app/notifications.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/screens/app/process_pages.dart';
import 'package:smartduan/screens/app/profile.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/app/reports.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/saved_projects.dart';
import 'package:smartduan/screens/app/team.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/api/content.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/stack_grid.dart';

import '../../support/responsive.dart';
import 'm5d_r4_responsive_test.dart'
    show r4Reply, verticalR4, mountR4, longName;
import 'task_h_fakes.dart';

void main() {
  testWidgets('8 search filter headings use the RN uppercase 13/700 label', (
    t,
  ) async {
    final e = HEnv();
    await e.mount(t, const SearchUnitsScreen());
    t.widget<kit.SearchBar>(find.byType(kit.SearchBar)).onFilter!();
    await t.pumpAndSettle();
    final text = t.widget<Text>(find.text('PHÒNG NGỦ'));
    expect(text.style?.fontSize, 13);
    expect(text.style?.fontWeight, FontWeight.w700);
  });

  for (final (name, screen, path, row)
      in <(String, Widget, String, Map<String, Object>)>[
        (
          'notifications',
          const NotificationsScreen(),
          '/sales/notifications',
          {'id': 'a', 'title': 'Thông báo mẫu', 'href': '/sales/ho-so'},
        ),
        (
          'process pages',
          const ProcessPagesScreen(),
          '/process-pages',
          {'id': 'a', 'title': 'Quy trình mẫu', 'slug': 'a'},
        ),
        (
          'team',
          const TeamScreen(),
          '/sales/team',
          {'id': 'a', 'full_name': 'Thành viên mẫu'},
        ),
      ]) {
    testWidgets('11/12 $name lists one RN card per row', (t) async {
      final e = HEnv(roles: ['manager']);
      e.http.respond = (r) => r.path == path
          ? Reply(200, {
              'data': [
                row,
                {...row, 'id': 'b'},
              ],
            })
          : hReply(r.path);
      await e.mount(t, screen);
      expect(find.byType(kit.Divider), findsNothing);
      final title = (row['title'] ?? row['full_name'])! as String;
      expect(
        find.ancestor(of: find.text(title), matching: find.byType(kit.Card)),
        findsNWidgets(2),
      );
      // RN: only notifications with a route show a chevron.
      if (name != 'notifications') {
        expect(find.byIcon(Ionicons.chevronForward), findsNothing);
      } else {
        expect(find.byIcon(Ionicons.chevronForward), findsNWidgets(2));
      }
    });
  }

  testWidgets(
    '17 saved project actions stay associated with their project across the responsive matrix',
    (t) async {
      await expectResponsive(t, () async {
        final e = HEnv(roles: ['manager']);
        e.http.respond = (r) => r4Reply(r.path);
        final router = await mountR4(
          t,
          e,
          const SavedProjectsScreen(),
          destinations: [
            GoRoute(
              path: '/cong-khai/:code',
              builder: (_, state) => Scaffold(
                body: Text('Public ${state.pathParameters['code']}'),
              ),
            ),
            GoRoute(
              path: '/bang-hang/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Board ${state.pathParameters['id']}')),
            ),
          ],
        );
        expect(find.textContaining('Bảng hàng ·'), findsNothing);
        await t.scrollUntilVisible(
          find.text(longName),
          200,
          scrollable: verticalR4.first,
        );
        await t.ensureVisible(find.text(longName));
        await t.pumpAndSettle();
        expect(find.text('Bảng hàng'), findsOneWidget);
        expect(find.text('Xem dự án'), findsNothing);
        await t.tap(find.text(longName));
        await t.pumpAndSettle();
        expect(find.text('Public P'), findsOneWidget);
        router.pop();
        await t.pumpAndSettle();
        final compact = find.bySemanticsLabel('Xem dạng danh sách gọn');
        await t.scrollUntilVisible(compact, -200, scrollable: verticalR4.first);
        await t.ensureVisible(compact);
        await t.pumpAndSettle();
        await t.tap(compact);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Bảng hàng'),
          200,
          scrollable: verticalR4.first,
        );
        await t.ensureVisible(find.text('Bảng hàng'));
        await t.pumpAndSettle();
        await t.tap(find.text('Bảng hàng'));
        await t.pumpAndSettle();
        expect(find.text('Board p'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        router.dispose();
        e.container.dispose();
      });
    },
  );

  testWidgets(
    '23 unit refresh uses the shared reduced-motion loading indicator',
    (t) async {
      final e = HEnv();
      await e.mount(t, const UnitScreen(id: 'u'));
      final pending = Completer<Reply>();
      e.http.respond = (r) =>
          r.path == '/units/u/detail' ? pending.future : hReply(r.path);
      final refresh = t
          .widget<kit.ListScreen<UnitImage>>(
            find.byWidgetPredicate((w) => w is kit.ListScreen<UnitImage>),
          )
          .onRefresh!();
      await t.pump();
      expect(find.byType(kit.Loading), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      pending.complete(const Reply(200, hUnit));
      await t.pumpAndSettle();
      await refresh;
    },
  );

  testWidgets(
    '24 project reserves a document section and retains it during refresh, hiding it on denied access',
    (t) async {
      final e = HEnv();
      var pending = Completer<Reply>();
      e.http.respond = (r) =>
          r.path.endsWith('/documents') ? pending.future : hReply(r.path);
      await e.mount(t, const ProjectScreen(id: 'p'));
      await t.scrollUntilVisible(
        find.text('Tài liệu'),
        200,
        scrollable: verticalR4.first,
      );
      expect(find.byType(kit.Skeleton), findsWidgets);
      pending.complete(
        const Reply(200, {
          'data': [
            {'id': 'd', 'title': 'Tài liệu đã tải'},
          ],
        }),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Tài liệu đã tải'),
        100,
        scrollable: verticalR4.first,
      );
      pending = Completer<Reply>();
      e.container.invalidate(fetchDocumentsProvider('p'));
      await t.pump();
      expect(find.text('Tài liệu đã tải'), findsOneWidget);
      pending.complete(const Reply(403));
      await t.pumpAndSettle();
      expect(find.text('Tài liệu đã tải'), findsNothing);
    },
  );

  testWidgets('31 profile previews count remaining downloads', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/sales/profile/downloads'
        ? Reply(200, {
            'data': List.generate(
              12,
              (i) => {'id': '$i', 'document_title': 'Tệp $i'},
            ),
          })
        : r4Reply(r.path);
    await e.mount(t, const ProfileScreen());
    await t.scrollUntilVisible(
      find.text('Xem thêm (2)'),
      300,
      scrollable: verticalR4.first,
    );
    expect(find.text('Xem thêm (2)'), findsOneWidget);
  });

  testWidgets('2 presentation has one view selector', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path);
    await e.mount(t, const PresentationScreen(projectId: 'p'));
    expect(find.text('Sơ đồ'), findsOneWidget);
    await t.tap(find.text('Danh sách'));
    await t.pumpAndSettle();
    expect(t.widget<StackGrid>(find.byType(StackGrid)).viewMode, 'list');
    expect(find.byType(kit.Segmented), findsOneWidget);
  });

  testWidgets('3 unit actions share an adaptive group with a primary loan', (
    t,
  ) async {
    final e = HEnv();
    await e.mount(t, const UnitScreen(id: 'u'));
    final group = t.widget<kit.ButtonGroup>(find.byType(kit.ButtonGroup).first);
    expect(group.children.first.title, 'Tính lãi vay căn này');
    expect(group.children.first.kind, 'primary');
    expect(group.children.last.kind, 'secondary');
  });

  testWidgets('10 unit status is an RN pill', (t) async {
    final e = HEnv();
    await e.mount(t, const UnitScreen(id: 'u'));
    expect(find.byType(kit.Pill), findsWidgets);
    expect(find.text('Còn hàng'), findsWidgets);
  });

  testWidgets('10 profile roles are RN pills', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/sales/profile'
        ? const Reply(200, {
            'id': 'me',
            'email': 'a@example.com',
            'roles': ['agent', 'manager'],
          })
        : hReply(r.path);
    await e.mount(t, const ProfileScreen());
    expect(find.byType(kit.Pill), findsNWidgets(2));
    expect(find.textContaining('Quản lý'), findsOneWidget);
  });

  for (final screen in [
    const NotificationsScreen(),
    const ProcessPagesScreen(),
  ]) {
    testWidgets('11 ${screen.runtimeType} uses RN cards', (t) async {
      final e = HEnv();
      e.http.respond = (r) => r4Reply(r.path);
      await e.mount(t, screen);
      expect(find.byType(kit.Card), findsWidgets);
    });
  }

  testWidgets('18 profile empty devices describes the consequence', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path, empty: true);
    await e.mount(t, const ProfileScreen());
    await t.scrollUntilVisible(
      find.text('Chưa có thiết bị đăng nhập nào được ghi nhận.'),
      300,
      scrollable: verticalR4.first,
    );
    expect(find.textContaining('máy chủ'), findsNothing);
  });

  testWidgets('18 search copy explains local filtering and save recovery', (
    t,
  ) async {
    final e = HEnv();
    await e.mount(t, const SearchUnitsScreen());
    t.widget<kit.SearchBar>(find.byType(kit.SearchBar)).onFilter!();
    await t.pumpAndSettle();
    expect(find.textContaining('Chỉ lọc các căn đã tải'), findsOneWidget);
    expect(find.textContaining('máy chủ'), findsNothing);
  });

  testWidgets('19 reports names the native inventory board', (t) async {
    final e = HEnv(roles: ['manager']);
    await e.mount(t, const ReportsScreen());
    await t.scrollUntilVisible(
      find.text('Cập nhật bảng hàng'),
      300,
      scrollable: verticalR4.first,
    );
    expect(find.text('Cập nhật rổ hàng'), findsNothing);
  });

  testWidgets('21 project missing price uses contact policy', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/projects/p'
        ? Reply(200, {...hProject, 'price_from': '0'})
        : hReply(r.path);
    await e.mount(t, const ProjectScreen(id: 'p'));
    expect(find.text('Liên hệ'), findsWidgets);
    expect(find.text('0 đ'), findsNothing);
    expect(find.text('Giá từ'), findsNothing);
  });

  testWidgets('26 project identity is grouped with tight gaps', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/projects/p'
        ? const Reply(200, {
            ...hProject,
            'status': 'selling',
            'address': 'Địa chỉ mẫu',
          })
        : hReply(r.path);
    await e.mount(t, const ProjectScreen(id: 'p'));
    final title = find.descendant(
      of: find.byType(kit.H1),
      matching: find.text('Dự án mẫu'),
    );
    final address = find.text('Địa chỉ mẫu');
    expect(
      t.getTopLeft(address).dy - t.getBottomLeft(title).dy,
      lessThanOrEqualTo(8),
    );
  });

  testWidgets('28 notification interests uses notification icon', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path);
    await e.mount(t, const ProfileScreen());
    final row = t.widget<kit.ListItem>(
      find.ancestor(
        of: find.text('Dự án quan tâm'),
        matching: find.byType(kit.ListItem),
      ),
    );
    expect(row.icon, Ionicons.notificationsOutline);
  });
}
