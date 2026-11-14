import 'dart:ui' show CheckedState;

import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/api/unit_compare.dart';
import 'package:smartduan/screens/public/developer.dart';
import 'package:smartduan/screens/public/project_compare.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/loan_result_cards.dart';
import 'package:smartduan/ui/network_image.dart';
import 'package:smartduan/ui/post_body.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/project_compare_kit.dart';
import 'package:smartduan/ui/project_browser.dart';
import 'package:smartduan/ui/project_filter.dart';
import 'package:smartduan/ui/unit_compare_picker.dart';

import '../api/models_test.dart' show loanJson;
import '../screens/public/detail_screens_test.dart' show DetailSession;

import 'package:smartduan/auth/session.dart';

PublicProject project(int i) =>
    PublicProject(id: '$i', code: 'P$i', name: 'Dự án $i', status: 'selling');

Future<void> mount(
  WidgetTester tester,
  Widget child,
  ProviderContainer container, {
  double width = 320,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '6 article image preserves its extent and opens a zoomable viewer',
    (tester) async {
      await mount(
        tester,
        const SingleChildScrollView(
          child: PostBody(
            html: '<img src="https://example.vn/a.png" alt="Mặt bằng">',
          ),
        ),
        ProviderContainer.test(),
      );
      expect(
        tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).fit,
        BoxFit.contain,
      );
      expect(
        find.ancestor(
          of: find.byType(AppNetworkImage),
          matching: find.byType(AspectRatio),
        ),
        findsNothing,
      );
      await tester.tap(find.byType(AppNetworkImage));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.byTooltip('Đóng'), findsOneWidget);
    },
  );

  testWidgets(
    '43 repayment schedule is disclosed on request, with amounts intact',
    (tester) async {
      final result = LoanResult.fromJson(loanJson);
      await mount(
        tester,
        SingleChildScrollView(child: LoanResultCards(r: result)),
        ProviderContainer.test(),
      );
      expect(find.text('Kỳ 1'), findsNothing);
      await tester.ensureVisible(find.text('Xem lịch trả 12 kỳ đầu'));
      await tester.pump();
      await tester.tap(find.text('Xem lịch trả 12 kỳ đầu'));
      await tester.pumpAndSettle();
      expect(find.text('Kỳ 1'), findsOneWidget);
      expect(find.text('10.000.000 đ (gốc 5.000.000 đ)'), findsOneWidget);
    },
  );

  testWidgets('46 loan rates use Vietnamese decimal separators', (
    tester,
  ) async {
    await mount(
      tester,
      SingleChildScrollView(
        child: LoanResultCards(r: LoanResult.fromJson(loanJson)),
      ),
      ProviderContainer.test(),
    );
    expect(find.textContaining(',00%'), findsNWidgets(2));
  });

  testWidgets('2 failed comparison can retry without losing selection', (
    tester,
  ) async {
    var calls = 0;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        fetchPublicProjectProvider('P0').overrideWith((_) async {
          if (++calls == 1) throw Exception('offline');
          return project(0);
        }),
        fetchPublicProjectProvider('P1').overrideWith((_) async => project(1)),
      ],
    );
    container.read(projectCompareProvider.notifier)
      ..add('P0')
      ..add('P1');
    await mount(tester, const ProjectCompareScreen(), container);
    await tester.tap(find.text('Thử lại dự án lỗi'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(container.read(projectCompareProvider), ['P0', 'P1']);
    expect(find.text('Dự án 0'), findsOneWidget);
  });

  testWidgets(
    '13 comparison columns remain readable with pinned headings and labels',
    (tester) async {
      final container = ProviderContainer.test(
        overrides: [
          for (var i = 0; i < 3; i++)
            fetchPublicProjectProvider('P$i')
                .overrideWith((_) async => project(i)),
        ],
      );
      for (var i = 0; i < 3; i++) {
        container.read(projectCompareProvider.notifier).add('P$i');
      }
      await mount(tester, const ProjectCompareScreen(), container, scale: 1.6);
      final columns = find.byKey(const ValueKey('compare-P0'));
      expect(tester.getSize(columns).width, greaterThanOrEqualTo(180));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('20 comparison controls provide 48dp targets', (tester) async {
    await mount(
      tester,
      const CompareChip(code: 'P0', name: 'Dự án 0'),
      ProviderContainer.test(),
    );
    final target = find
        .ancestor(
          of: find.text('So sánh'),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
  });

  testWidgets('12 comparison footer counter keeps full width with large text', (
    tester,
  ) async {
    await mount(
      tester,
      ComparePicker(visible: true, onClose: () {}),
      ProviderContainer.test(
        overrides: [
          listAllPublicProjectsProvider.overrideWith((_) async => []),
        ],
      ),
      scale: 2,
    );
    final count = tester.getRect(find.text('Đã chọn 0/3'));
    final clear = tester.getRect(find.text('Xoá'));
    expect(count.width, greaterThan(200));
    expect(clear.top, greaterThan(count.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('40 project picker reveals additional loaded results', (
    tester,
  ) async {
    await mount(
      tester,
      ComparePicker(visible: true, onClose: () {}),
      ProviderContainer.test(
        overrides: [
          listAllPublicProjectsProvider.overrideWith(
            (_) async => List.generate(31, project),
          ),
        ],
      ),
    );
    expect(find.text('Hiển thị 30/31 dự án'), findsOneWidget);
    expect(find.text('Dự án 30'), findsNothing);
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Hiển thị 31/31 dự án'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dự án 30'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Dự án 30'), findsOneWidget);
  });

  testWidgets('21 unit picker announces visible price type and status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await mount(
      tester,
      UnitComparePicker(projectId: 'p', visible: true, onClose: () {}),
      ProviderContainer.test(
        overrides: [
          unitCompareProvider.overrideWith((_) async => []),
          compareUnitsProvider('p').overrideWith(
            (_) async => [
              const ComparePickerUnit(
                id: 'u',
                code: 'A1',
                status: 'available',
                unitType: 'Căn hộ',
                priceMin: '2000000000',
              ),
            ],
          ),
        ],
      ),
    );
    expect(
      find.bySemanticsLabel('Chọn căn A1, Căn hộ, Còn hàng, 2 tỷ'),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel('Chọn căn A1, Căn hộ, Còn hàng, 2 tỷ'),
          )
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isFalse,
    );
    handle.dispose();
  });

  testWidgets('40 unit picker reveals remaining loaded units', (tester) async {
    await mount(
      tester,
      UnitComparePicker(projectId: 'p', visible: true, onClose: () {}),
      ProviderContainer.test(
        overrides: [
          unitCompareProvider.overrideWith((_) async => []),
          compareUnitsProvider('p').overrideWith(
            (_) async => List.generate(
              41,
              (i) =>
                  ComparePickerUnit(id: '$i', code: 'U$i', status: 'available'),
            ),
          ),
        ],
      ),
    );
    expect(find.text('Hiển thị 40/41 căn'), findsOneWidget);
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('U40'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('U40'), findsOneWidget);
  });

  testWidgets(
    '7 developer projects load the next page and label search scope',
    (tester) async {
      final container = ProviderContainer.test(
        overrides: [
          fetchPublicDeveloperProvider('dev').overrideWith(
            (_) async => PublicDeveloper(
              id: 'd',
              slug: 'dev',
              name: 'Chủ đầu tư',
              badges: [],
            ),
          ),
          listPublicProjectsProvider(
            const PublicFilters(developerId: 'd', perPage: 50),
          ).overrideWith(
            (_) async => Paged(
              data: List.generate(5, project),
              page: 1,
              perPage: 5,
              total: 6,
            ),
          ),
          listPublicProjectsProvider(
            const PublicFilters(developerId: 'd', perPage: 50, page: 2),
          ).overrideWith(
            (_) async =>
                Paged(data: [project(5)], page: 2, perPage: 5, total: 6),
          ),
        ],
      );
      await mount(tester, const DeveloperScreen(slug: 'dev'), container);
      expect(find.text('Hiển thị 5/6 dự án'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is kit.SearchBar &&
              w.placeholder == 'Tìm trong 5 dự án đã tải…',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Tải thêm'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Tải thêm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tải thêm'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Dự án 5'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Dự án 5'));
      await tester.pumpAndSettle();
      expect(find.text('Dự án 5'), findsOneWidget);
      // RN: once everything is loaded only the total eyebrow remains.
      await tester.scrollUntilVisible(
        find.text('6 dự án'),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('6 dự án'), findsOneWidget);
      expect(find.textContaining('Hiển thị'), findsNothing);
    },
  );

  testWidgets('27 developer badge is an RN chip', (tester) async {
    await mount(
      tester,
      const DeveloperScreen(slug: 'dev'),
      ProviderContainer.test(
        overrides: [
          fetchPublicDeveloperProvider('dev').overrideWith(
            (_) async => PublicDeveloper(
              id: 'd',
              slug: 'dev',
              name: 'Chủ đầu tư',
              badges: ['Uy tín'],
            ),
          ),
          listPublicProjectsProvider(
            const PublicFilters(developerId: 'd', perPage: 50),
          ).overrideWith(
            (_) async => Paged(data: [], page: 1, perPage: 50, total: 0),
          ),
        ],
      ),
    );
    expect(find.text('Uy tín'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Uy tín'), matching: find.byType(kit.Chip)),
      findsOneWidget,
    );
    // Informational chip: full opacity, not a dimmed disabled button.
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text('Uy tín'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
  });

  Future<void> mountDetail(
    WidgetTester tester,
    PublicProject p, {
    double width = 320,
    double scale = 1,
  }) => mount(
    tester,
    const ProjectDetailScreen(code: 'P'),
    ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => DetailSession(SessionStatus.guest)),
        fetchPublicProjectProvider('P').overrideWith((_) async => p),
      ],
    ),
    width: width,
    scale: scale,
  );

  testWidgets('15 developer action stays beside the name at large text', (
    tester,
  ) async {
    await mountDetail(
      tester,
      PublicProject(
        id: 'p',
        code: 'P',
        name: 'Dự án',
        status: 'selling',
        developer: const ProjectDeveloper(
          id: 'd',
          name: 'Chủ đầu tư có tên dài',
        ),
      ),
      scale: 1.8,
    );
    expect(
      tester.getRect(find.text('Dự án khác')).left,
      greaterThanOrEqualTo(
        tester.getRect(find.text('Chủ đầu tư có tên dài')).right,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('38 long text and amenities preview retain expansion access', (
    tester,
  ) async {
    final text = List.filled(100, 'Thông tin dự án.').join(' ');
    await mountDetail(
      tester,
      PublicProject(
        id: 'p',
        code: 'P',
        name: 'Dự án',
        status: 'selling',
        overviewJson: {
          'summary': text,
          'amenities': List.generate(6, (i) => 'Tiện ích $i'),
        },
      ),
    );
    expect(tester.widget<Text>(find.text(text)).maxLines, 6);
    expect(find.text('Tiện ích 5'), findsNothing);
    await tester.ensureVisible(find.text('Xem thêm (1)'));
    await tester.pump();
    await tester.tap(find.text('Xem thêm (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Tiện ích 5'), findsOneWidget);
    await tester.ensureVisible(find.text('Xem thêm'));
    await tester.pump();
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(text)).maxLines, isNull);
  });

  testWidgets(
    '42 large developer group collapses and searches with selection visible',
    (tester) async {
      final projects = List.generate(
        8,
        (i) => PublicProject(
          id: '$i',
          code: 'P$i',
          name: 'Dự án $i',
          status: 'selling',
          developer: ProjectDeveloper(id: 'd$i', name: 'Chủ đầu tư $i'),
        ),
      );
      await mount(
        tester,
        ProjectBrowser(
          projects: projects,
          loading: false,
          onRetry: () {},
          onRefresh: () {},
          onOpen: (_) {},
          emptyText: 'Trống',
          initial: const ProjectFilter(developer: 'Chủ đầu tư 7'),
        ),
        ProviderContainer.test(),
      );
      await tester.tap(find.bySemanticsLabel(RegExp('^Bộ lọc')));
      await tester.pumpAndSettle();
      expect(find.text('Chủ đầu tư 7 · 1'), findsOneWidget);
      expect(find.text('Chủ đầu tư 6 · 1'), findsNothing);
      // Selected developer plus five options are visible: two remain hidden.
      await tester.ensureVisible(find.text('Xem thêm chủ đầu tư (2)'));
      await tester.pump();
      await tester.tap(find.text('Xem thêm chủ đầu tư (2)'));
      await tester.pumpAndSettle();
      final search = find.byWidgetPredicate(
        (w) => w is kit.SearchBar && w.placeholder == 'Tìm chủ đầu tư…',
      );
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'Chủ đầu tư 6',
      );
      await tester.pumpAndSettle();
      expect(find.text('Chủ đầu tư 6 · 1'), findsOneWidget);
      expect(find.text('Chủ đầu tư 7 · 1'), findsOneWidget);
      expect(find.text('Chủ đầu tư 0 · 1'), findsNothing);
    },
  );

  testWidgets('44 narrow specifications keep the RN two-column grid', (
    tester,
  ) async {
    await mountDetail(
      tester,
      PublicProject(
        id: 'p',
        code: 'P',
        name: 'Dự án',
        status: 'selling',
        overviewJson: {'scale': '100 ha', 'legal': 'Giấy chứng nhận'},
      ),
      scale: 1.5,
    );
    final scale = tester.getRect(find.text('100 ha'));
    final legal = tester.getRect(find.text('Giấy chứng nhận'));
    expect(legal.left, greaterThan(scale.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '38 subdivision progress and document lists preview five records each',
    (tester) async {
      await mountDetail(
        tester,
        PublicProject(
          id: 'p',
          code: 'P',
          name: 'Dự án',
          status: 'selling',
          subdivisions: List.generate(
            6,
            (i) => PublicSubdivision(name: 'Phân khu $i'),
          ),
          progress: List.generate(
            6,
            (i) => PublicProgress(title: 'Tiến độ $i'),
          ),
          documents: List.generate(
            6,
            (i) => PublicDocument(
              name: 'Tài liệu $i',
              url: 'https://example.vn/$i.pdf',
            ),
          ),
        ),
      );
      for (final name in ['Phân khu', 'Tiến độ', 'Tài liệu']) {
        expect(find.text('$name 4'), findsOneWidget);
        expect(find.text('$name 5'), findsNothing);
      }
      for (var i = 0; i < 3; i++) {
        final action = find.text('Xem thêm (1)').first;
        await tester.ensureVisible(action);
        await tester.pump();
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      for (final name in ['Phân khu', 'Tiến độ', 'Tài liệu']) {
        expect(find.text('$name 5'), findsOneWidget);
      }
    },
  );

  testWidgets('20 comparison removal has a 48dp hit area', (tester) async {
    final container = ProviderContainer.test(
      overrides: [
        for (var i = 0; i < 2; i++)
          fetchPublicProjectProvider('P$i')
              .overrideWith((_) async => project(i)),
      ],
    );
    container.read(projectCompareProvider.notifier)
      ..add('P0')
      ..add('P1');
    await mount(tester, const ProjectCompareScreen(), container);
    final action = find
        .ancestor(of: find.text('Bỏ').first, matching: find.byType(kit.Button))
        .first;
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
  });
}
