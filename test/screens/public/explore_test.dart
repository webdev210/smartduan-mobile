import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/screens/public/explore.dart';
import 'package:smartduan/screens/public/routes.dart';
import 'package:smartduan/ui/project_card.dart';

import '../../ui/project_browser_test.dart' show browserProjects;

void main() {
  test('Task D registers the guest home and public catalogue', () {
    expect(publicHomeScreens.keys, containsAll(['/', '/kham-pha']));
  });
  testWidgets(
    'query parameters filter the complete catalogue and resolve a legacy developer id after loading',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            listAllPublicProjectsProvider.overrideWith(
              (_) async => browserProjects,
            ),
            fetchProvincesProvider.overrideWith((_) async => []),
          ],
          child: const MaterialApp(
            home: PublicExplore(
              params: {
                'developer_id': 'd1',
                'project_type': 'apartment',
                'province': 'Hà Nội',
                'q': 'ho tay',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sun Group'), findsWidgets);
      expect(find.text('1 dự án'), findsOneWidget);
      expect(find.byType(ProjectCard), findsOneWidget);
      expect(find.text('Hồ Tây'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown project type is ignored and unfiltered explore focuses search',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            listAllPublicProjectsProvider.overrideWith(
              (_) async => browserProjects,
            ),
            fetchProvincesProvider.overrideWith((_) async => []),
          ],
          child: const MaterialApp(
            home: PublicExplore(params: {'project_type': 'unknown'}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 dự án'), findsOneWidget);
      expect(find.text('Tất cả dự án'), findsOneWidget);
    },
  );
  testWidgets(
    'empty explore remains refreshable and failed reads offer retry',
    (tester) async {
      var failed = true;
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            listAllPublicProjectsProvider.overrideWith((_) async {
              if (failed) throw Exception('offline');
              return [];
            }),
            fetchProvincesProvider.overrideWith((_) async => []),
          ],
          child: const MaterialApp(home: PublicExplore(params: {'q': ''})),
        ),
      );
      await tester.pumpAndSettle();
      failed = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có dự án công khai nào.'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    },
  );
}
