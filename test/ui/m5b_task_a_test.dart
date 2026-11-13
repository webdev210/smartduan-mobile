import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:smartduan/ui/bottom_bar.dart';
import 'package:smartduan/ui/developer_chip.dart';
import 'package:smartduan/ui/format.dart';
import 'package:smartduan/ui/in_app.dart';
import 'package:smartduan/ui/kit.dart';
import 'package:smartduan/ui/project_card.dart';

import 'kit_test.dart' show mount;

void main() {
  testWidgets('14 sheet header and footer scroll above landscape keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const m.Size(640, 320);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.reset);
    var saved = false;
    await mount(
      tester,
      Sheet(
        visible: true,
        onClose: () {},
        title: 'Bộ lọc dự án',
        footer: Button(title: 'Áp dụng', onPress: () => saved = true),
        children: const [m.SizedBox(height: 300), Body('Nội dung')],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    expect(saved, isTrue);
  });

  for (final spec in [(320.0, 1.0), (400.0, 1.5), (400.0, 1.0)]) {
    testWidgets('16 responsive equal tiles at $spec', (tester) async {
      await mount(
        tester,
        m.MediaQuery(
          data: m.MediaQueryData(textScaler: m.TextScaler.linear(spec.$2)),
          child: m.Center(
            child: m.SizedBox(
              width: spec.$1,
              child: TileGrid(
                children: [
                  for (final label in [
                    'Dự án',
                    'Thông báo của bạn',
                    'Tài khoản',
                  ])
                    Tile(icon: m.Icons.home, label: label, onPress: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      final first = tester.getRect(find.byType(Tile).at(0));
      final second = tester.getRect(find.byType(Tile).at(1));
      final third = tester.getRect(find.byType(Tile).at(2));
      expect(first.size, second.size);
      expect(third.top > first.top, spec.$1 == 320 || spec.$2 > 1.3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('18 screen and lazy list centre readable content', (
    tester,
  ) async {
    tester.view.physicalSize = const m.Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mount(
      tester,
      const Screen(children: [m.SizedBox(key: m.Key('content'), height: 40)]),
    );
    expect(tester.getSize(find.byKey(const m.Key('content'))).width, 600);
    expect(tester.getCenter(find.byKey(const m.Key('content'))).dx, 512);
    await mount(
      tester,
      ListScreen<int>(
        data: const [1],
        keyOf: (n) => '$n',
        renderItem: (_) => const m.SizedBox(key: m.Key('item'), height: 40),
      ),
    );
    expect(tester.getSize(find.byKey(const m.Key('item'))).width, 600);
    expect(tester.getCenter(find.byKey(const m.Key('item'))).dx, 512);
  });

  testWidgets('20 section links and developer chips have 48dp targets', (
    tester,
  ) async {
    var taps = 0;
    await mount(
      tester,
      m.Column(
        children: [
          Section(
            title: 'Dự án',
            action: (label: 'Xem', onPress: () => taps++),
            child: const Body('Nội dung'),
          ),
          DeveloperChip(name: 'A', logo: null, onPress: () => taps++),
        ],
      ),
    );
    final target = find
        .ancestor(
          of: find.text('Xem'),
          matching: find.byType(m.GestureDetector),
        )
        .first;
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byType(DeveloperChip)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tapAt(tester.getTopLeft(target) + const m.Offset(2, 2));
    await tester.tap(find.byType(DeveloperChip));
    expect(taps, 2);
  });

  testWidgets('23 H1 and H2 expose heading semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await mount(
      tester,
      const m.Column(children: [H1('Dự án'), H2('Chi tiết')]),
    );
    for (final text in ['Dự án', 'Chi tiết']) {
      expect(
        tester.getSemantics(find.text(text)).flagsCollection.isHeader,
        isTrue,
      );
    }
    handle.dispose();
  });

  testWidgets('24 tab announces unread badge', (tester) async {
    final handle = tester.ensureSemantics();
    await mount(
      tester,
      GuestBar(
        items: [
          BarItem(
            key: 'notifications',
            label: 'Thông báo',
            icon: m.Icons.notifications,
            iconOn: m.Icons.notifications,
            badge: '7',
            onPress: () {},
          ),
        ],
      ),
    );
    expect(find.bySemanticsLabel('Thông báo, 7 chưa đọc'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('25 loading button announces progress and restores action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mount(tester, Button(title: 'Lưu', loading: true, onPress: () {}));
    expect(find.bySemanticsLabel('Lưu, đang xử lý'), findsOneWidget);
    expect(
      tester
              .getSemantics(find.bySemanticsLabel('Lưu, đang xử lý'))
              .flagsCollection
              .isEnabled ==
          Tristate.isTrue,
      isFalse,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is m.Semantics && w.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    await mount(tester, Button(title: 'Lưu', onPress: () {}));
    expect(find.bySemanticsLabel('Lưu'), findsOneWidget);
    expect(find.bySemanticsLabel('Lưu, đang xử lý'), findsNothing);
    handle.dispose();
  });

  testWidgets('26 keyboard focus paints a ring; touch focus does not', (
    tester,
  ) async {
    final manager = m.FocusManager.instance;
    addTearDown(
      () => manager.highlightStrategy = m.FocusHighlightStrategy.automatic,
    );
    manager.highlightStrategy = m.FocusHighlightStrategy.alwaysTraditional;
    await mount(tester, Button(title: 'Lưu', onPress: () {}));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final rings = find.descendant(
      of: find.byType(Button),
      matching: find.byWidgetPredicate(
        (w) => w is m.CustomPaint && w.foregroundPainter != null,
      ),
    );
    expect(rings, findsOneWidget);
    manager.highlightStrategy = m.FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(rings, findsNothing);
  });

  testWidgets(
    '27 informational chip is full contrast without button semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      await mount(tester, const Chip(label: 'Chủ đầu tư', informational: true));
      expect(
        tester.getSemantics(find.text('Chủ đầu tư')).flagsCollection.isButton,
        isFalse,
      );
      expect(tester.widget<m.Opacity>(find.byType(m.Opacity)).opacity, 1);
      handle.dispose();
    },
  );

  for (final throws in [false, true]) {
    testWidgets('34 failed external launch offers copy (throws: $throws)', (
      tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        if (throws) throw PlatformException(code: 'unavailable');
        return false;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(
        tester,
        m.Builder(
          builder: (context) => Button(
            title: 'Gọi',
            onPress: () => openInApp(context, 'tel:0901234567'),
          ),
        ),
      );
      await tester.tap(find.text('Gọi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Không mở được liên kết. Vui lòng thử lại.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sao chép'));
      await tester.pumpAndSettle();
      expect(copied, '0901234567');
    });
  }

  testWidgets(
    '44 bounded horizontal cards pin facts without placeholder rows',
    (tester) async {
      await mount(
        tester,
        m.SingleChildScrollView(
          child: m.SizedBox(
            height: 480,
            child: m.Row(
              crossAxisAlignment: m.CrossAxisAlignment.stretch,
              children: [
                ProjectCard(
                  width: 240,
                  p: const ProjectCardData(
                    status: 'selling',
                    name: 'A',
                    isPublic: false,
                  ),
                  onPress: () {},
                ),
                ProjectCard(
                  width: 240,
                  p: const ProjectCardData(
                    status: 'selling',
                    name: 'Dự án tên dài xuống hai dòng',
                    isPublic: false,
                    province: 'Hà Nội',
                    developerName: 'Chủ đầu tư',
                    activity7d: 5,
                  ),
                  onPress: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ProjectCard).at(0)),
        tester.getSize(find.byType(ProjectCard).at(1)),
      );
      expect(
        tester.getTopLeft(find.text('Giá từ').at(0)).dy,
        tester.getTopLeft(find.text('Giá từ').at(1)).dy,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('45 price prefix appears once', (tester) async {
    await mount(
      tester,
      Screen(
        children: [
          ProjectCard(
            p: const ProjectCardData(
              status: 'selling',
              name: 'A',
              isPublic: false,
              priceFrom: '2000000000',
            ),
            onPress: () {},
          ),
        ],
      ),
    );
    expect(find.text('Giá từ'), findsOneWidget);
    expect(find.text('2 tỷ'), findsOneWidget);
    expect(find.text('Giá từ 2 tỷ'), findsNothing);
  });

  test('46 Vietnamese decimals and currency unit', () {
    expect(fmtPrice('1234.5678'), '1.234,568 đ');
    expect(fmtArea('1234.5'), '1.234,5 m²');
    expect(fmtArea('NaN'), '—');
  });

  testWidgets('47 AsyncView accepts an existing contextual skeleton', (
    tester,
  ) async {
    await mount(
      tester,
      Screen(
        children: [
          AsyncView<int>(
            value: const AsyncLoading(),
            loading: const ProjectCardSkeleton(),
            builder: (_) => const Body('Loaded'),
          ),
        ],
      ),
    );
    expect(find.byType(ProjectCardSkeleton), findsOneWidget);
    expect(find.byType(Loading), findsNothing);
  });

  testWidgets('48 sheet has no drag handle and keeps dragging disabled', (
    tester,
  ) async {
    await mount(
      tester,
      Sheet(
        visible: true,
        onClose: () {},
        title: 'Bộ lọc',
        child: const Body('Nội dung'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is m.Container &&
            w.constraints?.maxWidth == 40 &&
            w.constraints?.maxHeight == 4,
      ),
      findsNothing,
    );
    expect(
      tester.widget<m.BottomSheet>(find.byType(m.BottomSheet)).enableDrag,
      isFalse,
    );
  });

  testWidgets('49 hero retains content without decorative circles', (
    tester,
  ) async {
    await mount(tester, const Hero(child: Body('Tài khoản')));
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Hero),
        matching: find.byType(m.Positioned),
      ),
      findsNothing,
    );
  });
}
