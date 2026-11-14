import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/ui/kit.dart';
import 'package:smartduan/ui/bottom_bar.dart';
import 'package:smartduan/ui/network_image.dart';
import 'package:smartduan/ui/theme.dart' as c;
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/auth/session.dart';

import '../screens/auth/auth_fakes.dart' show TestSession;

Future<void> mount(WidgetTester t, m.Widget child, {double scale = 1}) async {
  t.view.physicalSize = const m.Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(TestSession.new)],
      child: m.MaterialApp(
        theme: c.lightTheme,
        builder: (context, child) => m.MediaQuery(
          data: m.MediaQuery.of(context).copyWith(
            textScaler: m.TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: m.Scaffold(body: child),
      ),
    ),
  );
  await t.pump();
}

void main() {
  testWidgets('empty subtitles reserve no line and titles are centred', (
    t,
  ) async {
    await mount(
      t,
      const m.Column(
        children: [
          ListItem(key: m.Key('none'), title: 'No subtitle'),
          ListItem(key: m.Key('empty'), title: 'Empty subtitle', subtitle: ''),
          ListItem(
            key: m.Key('full'),
            title: 'With subtitle',
            subtitle: 'Details',
          ),
        ],
      ),
    );
    final none = t.getRect(find.byKey(const m.Key('none')));
    final empty = t.getRect(find.byKey(const m.Key('empty')));
    final full = t.getRect(find.byKey(const m.Key('full')));
    expect(none.height, lessThan(full.height));
    expect(empty.height, none.height);
    expect(t.getCenter(find.text('No subtitle')).dy, none.center.dy);
    expect(t.getCenter(find.text('Empty subtitle')).dy, empty.center.dy);
  });

  testWidgets('sheet covers nested navigator tabs and back closes it first', (
    t,
  ) async {
    final root = m.GlobalKey<m.NavigatorState>();
    final nested = m.GlobalKey<m.NavigatorState>();
    var visible = false;
    var taps = 0;
    await t.pumpWidget(
      m.MaterialApp(
        navigatorKey: root,
        home: m.StatefulBuilder(
          builder: (context, setState) => m.Scaffold(
            bottomNavigationBar: m.TextButton(
              onPressed: () => taps++,
              child: const m.Text('Tabs'),
            ),
            body: m.Navigator(
              key: nested,
              onGenerateRoute: (_) => m.MaterialPageRoute<void>(
                builder: (_) => m.StatefulBuilder(
                  builder: (context, update) => m.Column(
                    children: [
                      m.TextButton(
                        onPressed: () => update(() => visible = true),
                        child: const m.Text('Open'),
                      ),
                      Sheet(
                        visible: visible,
                        onClose: () => update(() => visible = false),
                        title: 'Picker',
                        child: const m.Text('Choices'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final route = m.ModalRoute.of(t.element(find.text('Picker')))!;
    expect(route.navigator, root.currentState);
    expect(nested.currentState!.canPop(), isFalse);
    expect(find.text('Tabs').hitTestable(), findsNothing);
    expect(
      t.getBottomRight(find.byType(m.ModalBarrier).last).dy,
      t.view.physicalSize.height / t.view.devicePixelRatio,
    );
    await root.currentState!.maybePop();
    await t.pumpAndSettle();
    expect(visible, isFalse);
    expect(find.text('Picker'), findsNothing);
    await t.tap(find.text('Tabs'));
    expect(taps, 1);
  });

  test('image widths share bounded physical-pixel buckets', () {
    expect(imageCacheWidth(120, 3), 360);
    expect(imageCacheWidth(121, 3), 720);
    expect(imageCacheWidth(350, 3), 1080);
    expect(imageCacheWidth(390, 3), 1440);
    expect(imageCacheWidth(2000, 3), 1440);
  });
  testWidgets('section action meets the right edge with a 48dp hit area', (
    t,
  ) async {
    await mount(
      t,
      m.Padding(
        padding: const m.EdgeInsets.all(20),
        child: Section(
          eyebrow: 'DỰ ÁN',
          title: 'Nổi bật',
          action: (label: 'Xem tất cả', onPress: () {}),
          child: const m.Text('Body'),
        ),
      ),
    );
    // RN link: label then chevron, flush with the right gutter.
    expect(t.getTopRight(find.byIcon(Ionicons.chevronForward)).dx, 370);
    expect(
      t.getTopLeft(find.byIcon(Ionicons.chevronForward)).dx,
      greaterThan(t.getTopLeft(find.text('Xem tất cả')).dx),
    );
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: find.text('Xem tất cả'),
                  matching: find.byType(m.GestureDetector),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('tiles stretch equally and preserve last-row width at $scale', (
      t,
    ) async {
      await mount(
        t,
        Screen(
          children: [
            TileGrid(
              children: [
                for (final label in [
                  'Dự án',
                  'Quy trình & đào tạo',
                  'Hồ sơ',
                  'Menu',
                ])
                  Tile(icon: Ionicons.home, label: label, onPress: () {}),
              ],
            ),
          ],
        ),
        scale: scale,
      );
      final tiles = find.byType(Tile);
      expect(t.getSize(tiles.at(0)).height, t.getSize(tiles.at(1)).height);
      if (scale <= 1.3) {
        expect(t.getSize(tiles.at(1)).height, t.getSize(tiles.at(2)).height);
      } else {
        expect(t.getSize(tiles.at(2)).height, t.getSize(tiles.at(3)).height);
      }
      expect(t.getSize(tiles.at(3)).width, t.getSize(tiles.at(0)).width);
      expect(t.getTopLeft(tiles.at(1)).dx - t.getTopRight(tiles.at(0)).dx, 10);
      expect(t.takeException(), isNull);
    });
  }
  for (final scale in [1.3, 2.0]) {
    testWidgets('kit and bottom navigation expand at $scale', (t) async {
      await mount(
        t,
        m.Column(
          children: [
            m.Expanded(
              child: Screen(
                children: [
                  Button(title: 'Tất cả tính năng', onPress: () {}),
                  Chip(label: 'Quy trình & đào tạo', onPress: () {}),
                  ChipRail(
                    children: [Chip(label: 'Dự án quan tâm', onPress: () {})],
                  ),
                  Segmented(
                    value: 'all',
                    onChange: (_) {},
                    options: const [
                      (key: 'all', label: 'Tất cả', count: 12),
                      (key: 'active', label: 'Hoạt động', count: 10),
                      (key: 'locked', label: 'Đã khoá', count: 2),
                    ],
                  ),
                  Stat(
                    label: 'Dự án quan tâm',
                    value: '123',
                    icon: Ionicons.home,
                  ),
                  ListItem(
                    title: 'Quy trình & đào tạo',
                    subtitle: 'Đăng nhập gần nhất: 00:02\u00a013/11/2026',
                    onPress: () {},
                  ),
                ],
              ),
            ),
            GuestBar(
              items: [
                for (final label in [
                  'Trang chủ',
                  'Dự án',
                  'Tìm căn',
                  'Thông báo',
                  'Menu',
                ])
                  BarItem(
                    key: label,
                    label: label,
                    icon: Ionicons.home,
                    iconOn: Ionicons.home,
                    onPress: () {},
                  ),
              ],
            ),
          ],
        ),
        scale: scale,
      );
      expect(t.takeException(), isNull);
      for (final label in ['Trang chủ', 'Thông báo']) {
        expect(t.getSize(find.byType(GuestBar)).height, lessThan(844 / 4));
        final text = t.widget<m.Text>(find.text(label));
        expect(text.maxLines, isNull);
      }
    });
  }
  testWidgets('heart sits on the cover, compare chip in the footer', (t) async {
    await mount(
      t,
      ProjectCard(
        p: const ProjectCardData(
          name: 'Dự án',
          status: 'selling',
          code: 'P',
          priceFrom: '2000000000',
        ),
        onPress: () {},
      ),
    );
    final card = t.getRect(find.byType(ProjectCard));
    final chip = t.getRect(find.bySemanticsLabel('So sánh Dự án'));
    final heart = t.getRect(find.bySemanticsLabel('Yêu thích Dự án'));
    expect(card.right - heart.right, closeTo(12, 1));
    expect(heart.top - card.top, closeTo(12, 1));
    expect(chip.top, greaterThan(heart.bottom));
  });
  // RN main splash is white with the user's photo, so both use dark icons.
  testWidgets('light headers and white splash both use dark icons', (t) async {
    expect(
      c.headerTheme.systemOverlayStyle!.statusBarIconBrightness,
      m.Brightness.dark,
    );
    await mount(t, const BrandSplash());
    final overlay = t.widget<m.AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(m.AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(overlay.value.statusBarIconBrightness, m.Brightness.dark);
    expect(find.byType(m.CircularProgressIndicator), findsNothing);
    expect(
      find.image(const m.AssetImage('assets/splash-bg.jpg')),
      findsOneWidget,
    );
  });
  testWidgets('Screen and ListScreen have the same first-content offset', (
    t,
  ) async {
    await mount(t, const Screen(children: [m.Text('First')]));
    final top = t.getTopLeft(find.text('First')).dy;
    await mount(
      t,
      ListScreen<String>(
        data: const ['First'],
        keyOf: (s) => s,
        renderItem: m.Text.new,
      ),
    );
    expect(t.getTopLeft(find.text('First')).dy, top);
  });
}
