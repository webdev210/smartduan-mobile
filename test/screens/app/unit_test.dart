import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/ui/network_image.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/ui/unit_compare_picker.dart';

import 'task_h_fakes.dart';

void main() {
  testWidgets('offscreen unit images are not mounted until scrolling', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => r.path == '/units/u/images'
        ? Reply(200, {
            'data': List.generate(
              100,
              (i) => {'id': '$i', 'url': 'https://example.com/$i.jpg'},
            ),
          })
        : hReply(r.path);
    await env.mount(tester, const UnitScreen(id: 'u'));
    expect(find.byType(AppNetworkImage).evaluate().length, lessThan(10));
    expect(find.byKey(const ValueKey('99')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('99')),
      1000,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('99')), findsOneWidget);
  });
  testWidgets(
    'price card omits only an extra price matching main label and value',
    (tester) async {
      final env = HEnv();
      env.http.respond = (r) => r.path == '/units/u/detail'
          ? const Reply(200, {
              ...hUnit,
              'price_min_label': 'Giá niêm yết',
              'price_list': '400000000',
              'price_loan': '400000000',
            })
          : hReply(r.path);
      await env.mount(tester, const UnitScreen(id: 'u'));
      // One summary above the card and one main row inside it, no third duplicate.
      expect(find.text('Giá niêm yết'), findsNWidgets(2));
      expect(find.text('Giá vay'), findsOneWidget);
    },
  );
  testWidgets(
    'unit nullable fields, decimal price/area and empty states render',
    (tester) async {
      final env = HEnv();
      await env.mount(tester, const UnitScreen(id: 'u'));
      expect(find.text('P-A101'), findsNWidgets(2));
      expect(find.text('400 tr'), findsNWidgets(2));
      expect(find.text('50.5 m²'), findsOneWidget);
      expect(find.text('Chưa có hình ảnh.'), findsOneWidget);
      expect(find.text('Chưa có lịch sử thay đổi.'), findsOneWidget);
      expect(find.text('Tạo tin đăng'), findsNothing);
      expect(find.text('Khai báo booking'), findsNothing);
      expect(env.http.seen.where((r) => r.path == '/activity').single.data, {
        'kind': 'unit',
        'project_id': 'p',
        'target': 'A101',
      });
    },
  );
  testWidgets('compare full message is shown and add is not retried', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) =>
        r.method == 'POST' && r.path == '/sales/me/compare'
        ? const Reply(409, {
            'error': 'compare_full',
            'message': 'Chỉ so sánh tối đa 4 căn',
          })
        : hReply(r.path);
    await env.mount(tester, const UnitScreen(id: 'u'));
    await tester.ensureVisible(find.text('Thêm vào so sánh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào so sánh'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉ so sánh tối đa 4 căn'), findsOneWidget);
    expect(
      env.http.seen.where(
        (r) => r.method == 'POST' && r.path == '/sales/me/compare',
      ),
      hasLength(1),
    );
  });
  testWidgets('add then long-press opens existing picker without another add', (
    tester,
  ) async {
    final env = HEnv();
    await env.mount(tester, const UnitScreen(id: 'u'));
    await tester.ensureVisible(find.text('Thêm vào so sánh'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Ionicons.gitCompareOutline), findsOneWidget);
    await tester.tap(find.text('Thêm vào so sánh'));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm · chọn thêm căn'), findsOneWidget);
    expect(find.byIcon(Ionicons.checkmarkCircle), findsOneWidget);
    expect(find.byIcon(Ionicons.gitCompareOutline), findsNothing);
    await tester.longPress(find.text('Đã thêm · chọn thêm căn'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn căn so sánh'), findsOneWidget);
    expect(
      tester.widget<UnitComparePicker>(find.byType(UnitComparePicker)).visible,
      isTrue,
    );
    expect(
      env.http.seen.where(
        (r) => r.method == 'POST' && r.path == '/sales/me/compare',
      ),
      hasLength(1),
    );
  });
  testWidgets('price-sheet fallback and history; loan entry carries unit', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => switch (r.path) {
      '/units/u/detail' => const Reply(200, {
        ...hUnit,
        'price_sheet_url': 'https://smartduan.vn/fallback.pdf',
        'extra_prices': [
          {
            'field': 'price_list',
            'label': 'Thanh toán chuẩn',
            'value': '500000000',
          },
        ],
      }),
      '/units/u/history' => const Reply(200, {
        'data': [
          {
            'id': 'h',
            'field': 'status',
            'old_value': 'reserved',
            'new_value': 'available',
            'changed_at': '2026-11-12',
          },
        ],
        'total': 1,
      }),
      _ => hReply(r.path),
    };
    final router = await env.mount(tester, const UnitScreen(id: 'u'));
    expect(find.text('Thanh toán chuẩn'), findsOneWidget);
    expect(find.text('500 tr'), findsOneWidget);
    expect(find.textContaining('reserved → available'), findsOneWidget);
    await tester.ensureVisible(find.text('Tính lãi vay căn này'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tính lãi vay căn này'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/lai-vay');
    expect(router.state.uri.queryParameters, {'unitId': 'u', 'code': 'P-A101'});
  });
  testWidgets('unit error is retryable', (tester) async {
    final env = HEnv();
    env.http.respond = (_) =>
        const Reply(500, {'message': 'Có lỗi, vui lòng thử lại'});
    await env.mount(tester, const UnitScreen(id: 'u'));
    expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
    env.http.respond = (r) => hReply(r.path);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('P-A101'), findsNWidgets(2));
  });
  testWidgets('late compare response and unit data drop after sign-out', (
    tester,
  ) async {
    final env = HEnv();
    final pending = Completer<Reply>();
    env.http.respond = (r) =>
        r.path == '/sales/me/compare' && r.method == 'POST'
        ? pending.future
        : hReply(r.path);
    await env.mount(tester, const UnitScreen(id: 'u'));
    await tester.ensureVisible(find.text('Thêm vào so sánh'));
    await tester.tap(find.text('Thêm vào so sánh'));
    await tester.pump();
    env.session.endSession();
    await tester.pump();
    pending.complete(const Reply(200, {'units': <Object?>[]}));
    await tester.pumpAndSettle();
    expect(find.text('P-A101'), findsNothing);
    expect(find.text('Đã thêm · chọn thêm căn'), findsNothing);
  });
}
