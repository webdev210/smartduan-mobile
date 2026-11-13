import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/announcements.dart';
import 'package:smartduan/screens/app/approve_accounts.dart';
import 'package:smartduan/screens/app/approve_devices.dart';
import 'package:smartduan/screens/app/become_sales.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/screens/app/compare_units.dart';
import 'package:smartduan/screens/app/interests.dart';
import 'package:smartduan/screens/app/loan.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/theme.dart' as c;

import 'm5d_r3_responsive_test.dart' show mountR3, response;
import 'task_h_fakes.dart';
import '../../realtime/fakes.dart';

void main() {
  testWidgets(
    '2, 11: project scope hides tower choices and uses divided unit navigation',
    (t) async {
      final e = HEnv();
      final projects = BoardProjects(e.client)
        ..blocks = [const Block(id: 'b', name: 'Toà B')];
      final units = BoardUnits(e.client)
        ..units = [
          const Unit(id: 'u1', code: 'A101', status: 'available'),
          const Unit(id: 'u2', code: 'A102', status: 'sold'),
        ];
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(() => e.session),
          apiClientProvider.overrideWithValue(e.client),
          projectsApiProvider.overrideWithValue(projects),
          unitsApiProvider.overrideWithValue(units),
          inventorySocketProvider('p').overrideWithValue(BoardSocket()),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BoardScreen(projectId: 'p')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Toà B'), findsOneWidget);
      expect(find.text('Sơ đồ'), findsOneWidget);
      await t.ensureVisible(find.text('Danh sách'));
      await t.pumpAndSettle();
      await t.tap(find.text('Danh sách'));
      await t.pumpAndSettle();
      expect(t.widget<StackGrid>(find.byType(StackGrid)).viewMode, 'list');
      await t.ensureVisible(find.text('Toàn dự án'));
      await t.pumpAndSettle();
      await t.tap(find.text('Toàn dự án'));
      await t.pumpAndSettle();
      expect(find.text('Toà B'), findsNothing);
      await t.scrollUntilVisible(
        find.text('A101'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(find.widgetWithText(kit.ListItem, 'A101'), findsOneWidget);
      expect(find.byType(kit.Divider), findsWidgets);
    },
  );

  testWidgets('1: home project rail follows card content height', (t) async {
    final e = HEnv(roles: []);
    e.http.respond = (r) => r.path == '/public/projects'
        ? Reply(200, {
            'data': [
              hProject,
              {
                ...hProject,
                'id': 'p2',
                'code': 'P2',
                'name': 'Dự án có tên rất dài để hiển thị hai dòng',
                'province': 'Hà Nội',
              },
            ],
            'total': 2,
          })
        : hReply(r.path);
    await e.mount(t, const Scaffold(body: HomeScreen()));
    final card = find.byType(ProjectCard);
    await t.ensureVisible(card.first);
    await t.pumpAndSettle();
    expect(t.getSize(card.first).height, lessThan(450));
    expect(t.getSize(card.first).height, t.getSize(card.last).height);
  });

  testWidgets('24: home reserves announcements and project loading layouts', (
    t,
  ) async {
    final e = HEnv(roles: ['admin']);
    final pending = Completer<Reply>();
    e.http.respond = (_) => pending.future;
    await e.mount(t, const Scaffold(body: HomeScreen()), settle: false);
    await t.pump();
    expect(find.byType(kit.Skeleton), findsWidgets);
    expect(find.byType(kit.Loading), findsNothing);
    pending.complete(const Reply(200, {'data': <Object?>[], 'total': 0}));
    await t.pumpAndSettle();
  });

  testWidgets('2, 18: board separates scope and explains connection recovery', (
    t,
  ) async {
    await mountR3(
      t,
      const BoardScreen(projectId: 'p'),
      'data',
      interact: () async {
        expect(find.text('Toàn dự án'), findsOneWidget);
        expect(find.textContaining('realtime'), findsNothing);
        expect(find.textContaining('kéo xuống để làm mới'), findsOneWidget);
      },
    );
  });

  testWidgets('4: comparison mutes labels and emphasizes ruled price row', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.path == '/sales/me/compare'
        ? const Reply(200, {
            'units': [hUnit],
          })
        : hReply(r.path);
    await e.mount(t, const CompareUnitsScreen());
    final label = t.widget<Text>(find.text('Giá tốt nhất'));
    final price = t.widget<Text>(find.text('400 tr'));
    expect(label.style?.color, c.muted);
    expect(price.style?.fontWeight, FontWeight.w700);
    final rules = t.widgetList<Container>(
      find.ancestor(of: find.text('400 tr'), matching: find.byType(Container)),
    );
    expect(
      rules.any(
        (w) =>
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      ),
      isTrue,
    );
  });

  for (final screen in [
    const ApproveAccountsScreen(),
    const ApproveDevicesScreen(),
  ]) {
    testWidgets(
      '23: ${screen.runtimeType} reduced motion shows static save feedback',
      (t) async {
        final e = HEnv(roles: ['admin']);
        final pending = Completer<Reply>();
        e.http.respond = (r) =>
            r.method == 'GET' ? response(r.path, 'data') : pending.future;
        await e.mount(
          t,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: screen,
            ),
          ),
        );
        final label = screen is ApproveAccountsScreen
            ? 'Duyệt'
            : 'Duyệt và thay thế';
        await t.ensureVisible(find.text(label));
        await t.tap(find.text(label));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(TextButton, label));
        await t.pumpAndSettle();
        expect(find.text('Đang lưu…'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        pending.complete(const Reply(503));
        await t.pumpAndSettle();
      },
    );
    testWidgets('10: ${screen.runtimeType} status is text metadata', (t) async {
      final e = HEnv(roles: ['admin']);
      e.http.respond = (r) => response(r.path, 'data');
      await e.mount(t, screen);
      expect(find.byType(kit.Pill), findsNothing);
      expect(find.text('Chờ duyệt'), findsWidgets);
    });
  }

  testWidgets('12: announcements have between-row rules', (t) async {
    final e = HEnv();
    e.http.respond = (r) => const Reply(200, {
      'data': [
        {'id': 'a', 'title': 'Tin thứ nhất'},
        {'id': 'b', 'title': 'Tin thứ hai'},
      ],
      'total': 2,
    });
    await e.mount(t, const AnnouncementsScreen());
    expect(find.byType(kit.Divider), findsOneWidget);
    expect(find.byType(kit.ListItem), findsNWidgets(2));
  });

  testWidgets('13: manager chooser uses titled kit sheet with close action', (
    t,
  ) async {
    await mountR3(
      t,
      const BecomeSalesScreen(),
      'data',
      interact: () async {
        await t.ensureVisible(find.text('Chọn quản lý'));
        await t.tap(find.text('Chọn quản lý'));
        await t.pumpAndSettle();
        expect(find.byType(kit.Sheet), findsOneWidget);
        expect(find.widgetWithText(kit.H2, 'Chọn quản lý'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is kit.IconButton && w.label == 'Đóng',
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(kit.Button, 'Đóng'), findsNothing);
      },
    );
  });

  for (final screen in [
    const LoanScreen(unitId: 'u'),
    const InterestsScreen(),
  ]) {
    testWidgets('14: ${screen.runtimeType} action matches tablet form gutter', (
      t,
    ) async {
      await mountR3(
        t,
        screen,
        'data',
        interact: () async {
          t.view.physicalSize = const Size(1000, 1000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pump();
          final button = find.widgetWithText(
            kit.Button,
            screen is LoanScreen ? 'Tính' : 'Lưu',
          );
          expect(t.getSize(button).width, 600);
          expect(t.getCenter(button).dx, 500);
        },
      );
    });
  }
}
