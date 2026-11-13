import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/screens/app/compare_units.dart';

import 'task_h_fakes.dart';

void main() {
  testWidgets('compare empty state', (tester) async {
    final env = HEnv();
    await env.mount(tester, const CompareUnitsScreen());
    expect(
      find.text('Chưa có căn nào. Mở chi tiết căn → “Thêm vào so sánh”.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'compare rows, removed notice, nullable fields, remove and invalidate',
    (tester) async {
      final env = HEnv();
      var removed = false;
      env.http.respond = (r) {
        if (r.method == 'DELETE') {
          removed = true;
          return const Reply(200);
        }
        return removed
            ? const Reply(200, {'units': <Object?>[]})
            : const Reply(200, {
                'units': [
                  {
                    ...hUnit,
                    'project': {'id': 'p', 'name': 'Dự án mẫu', 'code': 'P'},
                    'policy': {'name': 'CSBH mẫu'},
                  },
                ],
                'removed': ['x'],
              });
      };
      await env.mount(tester, const CompareUnitsScreen());
      expect(find.text('50,5 m²'), findsOneWidget);
      expect(find.text('400 tr'), findsOneWidget);
      expect(find.text('CSBH mẫu'), findsOneWidget);
      expect(
        find.text('1 căn đã bị gỡ khỏi danh sách (không còn xem được).'),
        findsOneWidget,
      );
      await tester.tap(find.text('Bỏ'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
      expect(
        find.text('Chưa có căn nào. Mở chi tiết căn → “Thêm vào so sánh”.'),
        findsOneWidget,
      );
      expect(env.http.seen.where((r) => r.method == 'DELETE'), hasLength(1));
    },
  );
  testWidgets('compare fetch failure and remove failure are visible', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => r.method == 'DELETE'
        ? const Reply(403, {'message': 'Không thể bỏ căn'})
        : const Reply(200, {
            'units': [hUnit],
          });
    await env.mount(tester, const CompareUnitsScreen());
    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể bỏ căn'), findsOneWidget);
    expect(find.text('P-A101'), findsOneWidget);
    expect(env.http.seen.where((r) => r.method == 'DELETE'), hasLength(1));
  });
}
