import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/api/unit_compare.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/ui/bottom_bar.dart';
import 'package:smartduan/ui/captcha.dart';
import 'package:smartduan/ui/loan_result_cards.dart';
import 'package:smartduan/ui/map_embed.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:smartduan/ui/developer_chip.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/otp_step.dart';
import 'package:smartduan/ui/post_body.dart';
import 'package:smartduan/ui/project_browser.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_compare_kit.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/ui/unit_compare_picker.dart';

import '../screens/auth/auth_fakes.dart' show TestSession;
import '../support/responsive.dart';
import 'board_filter_test.dart' show boardPlan;
import 'detail_webview_fake.dart';

const longName = 'Khu đô thị ven sông phía Đông Thành phố Hồ Chí Minh';
final project = PublicProject(
  id: 'p',
  code: 'P',
  name: longName,
  status: 'selling',
  province: 'Thành phố Hồ Chí Minh',
  priceFrom: '123456789000',
);

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  bool scroll = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(TestSession.new)],
      child: MaterialApp(
        home: Scaffold(
          body: SafeArea(child: scroll ? kit.Screen(children: [child]) : child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  for (final state
      in tester.stateList<ScrollableState>(find.byType(Scrollable)).toList()) {
    if (state.position.hasContentDimensions &&
        state.widget.axisDirection == AxisDirection.down) {
      state.position.jumpTo(state.position.maxScrollExtent);
    }
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => WebViewPlatform.instance = DetailWebViewPlatform());
  final surfaces = <String, Widget Function()>{
    'controls and long labels': () => Column(
      children: [
        kit.Button(title: longName, onPress: () {}),
        kit.ButtonGroup(
          children: [
            kit.Button(title: 'Xem bảng hàng', onPress: () {}),
            kit.Button(title: 'Chia sẻ cho khách', onPress: () {}),
          ],
        ),
        kit.Field(
          label: longName,
          value: '',
          onChangeText: (_) {},
          error: longName,
        ),
        kit.SearchBar(
          value: '',
          onChangeText: (_) {},
          onFilter: () {},
          filterCount: 12,
        ),
        kit.Chip(label: longName, onPress: () {}),
      ],
    ),
    'surfaces and actions': () => kit.Section(
      title: longName,
      action: (label: 'Xem tất cả dự án', onPress: () {}),
      children: [
        kit.ListItem(title: longName, subtitle: longName, onPress: () {}),
        kit.TileGrid(
          children: List.generate(
            5,
            (_) => kit.Tile(icon: Icons.home, label: longName, onPress: () {}),
          ),
        ),
        const kit.Hero(children: [kit.H2(longName)]),
      ],
    ),
    'empty error loading': () => Column(
      children: [
        kit.Empty(
          text: 'Chưa có căn phù hợp. Thử thay đổi bộ lọc.',
          action: (label: 'Thay đổi bộ lọc', onPress: () {}),
        ),
        kit.ErrorBox(error: StateError('offline'), onRetry: () {}),
        const kit.Loading(),
        const ProjectCardSkeleton(),
      ],
    ),
    'project card': () => ProjectCard(p: project, onPress: () {}),
    'developer': () =>
        DeveloperChip(name: longName, logo: null, onPress: () {}),
    'article': () => const PostBody(
      html:
          '<h2>$longName</h2><p>$longName</p><table><tr><td>$longName</td><td>123.456.789.000 đồng</td></tr></table>',
    ),
    'quick find': () => ProjectQuickFind(
      q: 'đô thị',
      projects: [project],
      onOpen: (_) {},
      onAll: () {},
    ),
    'grid': () => StackGrid(plan: boardPlan, onOpen: (_) {}),
    'empty grid': () => StackGrid(
      plan: const StackPlan(block: BlockRef(id: 'b')),
      onOpen: (_) {},
    ),
    'loan results': () => LoanResultCards(
      r: LoanResult.fromJson({
        'price': 123456789000,
        'monthly_payment': 123456789,
        'loan_amount': 98765432100,
        'loan_ratio': .7,
        'schedule': List.generate(
          12,
          (i) => {'period': i + 1, 'total': 123456789},
        ),
      }),
    ),
    'map': () => const MapEmbed(lat: 10.7, lng: 106.7, name: longName),
    'captcha': () => Captcha(action: 'register', onToken: (_) {}),
  };
  for (final entry in surfaces.entries) {
    testWidgets(
      'matrix ${entry.key}',
      (tester) => expectResponsive(tester, () => mount(tester, entry.value())),
    );
  }
  testWidgets(
    'matrix sliver board list mode',
    (tester) => expectResponsive(tester, () async {
      await mount(
        tester,
        kit.Screen(
          slivers: [StackGrid(plan: boardPlan, onOpen: (_) {}, sliver: true)],
          children: const [],
        ),
        scroll: false,
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(0);
      await tester.pump();
      await tester.tap(find.text('Danh sách'));
      await tester.pump();
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
    }),
  );
  testWidgets(
    'matrix splash',
    (tester) => expectResponsive(
      tester,
      () => mount(tester, const BrandSplash(), scroll: false),
    ),
  );
  testWidgets(
    'matrix OTP',
    (tester) => expectResponsive(
      tester,
      () => mount(
        tester,
        OtpStep(
          email: 'nguoidung@example.vn',
          password: '',
          notice: longName,
          onBack: () {},
        ),
        scroll: false,
      ),
    ),
  );
  testWidgets(
    'matrix guest bar',
    (tester) => expectResponsive(
      tester,
      () => mount(
        tester,
        GuestBar(
          items: [
            for (final label in [
              'Trang chủ',
              'Khám phá',
              'Thông báo',
              'Tài khoản',
            ])
              BarItem(
                key: label,
                label: label,
                icon: Icons.home,
                iconOn: Icons.home,
                onPress: () {},
              ),
          ],
        ),
      ),
    ),
  );
  testWidgets(
    'matrix compare dock',
    (tester) => expectResponsive(tester, () async {
      final container = ProviderContainer();
      container.read(projectCompareProvider.notifier).add('P');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CompareDock())),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }),
  );
  for (final state in ['data', 'empty', 'loading', 'error', 'filter']) {
    testWidgets(
      'matrix project browser $state',
      (tester) => expectResponsive(tester, () async {
        await mount(
          tester,
          ProjectBrowser(
            projects: state == 'empty' ? [] : [project],
            loading: state == 'loading',
            error: state == 'error' ? StateError('offline') : null,
            onRetry: () {},
            onRefresh: () async {},
            onOpen: (_) {},
            emptyText: 'Chưa có dự án.',
          ),
          scroll: false,
        );
        if (state == 'filter') {
          await tester.tap(find.bySemanticsLabel('Bộ lọc'));
          await tester.pumpAndSettle();
        }
      }),
    );
  }
  for (final state in ['data', 'empty', 'loading', 'error']) {
    for (final unit in [false, true]) {
      testWidgets(
        'matrix ${unit ? 'unit' : 'project'} picker $state',
        (tester) => expectResponsive(tester, () async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                listAllPublicProjectsProvider.overrideWith((_) {
                  if (state == 'error') throw StateError('offline');
                  if (state == 'loading') {
                    return Completer<List<PublicProject>>().future;
                  }
                  return state == 'empty'
                      ? <PublicProject>[]
                      : List.generate(
                          60,
                          (i) => PublicProject(
                            id: '$i',
                            code: '$i',
                            name: '$longName $i',
                            status: 'selling',
                          ),
                        );
                }),
                unitCompareProvider.overrideWith((_) async => []),
                compareUnitsProvider('p').overrideWith((_) {
                  if (state == 'error') throw StateError('offline');
                  if (state == 'loading') {
                    return Completer<List<ComparePickerUnit>>().future;
                  }
                  return state == 'empty'
                      ? <ComparePickerUnit>[]
                      : List.generate(
                          60,
                          (i) => ComparePickerUnit.fromJson({
                            'id': '$i',
                            'code': '$longName $i',
                            'status': 'available',
                            'price_min': 123456789000,
                          }),
                        );
                }),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: unit
                      ? UnitComparePicker(
                          projectId: 'p',
                          visible: true,
                          onClose: () {},
                        )
                      : ComparePicker(visible: true, onClose: () {}),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          for (final scrollable in tester.stateList<ScrollableState>(
            find.byType(Scrollable),
          )) {
            if (scrollable.widget.axisDirection == AxisDirection.down) {
              scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            }
          }
          await tester.pump();
        }),
      );
    }
  }
  testWidgets(
    'matrix sheet keeps action visible while body scrolls',
    (tester) => expectResponsive(tester, () async {
      await mount(
        tester,
        kit.Sheet(
          visible: true,
          title: 'Lọc căn',
          onClose: () {},
          footer: kit.Button(title: 'Xem kết quả', onPress: () {}),
          children: List.generate(30, (i) => Text('$longName $i')),
        ),
      );
      expect(find.text('Xem kết quả').hitTestable(), findsOneWidget);
    }),
  );
  testWidgets(
    'matrix sheet keyboard keeps field and action reachable',
    (tester) => expectResponsive(tester, () async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 140);
      await mount(
        tester,
        kit.Sheet(
          visible: true,
          title: 'Lọc căn',
          onClose: () {},
          footer: kit.Button(title: 'Xem kết quả', onPress: () {}),
          children: const [
            kit.Field(label: 'Mã căn'),
            SizedBox(height: 800),
          ],
        ),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        find.byType(TextField).hitTestable(),
        findsOneWidget,
        reason:
            '${tester.view.physicalSize} ${tester.getRect(find.byType(TextField))}',
      );
      expect(find.text('Xem kết quả').hitTestable(), findsOneWidget);
      tester.view.resetViewInsets();
    }),
  );
}
