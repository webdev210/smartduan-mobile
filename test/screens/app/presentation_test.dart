import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/ui/stack_grid.dart';

import 'task_h_fakes.dart';

const board = {
  'project': {
    'id': 'p',
    'code': 'P',
    'name': 'Dự án mẫu',
    'developer_name': 'Chủ đầu tư',
    'district': 'Quận 1',
    'province': 'TP.HCM',
  },
  'blocks': [
    {'id': 'b', 'name': 'Toà A'},
    {'id': 'b2', 'name': 'Toà B'},
  ],
  'block_id': 'b',
};
const plan = {
  'block': {'id': 'b', 'name': 'Toà A'},
  'layout': 'floors',
  'axes': ['01'],
  'floors': [
    {
      'floor': 1,
      'cells': [
        {
          'id': 'u',
          'code': 'A101',
          'axis': '01',
          'status': 'available',
          'price_min': '999999999',
          'price_min_label': 'Khoảng 1 tỷ',
        },
      ],
    },
  ],
};

void main() {
  testWidgets('selecting a low floor scrolls the loaded detail into view', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) {
      if (r.path.endsWith('/presentation-board')) {
        return const Reply(200, board);
      }
      if (r.path.endsWith('/stack-plan')) {
        return Reply(200, {
          ...plan,
          'floors': List.generate(
            30,
            (i) => {
              'floor': i,
              'cells': [
                {
                  'id': 'u',
                  'code': 'Floor $i',
                  'axis': '01',
                  'status': 'available',
                },
              ],
            },
          ),
        });
      }
      return const Reply(200, {'id': 'u', 'code': 'Selected'});
    };
    await env.mount(tester, const PresentationScreen(projectId: 'p'));
    await tester.scrollUntilVisible(
      find.text('Floor 0'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Floor 0'));
    await tester.pumpAndSettle();
    expect(find.text('Căn Selected').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'customer board switches blocks and opens label-only unit detail',
    (tester) async {
      final env = HEnv();
      env.http.respond = (r) {
        if (r.path.endsWith('/presentation-board')) {
          return const Reply(200, board);
        }
        if (r.path.endsWith('/stack-plan')) return const Reply(200, plan);
        if (r.path.endsWith('/units/u/detail')) {
          return const Reply(200, {
            'id': 'u',
            'code': 'INTERNAL',
            'public_code': 'A101',
            'status': 'available',
            'unit_type': 'Căn hộ',
            'bedrooms': 2,
            'area_net': '50',
            'direction': 'Đông',
            'price_min_label': 'Khoảng 1 tỷ',
            'price_min': '999999999',
            'reserved_note': 'Ghi chú nội bộ',
            'held_by': 'Đầu mối riêng',
          });
        }
        return hReply(r.path);
      };
      await env.mount(tester, const PresentationScreen(projectId: 'p'));
      expect(find.text('Dự án mẫu'), findsOneWidget);
      expect(find.text('Chủ đầu tư · Quận 1 · TP.HCM'), findsOneWidget);
      expect(
        tester.widget<StackGrid>(find.byType(StackGrid)).priceLabel,
        isTrue,
      );
      await tester.tap(find.text('Toà B'));
      await tester.pumpAndSettle();
      expect(
        env.http.seen.any((r) => r.path.contains('/blocks/b2/stack-plan')),
        isTrue,
      );
      await tester.tap(find.text('A101'));
      await tester.pumpAndSettle();
      expect(find.text('Căn A101'), findsOneWidget);
      expect(find.text('Căn hộ · 2PN'), findsOneWidget);
      expect(find.text('Khoảng 1 tỷ'), findsWidgets);
      for (final hidden in [
        '999999999',
        'Ghi chú nội bộ',
        'Đầu mối riêng',
        'INTERNAL',
      ]) {
        expect(find.textContaining(hidden), findsNothing);
      }
      await tester.ensureVisible(find.text('Đóng'));
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Căn A101'), findsNothing);
    },
  );

  testWidgets('grid_too_large has source notice and no automatic retry', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => r.path.endsWith('/presentation-board')
        ? const Reply(200, board)
        : const Reply(422, {'error': 'grid_too_large'});
    await env.mount(tester, const PresentationScreen(projectId: 'p'));
    expect(
      find.text(
        'Toà này quá nhiều căn để trình chiếu dạng lưới — chọn toà khác hoặc dùng link chia sẻ.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 20));
    expect(
      env.http.seen.where((r) => r.path.endsWith('/stack-plan')).length,
      1,
    );
  });

  testWidgets('board loading, failure, retry and no-block empty state', (
    tester,
  ) async {
    final env = HEnv();
    final pending = Completer<Reply>();
    env.http.respond = (_) => pending.future;
    await env.mount(
      tester,
      const PresentationScreen(projectId: 'p'),
      settle: false,
    );
    await tester.pump();
    expect(find.byType(StackGrid), findsNothing);
    pending.complete(const Reply(403, {'message': 'Bạn không có quyền'}));
    await tester.pumpAndSettle();
    expect(find.text('Bạn không có quyền'), findsOneWidget);
    env.http.respond = (_) => const Reply(200, {
      'project': {'id': 'p', 'code': 'P', 'name': 'Dự án mẫu'},
      'blocks': <Object?>[],
    });
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Dự án mẫu'), findsOneWidget);
    expect(
      env.http.seen.every((r) => r.path.endsWith('/presentation-board')),
      isTrue,
    );
  });

  testWidgets(
    'stack error retries manually; empty stack and unit defaults render',
    (tester) async {
      final env = HEnv();
      var fail = true;
      env.http.respond = (r) {
        if (r.path.endsWith('/presentation-board')) {
          return const Reply(200, board);
        }
        if (r.path.endsWith('/stack-plan')) {
          return fail
              ? const Reply(503, {'message': 'Thử lại sau'})
              : const Reply(200, plan);
        }
        return const Reply(200, {'id': 'u', 'code': 'A101'});
      };
      await env.mount(tester, const PresentationScreen(projectId: 'p'));
      expect(find.text('Thử lại sau'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A101'));
      await tester.pumpAndSettle();
      expect(find.text('Liên hệ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
