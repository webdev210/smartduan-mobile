import 'dart:async';

import 'package:ionicons/ionicons.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/ui/favorite_button.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/project_compare_kit.dart';
import 'package:smartduan/ui/unit_compare_picker.dart';
import 'package:smartduan/screens/public/project_compare.dart';

import '../api/fake_http.dart';
import '../auth/token_store_test.dart' show MemoryStorage;

class DeltaSession extends Session {
  DeltaSession(this.status);
  final SessionStatus status;
  @override
  SessionState build() => SessionState(status);
}

void main() {
  late ProviderContainer container;
  late FakeHttp http;
  late ApiClient client;
  late GoRouter router;
  var saved = <String>[];
  var picked = <String>['u1'];
  Reply? failure;
  Completer<Reply>? pending;
  // Exact projectCompareKit.test.tsx catalogue fixture from RN.
  Map<String, Object?> pickerProject(String code, String name) => {
    'id': code,
    'code': code,
    'name': name,
    'province': 'Hà Nội',
    'status': 'selling',
    'developer': null,
    'cover_url': null,
  };
  Map<String, Object?> project(String code, String name) => {
    'id': code,
    'code': code,
    'name': name,
    'status': 'selling',
    'project_type': 'apartment',
    'province': 'Đà Nẵng',
    'developer': {'id': 'd', 'name': 'Sun Group'},
    'documents': [],
    'has_tour360': code == 'A',
    'activity_7d': code == 'A' ? 12 : 0,
    if (code == 'A')
      'overview_json': {
        'handover': 'Quý 4/2027',
        'amenities': ['Hồ bơi', 'Gym'],
      },
  };
  Map<String, Object?> unit(String id, String code) => {
    'id': id,
    'project_id': 'P',
    'code': code,
    'public_code': code,
    'status': 'available',
    'title': '',
    'unit_type': '2PN',
    'price_min': '3000000000',
  };
  setUp(() {
    saved = [];
    picked = ['u1'];
    failure = null;
    pending = null;
    http = FakeHttp((o) async {
      if (o.path == '/me/saved-projects') {
        if (o.method != 'GET' && pending != null) return pending!.future;
        if (o.method != 'GET' && failure != null) return failure!;
        final body = o.data as Map<String, dynamic>?;
        if (o.method == 'POST') {
          saved.addAll((body!['codes'] as List).cast<String>());
        }
        if (o.method == 'DELETE') saved.remove(body!['code']);
        return Reply(200, {'codes': saved});
      }
      if (o.path == '/projects/P/units') {
        return Reply(200, {
          'data': [unit('u1', 'A-01'), unit('u2', 'A-02'), unit('u3', 'B-01')],
          'page': 1,
          'per_page': 50,
          'total': 3,
        });
      }
      if (o.path.startsWith('/sales/me/compare')) {
        if (o.method == 'POST') {
          final id = (o.data as Map)['unit_id'] as String;
          if (id == 'u3') {
            return const Reply(422, {
              'error': 'compare_full',
              'message': 'Rổ so sánh đã đủ 4 căn.',
            });
          }
          picked.add(id);
        }
        if (o.method == 'DELETE') picked.remove(o.path.split('/').last);
        return Reply(200, {
          'units': [
            for (final id in picked) {'id': id},
          ],
          'removed': <String>[],
        });
      }
      if (o.path == '/public/projects') {
        return Reply(200, {
          'data': [
            pickerProject('A', 'Dự án An'),
            pickerProject('B', 'Dự án Bình'),
            pickerProject('C', 'Dự án Cầu'),
            pickerProject('D', 'Dự án Đông'),
          ],
          'page': 1,
          'per_page': 50,
          'total': 4,
        });
      }
      return Reply(
        200,
        project(
          o.path.split('/').last,
          o.path.endsWith('/A') ? 'Dự án An' : 'Dự án Bình',
        ),
      );
    });
    client = ApiClient(
      adapter: http,
      tokens: SecureValue('test', storage: MemoryStorage()),
    );
  });
  tearDown(() {
    router.dispose();
    container.dispose();
    client.close();
  });
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    bool signedIn = false,
  }) async {
    container = ProviderContainer.test(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        sessionProvider.overrideWith(
          () => DeltaSession(
            signedIn ? SessionStatus.signedIn : SessionStatus.guest,
          ),
        ),
      ],
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        for (final path in ['/dang-nhap', '/so-sanh-du-an', '/so-sanh'])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('route $path')),
          ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('photo splash keeps app, tagline, brand and accessible label', (
    t,
  ) async {
    // Do not settle the repeating spinner.
    container = ProviderContainer.test();
    router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const BrandSplash())],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Smart Dự Án'), findsOneWidget);
    expect(find.text('SMARTLAND'), findsOneWidget);
    expect(find.image(const AssetImage('assets/splash.webp')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data?.replaceAll('\u00a0', ' ') ==
                'Bảng hàng & dự án bất động sản trong tay bạn',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Đang mở Smart Dự Án'), findsOneWidget);
  });
  testWidgets('intro remains on for 1400ms', (t) async {
    container = ProviderContainer.test();
    router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    );
    final subscription = container.listen(
      introDelayProvider(const Duration(milliseconds: 1400)),
      (_, _) {},
    );
    expect(subscription.read(), true);
    await t.pump(const Duration(milliseconds: 1399));
    expect(subscription.read(), true);
    await t.pump(const Duration(milliseconds: 1));
    expect(subscription.read(), false);
  });
  testWidgets('heart saves public code and removes it on second tap', (
    t,
  ) async {
    await show(
      t,
      const FavoriteButton(code: 'SUN1', name: 'Beachtro Tower'),
      signedIn: true,
    );
    await press(t, find.bySemanticsLabel('Yêu thích Beachtro Tower'));
    expect(
      find.bySemanticsLabel('Bỏ yêu thích Beachtro Tower'),
      findsOneWidget,
    );
    expect(http.seen.firstWhere((o) => o.method == 'POST').data, {
      'codes': ['SUN1'],
    });
    await press(t, find.bySemanticsLabel('Bỏ yêu thích Beachtro Tower'));
    expect(saved, isEmpty);
    expect(
      http.seen.any(
        (o) => o.method == 'DELETE' && o.path == '/me/saved-projects',
      ),
      true,
    );
  });
  testWidgets('guest heart opens login without API calls', (t) async {
    await show(t, const FavoriteButton(code: 'SUN1', name: 'Beachtro Tower'));
    await press(t, find.bySemanticsLabel('Yêu thích Beachtro Tower'));
    expect(router.state.uri.path, '/dang-nhap');
    expect(http.seen, isEmpty);
  });
  testWidgets('optimistic heart is shared and rolls back on failure', (
    t,
  ) async {
    await show(
      t,
      const Column(
        children: [
          FavoriteButton(code: 'A', name: 'one'),
          FavoriteButton(code: 'A', name: 'two'),
        ],
      ),
      signedIn: true,
    );
    pending = Completer<Reply>();
    await t.tap(find.bySemanticsLabel('Yêu thích one'));
    await t.pump();
    expect(find.bySemanticsLabel('Bỏ yêu thích two'), findsOneWidget);
    pending!.complete(
      const Reply(422, {
        'error': 'bad_request',
        'message': 'Không lưu được dự án.',
      }),
    );
    await t.pumpAndSettle();
    expect(find.text('Không lưu được'), findsOneWidget);
    await press(t, find.text('OK'));
    expect(find.bySemanticsLabel('Yêu thích two'), findsOneWidget);
  });
  testWidgets(
    'public card and row expose independent heart and compare controls',
    (t) async {
      await show(
        t,
        SingleChildScrollView(
          child: Column(
            children: [
              ProjectCard(
                p: const Browsable(
                  name: 'Sun Symphony',
                  status: 'selling',
                  code: 'SUN1',
                ),
                onPress: () {},
              ),
              ProjectRow(
                p: const Browsable(
                  name: 'Sun Row',
                  status: 'selling',
                  code: 'SUN1',
                ),
                onPress: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Yêu thích Sun Symphony'), findsOneWidget);
      expect(find.bySemanticsLabel('So sánh Sun Symphony'), findsOneWidget);
      expect(find.bySemanticsLabel('Yêu thích Sun Row'), findsOneWidget);
    },
  );
  testWidgets('private card hides favourite and compare', (t) async {
    await show(
      t,
      SingleChildScrollView(
        child: ProjectCard(
          p: const Browsable(
            name: 'Sun Symphony',
            status: 'selling',
            code: 'SUN1',
            isPublic: false,
          ),
          onPress: () {},
        ),
      ),
    );
    expect(find.byType(FavoriteButton), findsNothing);
    expect(find.byType(CompareChip), findsNothing);
  });
  testWidgets('compare tap toggles project', (t) async {
    await show(t, const CompareChip(code: 'A', name: 'Dự án An'));
    await press(t, find.bySemanticsLabel('So sánh Dự án An'));
    expect(container.read(projectCompareProvider), ['A']);
    await press(t, find.bySemanticsLabel('So sánh Dự án An'));
    expect(container.read(projectCompareProvider), isEmpty);
  });
  testWidgets(
    'holding compare adds current project and picker opens comparison at two',
    (t) async {
      http.respond = (_) => Reply(200, {
        'data': [
          for (final (code, name) in [
            ('A', 'Dự án An'),
            ('B', 'Dự án Bình'),
            ('C', 'Dự án Cầu'),
            ('D', 'Dự án Đông'),
          ])
            {
              'id': code,
              'code': code,
              'name': name,
              'province': 'Hà Nội',
              'status': 'selling',
              'developer': null,
              'cover_url': null,
            },
        ],
        'page': 1,
        'per_page': 50,
        'total': 4,
      });
      await show(t, const CompareChip(code: 'A', name: 'Dự án An'));
      expect(container.read(projectCompareProvider), isEmpty);
      expect(http.seen, isEmpty);
      await t.longPress(find.bySemanticsLabel('So sánh Dự án An'));
      await t.pumpAndSettle();
      expect(container.read(projectCompareProvider), ['A']);
      expect(find.text('Chọn dự án so sánh'), findsOneWidget);
      expect(http.seen.single.path, '/public/projects');
      for (final name in [
        'Dự án An',
        'Dự án Bình',
        'Dự án Cầu',
        'Dự án Đông',
      ]) {
        expect(find.bySemanticsLabel('Chọn $name'), findsOneWidget);
      }
      await press(t, find.bySemanticsLabel('Chọn Dự án Bình'));
      expect(container.read(projectCompareProvider), ['A', 'B']);
      await press(t, find.text('So sánh (2)'));
      expect(router.state.uri.path, '/so-sanh-du-an');
    },
  );
  testWidgets('fourth compare reports maximum without changing codes', (
    t,
  ) async {
    await show(t, const CompareChip(code: 'A', name: 'Dự án An'));
    for (final code in ['B', 'C', 'D']) {
      container.read(projectCompareProvider.notifier).add(code);
    }
    await press(t, find.bySemanticsLabel('So sánh Dự án An'));
    expect(container.read(projectCompareProvider), ['B', 'C', 'D']);
    expect(find.text('Tối đa 3 dự án'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2500));
  });
  testWidgets(
    'project picker keeps search when reopened and selected projects stay first',
    (t) async {
      await show(t, const CompareChip(code: 'A', name: 'Dự án An'));
      await t.longPress(find.bySemanticsLabel('So sánh Dự án An'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Bình');
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Chọn Dự án An'), findsOneWidget);
      expect(find.bySemanticsLabel('Chọn Dự án Bình'), findsOneWidget);
      expect(find.bySemanticsLabel('Chọn Dự án Cầu'), findsNothing);
      await press(t, find.bySemanticsLabel('Đóng').last);
      await t.longPress(find.bySemanticsLabel('So sánh Dự án An'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Bình',
      );
      expect(find.bySemanticsLabel('Chọn Dự án Cầu'), findsNothing);
    },
  );
  testWidgets('comparison shows API facts and missing data', (t) async {
    await show(t, const ProjectCompareScreen());
    container.read(projectCompareProvider.notifier)
      ..add('A')
      ..add('B');
    await t.pumpAndSettle();
    for (final value in [
      'Dự án An',
      'Dự án Bình',
      'Quý 4/2027',
      '2 tiện ích',
      '12 cập nhật căn',
      'Có tour công khai',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(find.text('Chưa cập nhật'), findsWidgets);
    expect(find.byIcon(Ionicons.add), findsOneWidget);
    container.read(projectCompareProvider.notifier).add('C');
    await t.pumpAndSettle();
    expect(find.byIcon(Ionicons.add), findsNothing);
    expect(find.text('Đổi dự án'), findsOneWidget);
  });
  testWidgets('comparison removes a project', (t) async {
    await show(t, const ProjectCompareScreen());
    container.read(projectCompareProvider.notifier)
      ..add('A')
      ..add('B');
    await t.pumpAndSettle();
    await press(t, find.bySemanticsLabel('Bỏ Dự án Bình khỏi so sánh'));
    expect(container.read(projectCompareProvider), ['A']);
  });
  testWidgets('comparison below two guides selection', (t) async {
    await show(t, const ProjectCompareScreen());
    expect(find.textContaining('Chọn ít nhất 2 dự án'), findsOneWidget);
    expect(find.byIcon(Ionicons.gitCompareOutline), findsOneWidget);
  });
  testWidgets('unit picker adds same-project unit and opens compare', (
    t,
  ) async {
    await show(
      t,
      UnitComparePicker(projectId: 'P', visible: true, onClose: () {}),
    );
    expect(find.text('Đã chọn 1/4 căn'), findsOneWidget);
    await press(t, find.bySemanticsLabel(RegExp('^Chọn căn A-02,')));
    expect(find.text('Đã chọn 2/4 căn'), findsOneWidget);
    await press(t, find.text('So sánh (2)'));
    expect(router.state.uri.path, '/so-sanh');
  });
  testWidgets('unit picker removes selected unit', (t) async {
    await show(
      t,
      UnitComparePicker(projectId: 'P', visible: true, onClose: () {}),
    );
    await press(t, find.bySemanticsLabel(RegExp('^Chọn căn A-01,')));
    expect(find.text('Đã chọn 0/4 căn'), findsOneWidget);
  });
  testWidgets(
    'unit picker displays backend full error without retrying write',
    (t) async {
      await show(
        t,
        UnitComparePicker(projectId: 'P', visible: true, onClose: () {}),
      );
      expect(find.text('Đã chọn 1/4 căn'), findsOneWidget);
      await press(t, find.bySemanticsLabel(RegExp('^Chọn căn B-01,')));
      expect(find.text('Rổ so sánh đã đủ 4 căn.'), findsOneWidget);
      expect(find.text('Đã chọn 1/4 căn'), findsOneWidget);
      expect(picked, ['u1']);
      expect(
        t
            .widget<Semantics>(find.bySemanticsLabel(RegExp('^Chọn căn A-01,')))
            .properties
            .checked,
        true,
      );
      expect(
        t
            .widget<Semantics>(find.bySemanticsLabel(RegExp('^Chọn căn B-01,')))
            .properties
            .checked,
        false,
      );
      expect(http.seen.where((o) => o.method == 'POST').length, 1);
    },
  );
  testWidgets('kit button long press respects disabled and loading', (t) async {
    var holds = 0;
    var taps = 0;
    var disabled = false, loading = false;
    late StateSetter update;
    await show(
      t,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return kit.Button(
            title: 'Hold',
            onPress: () => taps++,
            onLongPress: () => holds++,
            disabled: disabled,
            loading: loading,
          );
        },
      ),
    );
    final gesture = await t.startGesture(t.getCenter(find.text('Hold')));
    await t.pump(const Duration(milliseconds: 349));
    expect(holds, 0);
    await t.pump(const Duration(milliseconds: 1));
    expect(holds, 1);
    await gesture.up();
    expect(taps, 0);
    update(() => disabled = true);
    await t.pump();
    await t.longPress(find.text('Hold'));
    expect(holds, 1);
    update(() {
      disabled = false;
      loading = true;
    });
    await t.pump();
    await t.longPress(find.byType(kit.Button));
    expect(holds, 1);
  });
  testWidgets(
    'floating dock requires two, opens picker and can clear selection',
    (t) async {
      await show(t, const Stack(children: [CompareDock(bottom: 12)]));
      expect(find.text('So sánh'), findsNothing);
      container.read(projectCompareProvider.notifier).add('A');
      await t.pumpAndSettle();
      expect(find.text('So sánh 1/3 dự án'), findsOneWidget);
      expect(t.widget<kit.Button>(find.byType(kit.Button)).disabled, true);
      await press(t, find.bySemanticsLabel('Chọn thêm dự án so sánh'));
      await press(t, find.bySemanticsLabel('Chọn Dự án Bình'));
      expect(container.read(projectCompareProvider), ['A', 'B']);
      await press(t, find.bySemanticsLabel('Đóng').last);
      await press(t, find.byTooltip('Bỏ hết dự án đang so sánh'));
      expect(container.read(projectCompareProvider), isEmpty);
    },
  );
}
