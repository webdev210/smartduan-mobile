import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/public/home.dart';
import 'package:smartduan/ui/kit.dart' show Segmented;
import 'package:smartduan/ui/favorite_button.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/project_compare_kit.dart' show CompareChip;
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_region_section.dart';

import '../../support/responsive.dart';
import '../../auth/token_store_test.dart' show MemoryStorage;
import '../public/home_test.dart' show GuestSession, homeReply;
import 'task_h_fakes.dart';

final regionSection = find.byType(ProjectRegionSection);
final regionCards = find.descendant(
  of: regionSection,
  matching: find.byType(ProjectCard),
);
List<String> railIds(WidgetTester tester) =>
    tester.widgetList<ProjectCard>(regionCards).map((c) => c.p.id).toList();

class HomeFixture {
  HomeFixture({
    required this.signedIn,
    this.state = 'data',
    List<String>? places,
  }) {
    final provinces = places ?? ['Hà Nội', 'Đà Nẵng', 'TP.HCM'];
    final data = [
      for (final (i, province) in provinces.indexed)
        {
          ...hProject,
          'id': 'p$i',
          'code': 'P$i',
          'name': i == 0 ? 'Dự án mẫu' : 'Dự án ven sông với tên dài $i',
          'province': province,
          'is_public': true,
        },
    ];
    client = ApiClient(
      tokens: SecureValue('home-test', storage: MemoryStorage()),
      adapter: FakeHttp((r) {
        if (r.path == '/me/saved-projects') {
          return Reply(200, {
            'codes': r.method == 'POST' ? ['P0'] : <String>[],
          });
        }
        if (r.path == '/projects' || r.path == '/public/projects') {
          if (state == 'loading') return Completer<Reply>().future;
          return Reply(200, {
            'data': data,
            'total': data.length,
            'page': 1,
            'per_page': 200,
          });
        }
        return signedIn ? hReply(r.path) : homeReply(r.path);
      }),
    );
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(
          () => signedIn ? HSession(['agent']) : GuestSession(),
        ),
        apiClientProvider.overrideWithValue(client),
        publicApiProvider.overrideWithValue(PublicApi(client)),
      ],
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => signedIn
              ? const Scaffold(body: HomeScreen())
              : const PublicHome(),
        ),
        for (final path in ['/du-an/:id', '/cong-khai/:code', '/other'])
          GoRoute(
            path: path,
            builder: (_, s) => Scaffold(body: Text(s.uri.path)),
          ),
      ],
    );
  }
  final bool signedIn;
  final String state;
  late final ApiClient client;
  late final ProviderContainer container;
  late final GoRouter router;
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void dispose() {
    router.dispose();
    container.dispose();
    client.close();
  }
}

Future<void> choose(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: regionSection,
    matching: find.textContaining(label),
  );
  await Scrollable.ensureVisible(tester.element(segment), alignment: .5);
  await tester.pumpAndSettle();
  expect(segment.hitTestable(), findsOneWidget);
  await tester.tap(segment);
  await tester.pump();
}

