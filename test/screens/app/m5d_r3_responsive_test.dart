// Uses the platform interface already installed by webview_flutter.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/announcement.dart';
import 'package:smartduan/screens/app/announcements.dart';
import 'package:smartduan/screens/app/approve_accounts.dart';
import 'package:smartduan/screens/app/approve_devices.dart';
import 'package:smartduan/screens/app/basket.dart';
import 'package:smartduan/screens/app/become_sales.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/screens/app/compare_units.dart';
import 'package:smartduan/screens/app/consult.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/app/interests.dart';
import 'package:smartduan/screens/app/loan.dart';
import 'package:smartduan/screens/app/menu_tab.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'basket_test.dart' show BasketPlatform;

import '../../realtime/fakes.dart';
import '../../support/responsive.dart';
import 'task_h_fakes.dart';

const longName = 'Nguyễn Thị Minh Anh · Dự án khu đô thị phía Đông Sài Gòn';

Reply response(String path, String state) {
  if (state == 'error') return const Reply(503);
  if (state == 'empty') {
    return const Reply(200, {'data': <Object?>[], 'units': <Object?>[]});
  }
  final project = {...hProject, 'name': longName};
  return switch (path) {
    '/projects' => Reply(200, {
      'data': [project],
      'total': 1,
    }),
    '/sales/announcements' => const Reply(200, {
      'data': [
        {'id': 'a', 'title': longName},
      ],
      'total': 1,
    }),
    '/sales/announcements/a' => const Reply(200, {
      'data': {'id': 'a', 'title': longName, 'body': '<p>$longName</p>'},
    }),
    '/sales/managers' => const Reply(200, {
      'data': [
        {'id': 'm', 'full_name': longName},
      ],
    }),
    '/branches' => const Reply(200, {
      'data': [
        {'code': 'b', 'name': longName},
      ],
    }),
    '/sales/me/compare' => Reply(200, {
      'units': [
        for (var i = 0; i < 3; i++)
          {
            ...hUnit,
            'id': 'u$i',
            'code': 'A-120$i',
            'project': project,
            'price_min': '999999999999',
            'policy': {'name': longName, 'url': 'https://smartduan.vn/policy'},
          },
      ],
    }),
    '/users' => const Reply(200, {
      'data': [
        {
          'id': 'user',
          'email': 'long.email@example.com',
          'full_name': longName,
          'status': 'pending',
          'email_verified_at': '2026-11-13',
          'roles': <String>[],
        },
      ],
    }),
    '/admin/devices' => const Reply(200, {
      'data': [
        {
          'id': 'device',
          'label': longName,
          'kind': 'mobile',
          'status': 'pending',
          'user': {
            'id': 'user',
            'email': 'long.email@example.com',
            'full_name': longName,
          },
        },
      ],
    }),
    '/projects/p/units' => const Reply(200, {
      'data': [
        {...hUnit, 'bedrooms': 2, 'direction': 'dong'},
        {
          'id': 'u2',
          'code': 'B102',
          'status': 'available',
          'bedrooms': 1,
          'direction': 'tay',
        },
      ],
      'total': 2,
    }),
    '/auth/basket-token' => const Reply(200, {'token': 'fixture-token'}),
    '/sales/loans/calculate' => const Reply(200, {
      'monthly_payment': 123456789,
      'price': 999999999999,
      'loan_amount': 699999999999,
      'loan_ratio': .7,
      'schedule': [
        {'period': 1, 'total': 123456789, 'principal': 98765432},
      ],
    }),
    _ => hReply(path),
  };
}

