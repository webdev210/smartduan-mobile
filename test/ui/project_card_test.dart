import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/auth/session.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/developer_chip.dart';

import '../screens/auth/auth_fakes.dart' show TestSession;

void main() {
  testWidgets(
    'bounded cards align their facts at the bottom of a horizontal rail',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith(TestSession.new)],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 480,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProjectCard(
                      width: 240,
                      p: const ProjectCardData(
                        name: 'Short',
                        code: 'A',
                        status: 'selling',
                        priceFrom: '2000000000',
                        activity7d: 5,
                      ),
                      onPress: () {},
                    ),
                    ProjectCard(
                      width: 240,
                      p: const ProjectCardData(
                        name: 'Dự án tên dài xuống hai dòng để kiểm tra',
                        code: 'B',
                        status: 'selling',
                        province: 'Hà Nội',
                        developerName: 'Sun Group',
                        priceFrom: '3000000000',
                        activity7d: 5,
                      ),
                      onPress: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final facts = find.text('Giá từ');
      expect(
        tester.getTopLeft(facts.at(0)).dy,
        tester.getTopLeft(facts.at(1)).dy,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('developer navigation uses slug or catalogue filter fallback', () {
    expect(
      developerPath(id: 'd', name: 'Sun Group', slug: 'sun/group'),
      '/chu-dau-tu/sun%2Fgroup',
    );
    final fallback = Uri.parse(developerPath(id: 'd', name: 'Sun Group'));
    expect(fallback.path, '/kham-pha');
    expect(fallback.queryParameters, {
      'developer_id': 'd',
      'developer': 'Sun Group',
    });
  });
  testWidgets(
    'standalone media exposes tour label and compact mode hides badges',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: ProjectMedia(
                name: 'Sun Group',
                status: 'selling',
                tour: true,
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('Có tour 360 độ')), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 92,
              child: ProjectMedia(
                name: 'Sun Group',
                status: 'selling',
                tour: true,
                compact: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('360°'), findsNothing);
      expect(find.text('Đang bán'), findsNothing);
      expect(find.text('SG'), findsOneWidget);
    },
  );
  testWidgets('image and logo errors show initials or business fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(
                width: 200,
                child: ProjectMedia(
                  name: 'Sun Group',
                  uri: 'https://example.test/missing.jpg',
                ),
              ),
              DeveloperChip(
                name: 'Sun Group',
                logo: 'https://example.test/missing.png',
                onPress: () {},
              ),
            ],
          ),
        ),
      ),
    );
    // Flutter's test HTTP boundary returns 400 for both image requests.
    await tester.pumpAndSettle();
    expect(find.text('SG'), findsWidgets);
    expect(find.byIcon(Ionicons.businessOutline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('inventory update takes precedence over activity as in RN', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectCard(
              p: const ProjectCardData(
                name: 'Dự án',
                status: 'selling',
                inventoryUpdatedAt: '2026-11-12T00:00:00Z',
                activity7d: 9,
              ),
              onPress: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Rổ hàng cập nhật 07:00 12/11/2026'), findsOneWidget);
    expect(find.text('9 giao dịch trong 7 ngày qua'), findsNothing);
  });
  testWidgets(
    'card displays RN facts, status, tour and callback on narrow screens',
    (tester) async {
      var pressed = 0;
      final p = PublicProject(
        id: 'p',
        name: 'Artisan Park',
        code: 'P',
        status: 'selling',
        projectType: 'mixed',
        province: 'Bình Dương',
        priceFrom: '2500000000',
        activity7d: 3,
        hasTour360: true,
        developer: const ProjectDeveloper(id: 'd', name: 'CĐT'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith(TestSession.new)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 280,
                  child: ProjectCard(p: p, onPress: () => pressed++),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Artisan Park'), findsOneWidget);
      expect(find.text('Cao tầng & thấp tầng'), findsOneWidget);
      expect(find.text('Đang bán'), findsOneWidget);
      expect(find.text('3 giao dịch trong 7 ngày qua'), findsOneWidget);
      expect(find.text('360°'), findsOneWidget);
      await tester.tap(find.text('Artisan Park'));
      expect(pressed, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('compact row shows initials and contact fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(TestSession.new)],
        child: MaterialApp(
          home: Scaffold(
            body: ProjectRow(
              p: PublicProject(
                id: '1',
                name: 'Sun Urban',
                code: 'S',
                status: 'upcoming',
              ),
              onPress: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('SU'), findsOneWidget);
    expect(find.text('Liên hệ'), findsOneWidget);
    expect(find.text('Sắp mở bán'), findsOneWidget);
  });
  testWidgets('developer chip provides accessible callback and icon fallback', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeveloperChip(
            name: 'Sun Group',
            logo: null,
            onPress: () => pressed = true,
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Dự án của Sun Group'), findsOneWidget);
    await tester.tap(find.text('Sun Group'));
    expect(pressed, true);
  });
}