void main() {
  for (final signedIn in [true, false]) {
    final home = signedIn ? 'signed-in' : 'guest';
    testWidgets('$home section switches regions and opens correct detail', (
      t,
    ) async {
      final fixture = HomeFixture(signedIn: signedIn);
      addTearDown(fixture.dispose);
      await fixture.mount(t);
      expect(find.text('Dự án theo khu vực'), findsOneWidget);
      expect(railIds(t), ['p0']);
      await choose(t, 'Miền Trung');
      expect(railIds(t), ['p1']);
      await choose(t, 'Miền Nam');
      expect(railIds(t), ['p2']);
      await t.ensureVisible(regionCards.first);
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: regionCards.first,
          matching: find.textContaining('Dự án ven sông'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        fixture.router.state.uri.path,
        signedIn ? '/du-an/p2' : '/cong-khai/P2',
      );
    });
    for (final state in ['data', 'empty region', 'loading']) {
      testWidgets('$home region section $state responsive matrix', (t) async {
        await expectResponsive(t, () async {
          final fixture = HomeFixture(
            signedIn: signedIn,
            state: state,
            places: ['Hà Nội', 'Hà Nội', 'Đà Nẵng'],
          );
          await fixture.mount(t);
          if (state == 'empty region') await choose(t, 'Miền Nam');
          if (state == 'data') {
            await choose(t, 'Miền Trung');
            expect(railIds(t), ['p2']);
            await choose(t, 'Miền Bắc');
          }
          await t.ensureVisible(regionSection);
          await t.pump();
          if (state == 'loading') {
            expect(
              find.descendant(
                of: regionSection,
                matching: find.byType(ProjectCardSkeleton),
              ),
              findsNWidgets(2),
            );
          } else if (state == 'empty region') {
            expect(find.text('Chưa có dự án tại khu vực này.'), findsOneWidget);
          } else {
            expect(t.widgetList<ProjectCard>(regionCards), hasLength(2));
            expect(
              t.getSize(regionCards.first).height,
              t.getSize(regionCards.last).height,
            );
          }
          await t.pumpWidget(const SizedBox());
          fixture.dispose();
        });
      });
    }
  }
  testWidgets(
    'signed-in default uses first populated region with labels and section order',
    (t) async {
      final fixture = HomeFixture(
        signedIn: true,
        places: ['TP.HCM', 'Đà Nẵng'],
      );
      addTearDown(fixture.dispose);
      await fixture.mount(t);
      expect(railIds(t), ['p1']);
      expect(find.text('Miền Bắc'), findsOneWidget);
      expect(find.text('Miền Trung'), findsOneWidget);
      expect(find.text('Miền Nam'), findsOneWidget);
      final sections = [
        'Dự án của bạn',
        'Dự án theo khu vực',
        'Truy cập nhanh',
        'Bảng tin mới',
      ];
      for (var i = 1; i < sections.length; i++) {
        expect(
          t.getTopLeft(find.text(sections[i])).dy,
          greaterThan(t.getTopLeft(find.text(sections[i - 1])).dy),
        );
      }
    },
  );
  testWidgets(
    'signed-in region uses all allocations and survives leaving home',
    (t) async {
      final fixture = HomeFixture(
        signedIn: true,
        places: [...List.filled(9, 'Hà Nội'), 'Đà Nẵng'],
      );
      addTearDown(fixture.dispose);
      await fixture.mount(t);
      expect(railIds(t), hasLength(9));
      await choose(t, 'Miền Trung');
      expect(railIds(t), ['p9']);
      fixture.router.go('/other');
      await t.pumpAndSettle();
      fixture.router.go('/');
      await t.pumpAndSettle();
      expect(railIds(t), ['p9']);
    },
  );
  testWidgets('guest retains north default and six-card limit', (t) async {
    final fixture = HomeFixture(
      signedIn: false,
      places: List.filled(9, 'Hà Nội'),
    );
    addTearDown(fixture.dispose);
    await fixture.mount(t);
    expect(railIds(t), hasLength(6));
    expect(
      t
          .widget<Segmented<String>>(
            find.descendant(
              of: regionSection,
              matching: find.byType(Segmented<String>),
            ),
          )
          .value,
      'bac',
    );
  });

  testWidgets('region cards reuse signed-in favourite and compare controls', (
    t,
  ) async {
    final fixture = HomeFixture(signedIn: true);
    addTearDown(fixture.dispose);
    await fixture.mount(t);
    final favourite = find.descendant(
      of: regionCards.first,
      matching: find.byType(FavoriteButton),
    );
    final compare = find.descendant(
      of: regionCards.first,
      matching: find.byType(CompareChip),
    );
    expect(t.widget<FavoriteButton>(favourite).code, 'P0');
    expect(t.widget<CompareChip>(compare).code, 'P0');
    await t.ensureVisible(favourite);
    await t.pumpAndSettle();
    await t.tap(favourite);
    await t.pumpAndSettle();
    expect(fixture.container.read(savedProjectsProvider).value, ['P0']);
    await t.tap(favourite);
    await t.pumpAndSettle();
    expect(fixture.container.read(savedProjectsProvider).value, isEmpty);
    await t.ensureVisible(compare);
    await t.pumpAndSettle();
    await t.tap(compare);
    await t.pumpAndSettle();
    expect(fixture.container.read(projectCompareProvider), ['P0']);
    expect(fixture.router.state.uri.path, '/');
  });
}