Future<void> mountR3(
  WidgetTester tester,
  Widget screen,
  String state, {
  List<String> roles = const ['admin'],
  Future<void> Function()? interact,
}) async {
  final env = HEnv(roles: roles);
  env.http.respond = (r) =>
      state == 'loading' ? Completer<Reply>().future : response(r.path, state);
  final socket = BoardSocket();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => screen is HomeScreen || screen is MenuTab
            ? Scaffold(body: screen)
            : screen,
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: env.container,
      child: ProviderScope(
        overrides: [inventorySocketProvider('p').overrideWithValue(socket)],
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (interact != null) await interact();
  for (final scrollable in find.byType(Scrollable).evaluate().toList()) {
    if (!scrollable.mounted) continue;
    final state = (scrollable as StatefulElement).state as ScrollableState;
    if (state.position.hasContentDimensions) {
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
    }
  }
  await tester.pumpWidget(const SizedBox());
  router.dispose();
  env.container.dispose();
}

void main() {
  setUp(() => WebViewPlatform.instance = BasketPlatform());
  final screens = <String, Widget>{
    'announcement': const AnnouncementScreen(id: 'a'),
    'announcements': const AnnouncementsScreen(),
    'approve accounts': const ApproveAccountsScreen(),
    'approve devices': const ApproveDevicesScreen(),
    'basket invalid': const BasketScreen(),
    'basket embedded': const BasketScreen(
      projectId: 'p',
      url: 'https://ro-hang.smartland.vn/',
    ),
    'become sales F2': const BecomeSalesScreen(),
    'board': const BoardScreen(projectId: 'p', name: longName),
    'comparison': const CompareUnitsScreen(),
    'consult': const ConsultScreen(name: longName),
    'home': const HomeScreen(),
    'interests': const InterestsScreen(),
    'loan': const LoanScreen(),
    'menu': const MenuTab(),
  };
  for (final entry in screens.entries) {
    for (final state in ['data', 'empty', 'error', 'loading']) {
      testWidgets('${entry.key} $state responsive matrix', (tester) async {
        await expectResponsive(
          tester,
          () => mountR3(tester, entry.value, state),
        );
      });
    }
  }
  testWidgets('free registration responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(tester, const BecomeSalesScreen(), 'data', roles: []),
    );
  });
  testWidgets('F2 manager picker responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(
        tester,
        const BecomeSalesScreen(),
        'data',
        interact: () async {
          await tester.ensureVisible(find.text('Chọn quản lý'));
          await tester.tap(find.text('Chọn quản lý'));
          await tester.pumpAndSettle();
          expect(find.text('Tìm quản lý, đại lý…'), findsOneWidget);
        },
      ),
    );
  });
  testWidgets('account confirmation responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(
        tester,
        const ApproveAccountsScreen(),
        'data',
        interact: () async {
          final approve = find.text('Duyệt');
          await tester.ensureVisible(approve);
          await tester.pumpAndSettle();
          await tester.ensureVisible(approve);
          await tester.tap(approve);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
        },
      ),
    );
  });
  testWidgets('device confirmation responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(
        tester,
        const ApproveDevicesScreen(),
        'data',
        interact: () async {
          final approve = find.text('Duyệt và thay thế');
          await tester.ensureVisible(approve);
          await tester.pumpAndSettle();
          await tester.ensureVisible(approve);
          await tester.tap(approve);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
        },
      ),
    );
  });
  testWidgets('loan policy overrides responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(
        tester,
        const LoanScreen(unitId: 'u'),
        'data',
        interact: () async {
          final button = find.text('Điều chỉnh lãi suất / ưu đãi');
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pump();
          expect(find.byType(kit.Field), findsNWidgets(4));
        },
      ),
    );
  });
  testWidgets('board filter sheet responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(
        tester,
        const BoardScreen(projectId: 'p'),
        'data',
        interact: () async {
          final search = tester.widget<kit.SearchBar>(
            find.byType(kit.SearchBar),
          );
          search.onFilter!();
          await tester.pumpAndSettle();
          expect(find.text('Lọc căn'), findsOneWidget);
        },
      ),
    );
  });
  testWidgets('loan result and schedule responsive matrix', (tester) async {
    await expectResponsive(
      tester,
      () => mountR3(
        tester,
        const LoanScreen(unitId: 'u'),
        'data',
        interact: () async {
          await tester.tap(find.text('Tính'));
          await tester.pumpAndSettle();
          expect(find.text('Trả hàng tháng — kỳ đầu'), findsOneWidget);
          final schedule = find.text('Xem lịch trả 12 kỳ đầu');
          await tester.ensureVisible(schedule);
          await tester.pumpAndSettle();
          await tester.tap(schedule);
          await tester.pump();
          expect(find.text('Kỳ 1'), findsOneWidget);
        },
      ),
    );
  });
  for (final screen in [
    const BecomeSalesScreen(),
    const ConsultScreen(),
    const LoanScreen(unitId: 'u'),
    const InterestsScreen(),
  ]) {
    testWidgets('${screen.runtimeType} focused field stays above keyboard', (
      tester,
    ) async {
      await expectResponsive(
        tester,
        () => mountR3(
          tester,
          screen,
          'data',
          interact: () async {
            tester.view.viewInsets = const FakeViewPadding(bottom: 200);
            await tester.pump();
            final field = find.byType(TextField).first;
            await tester.showKeyboard(field);
            await tester.ensureVisible(field);
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              tester.getCenter(field).dy,
              lessThan(tester.view.physicalSize.height - 200),
            );
          },
        ),
      );
    });
  }
}
