import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/loan_result_cards.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/ui/theme.dart' as c;

import 'board_filter_test.dart' show boardPlan;

void main() {
  // RN main: primary keeps the brand gradient and shadow, and dims on press.
  testWidgets('primary uses the RN brand gradient', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: kit.Button(title: 'Xem bảng hàng', onPress: () {}),
        ),
      ),
    );
    final fill = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(kit.Button),
            matching: find.byType(Container),
          ),
        )
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .first;
    expect(fill.gradient, c.brandGradient);
    expect(fill.boxShadow, c.brandShadow);
  });
  testWidgets('Screen keeps scroll position when slivers arrive', (
    tester,
  ) async {
    Widget page(bool loaded) => MaterialApp(
      home: Scaffold(
        body: kit.Screen(
          slivers: loaded
              ? [const SliverToBoxAdapter(child: Text('Đã tải'))]
              : [],
          children: List.generate(30, (i) => Text('Dòng $i')),
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.drag(find.byType(Scrollable), const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(find.byType(Scrollable));
    final offset = before.position.pixels;
    await tester.pumpWidget(page(true));
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)),
      same(before),
    );
    expect(before.position.pixels, offset);
  });
  testWidgets('loan headline precedes supporting values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: kit.Screen(
            children: [
              LoanResultCards(
                r: LoanResult.fromJson({'monthly_payment': 12345678}),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Trả hàng tháng — kỳ đầu'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Trả hàng tháng — kỳ đầu')).dy,
      lessThan(tester.getTopLeft(find.text('Giá')).dy),
    );
  });
  testWidgets('excluded grid cells cannot open and list shows status', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: kit.Screen(
            children: [
              StackGrid(
                plan: boardPlan,
                keep: (cell) => cell.status != 'sold',
                onOpen: (id) => opened = id,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('A-02.01'));
    expect(opened, isNull);
    await tester.tap(find.text('Danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('A-02.01'), findsNothing);
    expect(find.textContaining('Còn hàng'), findsWidgets);
    await tester.tap(find.text('A-01.01'));
    expect(opened, 'A-01.01');
  });
}
