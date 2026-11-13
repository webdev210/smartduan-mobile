import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/screens/app/top_units.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'task_h_fakes.dart';

void main() {
  testWidgets('all four top modes request their mode and have empty states', (
    tester,
  ) async {
    final modes = <String>[];
    final env = HEnv();
    env.http.respond = (r) {
      modes.add(r.queryParameters['mode'] as String);
      return const Reply(200, {'groups': <Object?>[]});
    };
    await env.mount(tester, const TopUnitsScreen(projectId: 'p'));
    expect(find.text('Dự án chưa có căn còn hàng.'), findsOneWidget);
    for (final label in ['Căn đẹp', 'Căn góc', 'Sàn chọn']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(modes, ['cheap', 'nice', 'corner', 'manual']);
    expect(
      find.text('Sàn chưa chọn căn nổi bật cho dự án này.'),
      findsOneWidget,
    );
  });
  testWidgets('reasons, decimals and filters are local; opens unit', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (_) => const Reply(200, {
      'groups': [
        {
          'unit_type': 'Căn hộ',
          'bedrooms': 2,
          'available': 1,
          'units': [
            {
              'id': 'u',
              'code': 'A101',
              'area': '50.5',
              'price_min': '400000000',
              'why': ['', 'Giá tốt', 'View sông'],
            },
          ],
        },
        {'unit_type': 'Biệt thự', 'available': 0, 'units': <Object?>[]},
      ],
    });
    final router = await env.mount(
      tester,
      const TopUnitsScreen(projectId: 'p'),
    );
    expect(find.textContaining('Giá tốt · View sông'), findsOneWidget);
    final label = find.text('A101 · 400 tr');
    final card = find
        .ancestor(of: label, matching: find.byType(kit.Card))
        .first;
    expect(
      tester.getTopLeft(label).dx - tester.getTopLeft(card).dx,
      closeTo(16, 1),
    );
    expect(find.textContaining('50,5 m²'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'View song');
    await tester.pumpAndSettle();
    expect(find.text('Căn hộ · 2PN'), findsOneWidget);
    expect(find.text('Biệt thự'), findsNothing);
    expect(env.http.seen, hasLength(1));
    await tester.tap(find.text('A101 · 400 tr'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/can/u');
  });
  testWidgets('top error can retry', (tester) async {
    final env = HEnv();
    env.http.respond = (_) =>
        const Reply(500, {'message': 'Có lỗi, vui lòng thử lại'});
    await env.mount(tester, const TopUnitsScreen(projectId: 'p'));
    expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
    env.http.respond = (_) => const Reply(200, {'groups': <Object?>[]});
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Dự án chưa có căn còn hàng.'), findsOneWidget);
  });
}
