import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/main.dart';
import 'package:smartduan/ui/bottom_bar.dart';
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/otp_step.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_filter.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/ui/theme.dart' as c;

import '../router_test.dart' show FakeSession;
import '../screens/auth/auth_fakes.dart' show TestSession;
import '../support/responsive.dart';
import 'board_filter_test.dart' show boardPlan;
import 'project_browser_test.dart' show pumpBrowser;

Future<void> mount(WidgetTester tester, Widget child, {bool reduce = false}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(TestSession.new)],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(disableAnimations: reduce),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );

void main() {
  for (final selected in [false, true]) {
    testWidgets('31 show more counts hidden options, selected $selected', (
      tester,
    ) async {
      await pumpBrowser(
        tester,
        projects: [
          for (var i = 0; i < 7; i++)
            PublicProject(
              id: '$i',
              code: '$i',
              name: 'Dự án $i',
              status: 'selling',
              developer: ProjectDeveloper(id: '$i', name: 'Công ty $i'),
            ),
        ],
        initial: selected
            ? const ProjectFilter(developer: 'Công ty 6')
            : emptyProjectFilter,
      );
      await tester.tap(
        find.bySemanticsLabel(selected ? 'Bộ lọc, đang bật 1' : 'Bộ lọc'),
      );
      await tester.pumpAndSettle();
      final more = find.text('Xem thêm chủ đầu tư (${selected ? 1 : 2})');
      expect(more, findsOneWidget);
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('Công ty 6 · 1'), findsOneWidget);
    });
  }
  testWidgets('2 parent owns the only inventory view selector', (tester) async {
    await mount(
      tester,
      StackGrid(plan: boardPlan, viewMode: 'list', onOpen: (_) {}),
    );
    expect(find.byType(kit.Segmented<String>), findsNothing);
    expect(find.byType(kit.ListItem), findsNWidgets(3));
    await mount(
      tester,
      StackGrid(plan: boardPlan, viewMode: 'grid', onOpen: (_) {}),
    );
    expect(find.byType(kit.ListItem), findsNothing);
    expect(find.text('T2'), findsOneWidget);
  });

  testWidgets('7 promo is flat brand deep with a gold accent', (tester) async {
    await mount(tester, const kit.Hero(child: Text('Đăng nhập')));
    final box = tester
        .widgetList<Container>(find.byType(Container))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .singleWhere((d) => d.color == c.brandDeep);
    expect(box.gradient, isNull);
    expect(box.border, Border.all(color: c.gold));
  });

  testWidgets('8 filter headings retain sentence case at 15/600', (
    tester,
  ) async {
    await mount(
      tester,
      const kit.FilterGroup(title: 'Trạng thái', children: []),
    );
    final text = tester.widget<Text>(find.text('Trạng thái'));
    expect(text.style!.fontSize, 15);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.letterSpacing, isNull);
  });

  testWidgets(
    '9 section action takes its natural width and stacks when needed',
    (tester) async {
      Widget section(double width) => SizedBox(
        width: width,
        child: kit.Section(
          title: 'Dự án nổi bật',
          action: (label: 'Xem tất cả', onPress: () {}),
          child: const SizedBox(),
        ),
      );
      await mount(tester, section(600));
      expect(tester.getSize(find.byType(kit.Pressable)).width, lessThan(200));
      expect(
        tester.getTopLeft(find.text('Xem tất cả')).dy,
        lessThan(tester.getBottomLeft(find.text('Dự án nổi bật')).dy),
      );
      await mount(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: section(220),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Xem tất cả')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Dự án nổi bật')).dy,
        ),
      );
    },
  );

  testWidgets(
    '10 row status is coloured text while cover status stays backed',
    (tester) async {
      const p = ProjectCardData(name: 'Dự án', status: 'selling');
      await mount(tester, ProjectRow(p: p, onPress: () {}));
      expect(find.byType(kit.Pill), findsNothing);
      final status = tester.widget<Text>(
        find.text(projectStatus['selling']!.label),
      );
      expect(status.style!.color, isNotNull);
      await mount(tester, const ProjectMedia(name: 'Dự án', status: 'selling'));
      expect(find.byType(kit.Pill), findsOneWidget);
    },
  );

  testWidgets('12 list boundaries and chevrons preserve unit navigation', (
    tester,
  ) async {
    String? opened;
    await mount(
      tester,
      StackGrid(plan: boardPlan, viewMode: 'list', onOpen: (id) => opened = id),
    );
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.byIcon(Ionicons.chevronForward), findsNWidgets(3));
    await tester.tap(find.text('A-01.01'));
    expect(opened, 'A-01.01');
  });

  testWidgets('16 OTP uses the screen gutter without an inset card', (
    tester,
  ) async {
    await mount(
      tester,
      SizedBox(
        height: 550,
        child: OtpStep(
          email: 'a@b.vn',
          password: 'password',
          notice: 'Mã đã gửi',
          onBack: () {},
        ),
      ),
    );
    expect(find.byType(kit.Card), findsNothing);
    expect(
      tester.getTopLeft(find.byType(kit.Field)).dx,
      tester.getTopLeft(find.byType(kit.Notice)).dx,
    );
  });

  testWidgets('19 native inventory activity says bảng hàng', (tester) async {
    await mount(
      tester,
      ProjectCard(
        p: const ProjectCardData(
          name: 'Dự án',
          status: 'selling',
          inventoryUpdatedAt: '2026-11-13T00:00:00Z',
        ),
        onPress: () {},
      ),
    );
    expect(find.textContaining('Bảng hàng cập nhật'), findsOneWidget);
    expect(find.textContaining('Rổ hàng cập nhật'), findsNothing);
  });

  testWidgets('20 inventory list uses Vietnamese area formatting', (
    tester,
  ) async {
    final plan = StackPlan.fromJson({
      'block': {'id': 'b'},
      'layout': 'floors',
      'axes': ['01'],
      'floors': [
        {
          'floor': 1,
          'cells': [
            {
              'id': 'u',
              'code': 'A1',
              'axis': '01',
              'status': 'available',
              'area_net': '72.50',
            },
          ],
        },
      ],
    });
    await mount(
      tester,
      StackGrid(plan: plan, viewMode: 'list', onOpen: (_) {}),
    );
    expect(find.textContaining('72,5 m²'), findsOneWidget);
  });

  testWidgets('21 missing prices omit giá từ', (tester) async {
    for (final price in [null, '', '0', '-1', 'invalid']) {
      await mount(
        tester,
        ProjectCard(
          p: ProjectCardData(
            name: 'Dự án',
            status: 'selling',
            priceFrom: price,
          ),
          onPress: () {},
        ),
      );
      expect(find.text('Liên hệ'), findsOneWidget);
      expect(find.text('Giá từ'), findsNothing);
    }
  });

  testWidgets('22 app supplies Vietnamese SDK calendar strings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(
            () => FakeSession(SessionStatus.loading),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(BrandSplash));
    expect(Localizations.localeOf(context), const Locale('vi'));
    final labels = MaterialLocalizations.of(context);
    expect(labels.cancelButtonLabel, 'Huỷ');
    final result = showDatePicker(
      context: context,
      initialDate: DateTime(2026, 11, 13),
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(labels.datePickerHelpText), findsOneWidget);
    expect(
      find.text(labels.formatMonthYear(DateTime(2026, 11))),
      findsOneWidget,
    );
    await tester.tap(find.text(labels.cancelButtonLabel));
    await tester.pump(const Duration(milliseconds: 400));
    expect(await result, isNull);
  });

  testWidgets(
    '23 reduced motion loading, refresh, buttons and FAQ are static',
    (tester) async {
      final pending = Completer<int>();
      var refreshing = false;
      final provider = FutureProvider<int>(
        (_) => refreshing ? pending.future : Future.value(1),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      refreshing = true;
      container.invalidate(provider);
      await mount(
        tester,
        Column(
          children: [
            const kit.Loading(),
            kit.Button(title: 'Lưu', onPress: () {}, loading: true),
            kit.AsyncView<int>(
              value: container.read(provider),
              builder: (_) => const Text('Đã tải'),
            ),
            const kit.FaqItem(question: 'Câu hỏi', answer: 'Trả lời'),
          ],
        ),
        reduce: true,
      );
      expect(find.text('Đang tải…'), findsOneWidget);
      expect(find.text('Đang xử lý…'), findsOneWidget);
      expect(find.text('Đang cập nhật…'), findsOneWidget);
      expect(find.text('Đã tải'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile))
            .expansionAnimationStyle,
        AnimationStyle.noAnimation,
      );
      await tester.tap(find.text('Câu hỏi'));
      await tester.pump();
      expect(find.text('Trả lời').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('25 skeleton and project card use 16dp radii', (tester) async {
    await mount(tester, const kit.Skeleton(height: 60));
    final box =
        tester.widget<Container>(find.byType(Container)).decoration
            as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(16));
    await mount(
      tester,
      ProjectCard(
        p: const ProjectCardData(name: 'Dự án', status: 'selling'),
        onPress: () {},
      ),
    );
    expect(
      tester.widget<ClipRRect>(find.byType(ClipRRect).first).borderRadius,
      BorderRadius.circular(16),
    );
  });

  test('29 shared bottom bar uses a divider and a 62dp row', () {
    final style = tabBarStyle(20);
    expect(style.decoration.boxShadow, isNull);
    expect(
      style.decoration.border,
      const Border(top: BorderSide(color: c.line)),
    );
    expect(style.height, 82);
    expect(style.padding, EdgeInsets.zero);
  });

  testWidgets('shared sections retain the complete responsive matrix', (
    tester,
  ) async {
    await expectResponsive(tester, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: kit.Screen(
              children: [
                kit.Section(
                  title: 'Dự án nổi bật trong tháng',
                  action: (label: 'Xem tất cả dự án', onPress: () {}),
                  children: const [
                    kit.FilterGroup(title: 'Trạng thái', children: []),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    });
  });
}
