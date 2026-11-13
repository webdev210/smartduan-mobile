import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/app/become_sales.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/app/loan.dart';
import 'package:smartduan/screens/app/interests.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/screens/app/compare_units.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'task_h_fakes.dart';
import 'm5d_r3_responsive_test.dart' show response, mountR3;

class InterestSession extends Session {
  @override
  SessionState build() => SessionState(
    SessionStatus.signedIn,
    me: {
      'roles': ['agent'],
      'region': 'nam',
      'interested_project_ids': [for (var i = 0; i < 50; i++) '$i'],
    },
  );
}

class PendingSession extends Session {
  int refreshes = 0;
  @override
  SessionState build() => const SessionState(
    SessionStatus.signedIn,
    me: {
      'roles': ['sales_free'],
      'f2_requested_at': '2026-11-13T08:00:00Z',
    },
  );
  @override
  Future<void> refreshMe() async {
    refreshes++;
  }
}

void main() {
  testWidgets('pending F2 exposes a manual status refresh', (tester) async {
    final env = HEnv();
    final session = PendingSession();
    await env.mount(
      tester,
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => session)],
        child: const BecomeSalesScreen(),
      ),
    );
    await tester.tap(find.text('Kiểm tra trạng thái'));
    await tester.pumpAndSettle();
    expect(session.refreshes, 1);
  });
  testWidgets('unverified phone cannot submit registration', (tester) async {
    final env = HEnv(roles: []);
    await env.mount(tester, const BecomeSalesScreen());
    final button = tester.widget<kit.Button>(
      find.widgetWithText(kit.Button, 'Đăng ký làm sale'),
    );
    expect(button.disabled, isTrue);
  });
  testWidgets('F2 registration title matches the branch', (tester) async {
    final env = HEnv(roles: ['sales_free']);
    await env.mount(tester, const BecomeSalesScreen());
    expect(find.text('Xin xác nhận F2'), findsOneWidget);
  });
  testWidgets('home news precedes compact working projects', (tester) async {
    final env = HEnv(roles: ['agent']);
    env.http.respond = (r) => response(r.path, 'data');
    await env.mount(tester, const Scaffold(body: HomeScreen()));
    expect(
      tester.getTopLeft(find.text('Bảng tin mới')).dy,
      lessThan(tester.getTopLeft(find.text('Dự án của bạn')).dy),
    );
    expect(find.text('Biến động'), findsWidgets);
  });
  testWidgets(
    'loan year presets use month values and overrides start collapsed',
    (tester) async {
      final env = HEnv();
      await env.mount(tester, const LoanScreen(unitId: 'u'));
      expect(find.text('20 năm'), findsOneWidget);
      expect(
        find.text('Lãi thả nổi (%/năm) — bỏ trống = theo CSBH'),
        findsNothing,
      );
      await tester.tap(find.text('15 năm'));
      await tester.tap(find.text('Tính'));
      await tester.pumpAndSettle();
      expect(env.http.seen.single.data?['term_months'], 180);
    },
  );
  testWidgets(
    'F2 manager search selects and dirty back asks before discarding',
    (tester) async {
      final env = HEnv(roles: ['sales_free']);
      env.http.respond = (r) => response(r.path, 'data');
      await env.mount(tester, const BecomeSalesScreen());
      await tester.tap(find.text('Chọn quản lý'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'không có quản lý này',
      );
      await tester.pump();
      expect(find.textContaining('Nguyễn Thị Minh Anh'), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'Minh Anh');
      await tester.pump();
      await tester.tap(find.textContaining('Nguyễn Thị Minh Anh'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi quản lý'), findsOneWidget);
      await Navigator.of(tester.element(find.byType(BecomeSalesScreen)))
          .maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi quản lý'), findsOneWidget);
    },
  );
  testWidgets('interests prevents selection 51 and still permits deselection', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (_) => Reply(200, {
      'data': [
        for (var i = 0; i < 51; i++)
          {'id': '$i', 'code': 'P$i', 'name': 'Dự án $i'},
      ],
      'total': 51,
    });
    await env.mount(
      tester,
      ProviderScope(
        overrides: [sessionProvider.overrideWith(InterestSession.new)],
        child: const InterestsScreen(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Dự án 50');
    await tester.pumpAndSettle();
    final last = find.descendant(
      of: find.byType(kit.Card),
      matching: find.text('Dự án 50'),
    );
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pump();
    expect(find.text('Đã chọn 50/50'), findsOneWidget);
    expect(find.textContaining('Chỉ chọn tối đa 50 dự án.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dự án 49');
    await tester.pumpAndSettle();
    final selected = find.descendant(
      of: find.byType(kit.Card),
      matching: find.text('Dự án 49'),
    );
    await tester.ensureVisible(selected);
    await tester.pumpAndSettle();
    await tester.tap(selected);
    await tester.pump();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(find.text('Đã chọn 49/50'), findsOneWidget);
  });
  testWidgets('board project list excludes unknown prices from a budget', (
    tester,
  ) async {
    await mountR3(
      tester,
      const BoardScreen(projectId: 'p'),
      'data',
      interact: () async {
        await tester.tap(find.text('Toàn dự án'));
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.widgetWithText(kit.Field, 'Giá tối đa (đồng)'),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, '500000000');
        await tester.pumpAndSettle();
        expect(find.textContaining('1 căn chưa có giá'), findsOneWidget);
        expect(find.text('B102'), findsNothing);
        expect(find.text('1 căn'), findsOneWidget);
      },
    );
  });
  testWidgets(
    'comparison keeps labels on horizontal scroll and identity on vertical scroll',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mountR3(
        tester,
        const CompareUnitsScreen(),
        'data',
        interact: () async {
          final labelX = tester.getTopLeft(find.text('Giá tốt nhất')).dx;
          final headingY = tester.getTopLeft(find.text('P-A101').first).dy;
          final body = find.byType(SingleChildScrollView).last;
          await tester.dragFrom(
            tester.getTopLeft(body) + const Offset(80, 40),
            const Offset(-200, 0),
          );
          await tester.pumpAndSettle();
          final horizontal = tester.state<ScrollableState>(
            find.descendant(of: body, matching: find.byType(Scrollable)).first,
          );
          expect(horizontal.position.pixels, greaterThan(0));
          expect(tester.getTopLeft(find.text('Giá tốt nhất')).dx, labelX);
          await tester.dragFrom(
            tester.getTopLeft(body) + const Offset(30, 60),
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(find.text('P-A101').first).dy, headingY);
        },
      );
    },
  );
}
