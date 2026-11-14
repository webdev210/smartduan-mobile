import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/api/models.dart';

import 'board_filter_test.dart' show boardPlan;

void main() {
  testWidgets(
    'lazy floors share horizontal offset including newly mounted rows',
    (tester) async {
      final plan = StackPlan.fromJson({
        'block': {'id': 'b'},
        'layout': 'floors',
        'axes': List.generate(12, (i) => '$i'),
        'floors': List.generate(
          100,
          (floor) => {
            'floor': floor,
            'cells': List.generate(
              12,
              (axis) => {
                'id': '$floor-$axis',
                'code': '$floor-$axis',
                'axis': '$axis',
                'status': 'available',
              },
            ),
          },
        ),
      });
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [StackGrid(sliver: true, plan: plan, onOpen: (_) {})],
            ),
          ),
        ),
      );
      expect(find.text('0-0'), findsNothing);
      expect(find.byType(InkWell).evaluate().length, lessThan(300));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(-2000, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('99-11').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final horizontal = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((s) => s.widget.axisDirection == AxisDirection.right)
          .toList();
      expect(horizontal.length, greaterThan(2));
      for (final scroll in horizontal) {
        expect(
          scroll.position.pixels,
          closeTo(horizontal.first.position.pixels, .01),
        );
        expect(scroll.position.pixels, greaterThan(500));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'floors descend, axes align, sold label and excluded cells are disabled',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StackGrid(
              plan: boardPlan,
              keep: (_) => false,
              onOpen: (id) => opened = id,
              fundColors: {'chung': '#ff0000'},
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('T2')).dy,
        lessThan(tester.getTopLeft(find.text('T1')).dy),
      );
      expect(find.text('Đã bán'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      await tester.tap(find.text('A-01.01'));
      expect(opened, isNull);
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.2),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('row layout uses row names and presentation price labels', (
    tester,
  ) async {
    final plan = StackPlan.fromJson({
      'block': {'id': 'b'},
      'layout': 'rows',
      'floors': [
        {
          'floor': 1,
          'name': 'Dãy Đông',
          'cells': [
            {
              'id': 'u',
              'code': 'U',
              'status': 'available',
              'price_min_label': '3 tỷ',
            },
          ],
        },
        {'floor': 2, 'cells': <Object?>[]},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StackGrid(plan: plan, priceLabel: true, onOpen: (_) {}),
        ),
      ),
    );
    expect(find.text('Dãy Đông'), findsOneWidget);
    expect(find.text('Dãy 2'), findsOneWidget);
    expect(find.text('3 tỷ'), findsOneWidget);
    expect(find.text('T1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty stack has source Vietnamese text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StackGrid(
          plan: const StackPlan(block: BlockRef(id: 'b')),
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.text('Toà này chưa có căn nào bạn được xem.'), findsOneWidget);
  });
  testWidgets(
    'wide stack scrolls horizontally without overflow on narrow screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final plan = StackPlan.fromJson({
        'block': {'id': 'b'},
        'layout': 'floors',
        'axes': List.generate(12, (i) => '$i'),
        'floors': [
          {
            'floor': 1,
            'cells': List.generate(
              12,
              (i) => {
                'id': '$i',
                'axis': '$i',
                'code': 'Unit$i',
                'status': 'available',
              },
            ),
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StackGrid(plan: plan, onOpen: (_) {}),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-2000, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Unit11').hitTestable(), findsOneWidget);
    },
  );
}
