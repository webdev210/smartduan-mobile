import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/preview_text.dart';

void main() {
  testWidgets('long preview expands, collapses and resets for new content', (
    tester,
  ) async {
    final long = List.filled(10, 'Thông tin dự án').join('\n');
    Future<void> mount(String text) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PreviewText(text))),
      ),
    );

    await mount(long);
    expect(tester.widget<Text>(find.text(long)).maxLines, 6);
    await tester.tap(find.text('Xem thêm'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    await tester.tap(find.text('Thu gọn'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(long)).maxLines, 6);
    await tester.tap(find.text('Xem thêm'));
    await tester.pump();
    await mount('$long\nNội dung mới');
    expect(tester.widget<Text>(find.text('$long\nNội dung mới')).maxLines, 6);
    await mount('Nội dung ngắn');
    expect(find.text('Xem thêm'), findsNothing);
    expect(find.text('Thu gọn'), findsNothing);
  });
}
