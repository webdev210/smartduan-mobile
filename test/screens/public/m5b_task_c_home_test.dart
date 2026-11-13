import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/project_card.dart';

import '../../api/fake_http.dart';
import '../../api/public_test.dart' show projectJson;
import 'home_test.dart' show mountHome, homeReply;

void main() {
  testWidgets('37 news events and developers expose independent recovery', (
    tester,
  ) async {
    final attempts = <String, int>{};
    final http = FakeHttp((c) {
      final key = '${c.path}:${c.queryParameters['kind'] ?? ''}';
      attempts.update(key, (v) => v + 1, ifAbsent: () => 1);
      if (c.path == '/public/posts' || c.path == '/public/developers') {
        return const Reply(500, {'error': 'server_error'});
      }
      return homeReply(c.path);
    });
    await mountHome(tester, http);
    expect(find.text('Tin mới'), findsOneWidget);
    expect(find.text('Sự kiện'), findsOneWidget);
    expect(find.text('Theo chủ đầu tư'), findsOneWidget);
    expect(find.text('Thử lại'), findsNWidgets(3));
    await tester.ensureVisible(find.text('Thử lại').first);
    await tester.pump();
    await tester.tap(find.text('Thử lại').first);
    await tester.pumpAndSettle();
    expect(attempts['/public/posts:news'], 2);
    expect(attempts['/public/posts:event'], 1);
    expect(attempts['/public/developers:'], 1);
  });

  for (final size in [const Size(1024, 768), const Size(844, 390)]) {
    testWidgets('17 hero is bounded and content centred at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mountHome(
        tester,
        FakeHttp(
          (c) => c.path == '/public/projects'
              ? Reply(200, {
                  'data': [projectJson('A')],
                  'page': 1,
                  'per_page': 50,
                  'total': 1,
                })
              : homeReply(c.path),
        ),
      );
      final hero = tester.getRect(find.byKey(const ValueKey('public-hero')));
      expect(hero.height, lessThanOrEqualTo(size.height * .6));
      expect(hero.width, lessThanOrEqualTo(640));
      expect(hero.center.dx, closeTo(size.width / 2, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('44 horizontal project cards have matched bottoms', (
    tester,
  ) async {
    await mountHome(
      tester,
      FakeHttp(
        (c) => c.path == '/public/projects'
            ? Reply(200, {
                'data': [
                  projectJson('A'),
                  {
                    ...projectJson('B'),
                    'name': 'Dự án có tên rất dài để kiểm tra chiều cao đồng đều trên cùng một hàng',
                  },
                ],
                'page': 1,
                'per_page': 50,
                'total': 2,
              })
            : homeReply(c.path),
      ),
    );
    final cards = find.byType(ProjectCard);
    expect(
      tester.getSize(cards.at(0)).height,
      tester.getSize(cards.at(1)).height,
    );
  });
}
