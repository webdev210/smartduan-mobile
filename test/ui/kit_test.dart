import 'dart:async';

import 'package:material_ui/material_ui.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/ui/kit.dart';
import 'package:smartduan/ui/theme.dart' as theme;

Future<void> mount(WidgetTester tester, m.Widget child) => tester.pumpWidget(
  m.MaterialApp(
    theme: theme.lightTheme,
    home: m.Scaffold(body: child),
  ),
);

void main() {
  testWidgets('Field enforces maxLength without a character counter', (
    tester,
  ) async {
    await mount(tester, const Field(label: 'Họ và tên', maxLength: 120));
    expect(find.text('0/120'), findsNothing);
    await tester.enterText(find.byType(m.TextField), 'Nguyễn Minh');
    await tester.pump();
    expect(find.text('11/120'), findsNothing);
    final input = tester.widget<m.TextField>(find.byType(m.TextField));
    expect(input.maxLength, 120);
    expect(input.decoration!.counterText, '');
  });
  testWidgets('Card and Hero preserve spacing between RN children', (
    tester,
  ) async {
    await mount(
      tester,
      const Screen(
        children: [
          Card(children: [Body('Thẻ một'), Body('Thẻ hai')]),
          Hero(children: [Body('Hero một'), Body('Hero hai')]),
        ],
      ),
    );
    expect(
      tester.getTopLeft(find.text('Thẻ hai')).dy -
          tester.getBottomLeft(find.text('Thẻ một')).dy,
      8,
    );
    expect(
      tester.getTopLeft(find.text('Hero hai')).dy -
          tester.getBottomLeft(find.text('Hero một')).dy,
      16,
    );
  });
  test('initials preserves Vietnamese first and last initials (RN cases)', () {
    expect(initials('Nguyễn Văn An'), 'NA');
    expect(initials('đỗ thị ánh'), 'ĐÁ');
    expect(initials('  Lan  '), 'L');
  });
  test('initials uses question mark for absent names (RN cases)', () {
    expect(initials(null), '?');
    expect(initials('   '), '?');
    expect(initials(''), '?');
  });
  for (final mode in ['enabled', 'disabled', 'loading']) {
    testWidgets('Button $mode controls activation', (tester) async {
      var calls = 0;
      await mount(
        tester,
        Button(
          title: 'Lưu',
          onPress: () => calls++,
          disabled: mode == 'disabled',
          loading: mode == 'loading',
          icon: Ionicons.add,
        ),
      );
      await tester.tap(find.byType(Button));
      expect(calls, mode == 'enabled' ? 1 : 0);
      expect(
        find.byType(m.CircularProgressIndicator),
        mode == 'loading' ? findsOneWidget : findsNothing,
      );
    });
  }
  testWidgets('Field displays error and focus callbacks', (tester) async {
    var focused = false;
    await mount(
      tester,
      Field(
        label: 'Email',
        error: 'Email không hợp lệ',
        onFocus: () => focused = true,
      ),
    );
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    await tester.tap(find.byType(m.TextField));
    await tester.pump();
    expect(focused, isTrue);
    final input = tester.widget<m.TextField>(find.byType(m.TextField));
    expect(
      (input.decoration!.focusedBorder! as m.OutlineInputBorder)
          .borderSide
          .color,
      theme.danger,
    );
  });
  testWidgets('SearchBar changes, clears, submits and opens filter', (
    tester,
  ) async {
    var value = 'Nhà';
    var submits = 0;
    var filters = 0;
    await mount(
      tester,
      m.StatefulBuilder(
        builder: (context, setState) => SearchBar(
          value: value,
          onChangeText: (s) => setState(() => value = s),
          onSubmit: () => submits++,
          onFilter: () => filters++,
          filterCount: 2,
        ),
      ),
    );
    await tester.enterText(find.byType(m.TextField), 'Căn');
    expect(value, 'Căn');
    await tester.testTextInput.receiveAction(m.TextInputAction.search);
    expect(submits, 1);
    await tester.tap(find.bySemanticsLabel('Bộ lọc, đang bật 2'));
    expect(filters, 1);
    await tester.tap(find.bySemanticsLabel('Xoá từ khoá'));
    await tester.pump();
    expect(value, '');
    expect(find.bySemanticsLabel('Xoá từ khoá'), findsNothing);
  });
  testWidgets('Chip reports selection and renders active color', (
    tester,
  ) async {
    var active = false;
    await mount(
      tester,
      m.StatefulBuilder(
        builder: (context, setState) => Chip(
          label: 'Còn hàng',
          active: active,
          color: theme.success,
          onPress: () => setState(() => active = !active),
        ),
      ),
    );
    await tester.tap(find.text('Còn hàng'));
    await tester.pump();
    expect(active, isTrue);
    expect(
      tester.widget<m.Text>(find.text('Còn hàng')).style!.color,
      m.Colors.white,
    );
    expect(
      tester.getSemantics(find.byType(Chip)),
      matchesSemantics(
        label: 'Còn hàng',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
  });
  testWidgets('Segmented reports option key', (tester) async {
    String? selection = 'a';
    await mount(
      tester,
      Segmented<String>(
        value: selection,
        onChange: (s) => selection = s,
        options: const [
          (key: 'a', label: 'Tất cả', count: 4),
          (key: 'b', label: 'Đã lưu', count: 0),
        ],
      ),
    );
    await tester.tap(find.text('Đã lưu · 0'));
    expect(selection, 'b');
  });
  testWidgets('IconButton caps badge and activates', (tester) async {
    var calls = 0;
    await mount(
      tester,
      IconButton(
        icon: Ionicons.notifications,
        label: 'Thông báo',
        badge: 120,
        onPress: () => calls++,
      ),
    );
    expect(find.text('99+'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Thông báo, 120 mới'));
    expect(calls, 1);
  });
  testWidgets('Button and Card show RN pressed scale', (tester) async {
    await mount(
      tester,
      m.Column(
        children: [
          Button(title: 'Bấm', onPress: () {}),
          Card(onPress: () {}, child: const Body('Thẻ')),
        ],
      ),
    );
    final button = await tester.startGesture(
      tester.getCenter(find.byType(Button)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final transform = tester.widget<m.Transform>(
      find
          .descendant(
            of: find.byType(Button),
            matching: find.byType(m.Transform),
          )
          .first,
    );
    expect(transform.transform.storage[0], closeTo(0.98, 0.001));
    await button.up();
    await tester.pump();
    final card = await tester.startGesture(tester.getCenter(find.byType(Card)));
    await tester.pump(const Duration(milliseconds: 150));
    final cardTransform = tester.widget<m.Transform>(
      find
          .descendant(of: find.byType(Card), matching: find.byType(m.Transform))
          .first,
    );
    expect(cardTransform.transform.storage[0], closeTo(0.985, 0.001));
    await card.up();
  });
  for (final kind in ['primary', 'secondary', 'soft', 'danger', 'link']) {
    testWidgets('Button $kind supports both sizes', (tester) async {
      for (final small in [false, true]) {
        await mount(
          tester,
          m.Align(
            alignment: m.Alignment.topLeft,
            child: Button(
              title: 'Lưu',
              kind: kind,
              size: small ? 'sm' : 'md',
              onPress: () {},
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(Button)).height,
          small || kind == 'link' ? 48 : 52,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
    'Card Stat ListItem Tile Section and Empty invoke their actions',
    (tester) async {
      final calls = <String>[];
      await mount(
        tester,
        Screen(
          children: [
            Card(onPress: () => calls.add('card'), child: const Body('Thẻ')),
            Stat(
              label: 'Số căn',
              value: 10,
              icon: Ionicons.home,
              onPress: () => calls.add('stat'),
            ),
            ListItem(title: 'Hồ sơ', onPress: () => calls.add('item')),
            Tile(
              icon: Ionicons.home,
              label: 'Dự án',
              onPress: () => calls.add('tile'),
            ),
            Section(
              title: 'Danh mục',
              action: (label: 'Xem thêm', onPress: () => calls.add('section')),
              child: const Body('Chi tiết'),
            ),
            Empty(
              text: 'Chưa có dữ liệu',
              action: (label: 'Khám phá', onPress: () => calls.add('empty')),
            ),
          ],
        ),
      );
      for (final label in [
        'Thẻ',
        'Số căn',
        'Hồ sơ',
        'Dự án',
        'Xem thêm',
        'Khám phá',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(calls, ['card', 'stat', 'item', 'tile', 'section', 'empty']);
    },
  );
  testWidgets('Appear honors delay and reduced motion', (tester) async {
    await mount(tester, const Appear(delay: 200, child: Body('Xin chào')));
    final fade = find.descendant(
      of: find.byType(Appear),
      matching: find.byType(m.FadeTransition),
    );
    expect(tester.widget<m.FadeTransition>(fade).opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<m.FadeTransition>(fade).opacity.value, 0);
    await tester.pumpAndSettle();
    // The delayed animation may only schedule after the timer fires.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.widget<m.FadeTransition>(fade).opacity.value, 1);
    await mount(
      tester,
      const m.MediaQuery(
        data: m.MediaQueryData(disableAnimations: true),
        child: Appear(
          key: m.ValueKey('reduced'),
          delay: 5000,
          child: Body('Ngay'),
        ),
      ),
    );
    expect(
      tester
          .widget<m.FadeTransition>(
            find.descendant(
              of: find.byType(Appear),
              matching: find.byType(m.FadeTransition),
            ),
          )
          .opacity
          .value,
      1,
    );
  });
  testWidgets('kit lays out on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const m.Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(
      tester,
      m.MediaQuery(
        data: const m.MediaQueryData(
          size: m.Size(320, 640),
          textScaler: m.TextScaler.linear(1.5),
        ),
        child: Screen(
          children: [
            const H1('Tiêu đề'),
            const H2('Dự án'),
            const Eyebrow('Nổi bật'),
            const Muted('Mô tả'),
            const Body('Nội dung', selectable: true),
            const Hero(child: Body('Chào mừng')),
            const Avatar(name: 'Nguyễn Văn An'),
            const Row(
              label: 'Đại lý',
              value: 'Tên đại lý rất dài cần xuống dòng nhiều lần',
            ),
            const Divider(),
            const Skeleton(height: 20),
            const Pill(label: 'Đã lưu', color: theme.brand, soft: true),
            const FilterGroup(
              title: 'Loại căn',
              children: [Chip(label: 'Căn hộ')],
            ),
            const ChipRail(
              children: [
                Chip(label: 'Một lựa chọn dài'),
                Chip(label: 'Lựa chọn thứ hai'),
              ],
            ),
            TileGrid(
              children: [
                for (var i = 0; i < 4; i++)
                  Tile(icon: Ionicons.home, label: 'Dự án $i', onPress: () {}),
              ],
            ),
            for (final tone in ['info', 'success', 'warn', 'error'])
              Notice(text: 'Thông báo', tone: tone),
          ],
        ),
      ),
    );
    await tester.drag(
      find.byType(m.Scrollable).first,
      const m.Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Sheet opens and closes with close button and barrier', (
    tester,
  ) async {
    var visible = false;
    late m.StateSetter update;
    await mount(
      tester,
      m.StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return m.Column(
            children: [
              Button(
                title: 'Mở',
                onPress: () => setState(() => visible = true),
              ),
              Sheet(
                visible: visible,
                title: 'Bộ lọc',
                onClose: () => setState(() => visible = false),
                footer: const Body('Chân bảng'),
                child: const Body('Nội dung'),
              ),
            ],
          );
        },
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung'), findsOneWidget);
    expect(find.text('Chân bảng'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Đóng').last);
    await tester.pumpAndSettle();
    expect(visible, isFalse);
    expect(find.text('Nội dung'), findsNothing);
    update(() => visible = true);
    await tester.pumpAndSettle();
    await tester.tapAt(const m.Offset(10, 10));
    await tester.pumpAndSettle();
    expect(visible, isFalse);
  });
  testWidgets(
    'Sheet updates its content while open and follows caller visibility',
    (tester) async {
      var visible = true;
      var title = 'Ban đầu';
      var closed = 0;
      late m.StateSetter update;
      await mount(
        tester,
        m.StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Sheet(
              visible: visible,
              title: title,
              onClose: () => closed++,
              child: Body(title),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ban đầu'), findsNWidgets(2));
      update(() => title = 'Đã đổi');
      await tester.pumpAndSettle();
      expect(find.text('Đã đổi'), findsNWidgets(2));
      update(() => visible = false);
      await tester.pumpAndSettle();
      expect(find.text('Đã đổi'), findsNothing);
      expect(closed, 0);
    },
  );
  testWidgets('ErrorBox uses safe message and retries', (tester) async {
    var calls = 0;
    await mount(
      tester,
      ErrorBox(error: Exception('secret'), onRetry: () => calls++),
    );
    expect(find.text('Có lỗi xảy ra, thử lại sau'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    expect(calls, 1);
    await mount(
      tester,
      const ErrorBox(error: ApiError(0, 'sample', 'Mất mạng')),
    );
    expect(find.text('Mất mạng'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });
  testWidgets(
    'AsyncView renders loading error and data, including nullable data',
    (tester) async {
      var calls = 0;
      for (final value in <AsyncValue<String>>[
        const AsyncLoading(),
        AsyncError(Exception('secret'), StackTrace.empty),
        const AsyncData('Dữ liệu'),
      ]) {
        await mount(
          tester,
          AsyncView<String>(
            value: value,
            onRetry: () => calls++,
            builder: (s) => Body(s),
          ),
        );
        if (value.isLoading) {
          expect(find.byType(Loading), findsOneWidget);
        } else if (value.hasError) {
          expect(find.byType(ErrorBox), findsOneWidget);
          await tester.tap(find.text('Thử lại'));
          expect(calls, 1);
        } else {
          expect(find.text('Dữ liệu'), findsOneWidget);
        }
      }
      await mount(
        tester,
        AsyncView<String?>(
          value: const AsyncData(null),
          builder: (s) => Body(s ?? 'Trống'),
        ),
      );
      expect(find.text('Trống'), findsOneWidget);
    },
  );
  for (final list in [false, true]) {
    for (final failure in [false, true]) {
      testWidgets(
        '${list ? 'ListScreen' : 'Screen'} refresh ${failure ? 'failure' : 'success'} ends spinner',
        (tester) async {
          final done = Completer<void>();
          var calls = 0;
          Future<void> refresh() {
            calls++;
            return done.future;
          }

          await mount(
            tester,
            list
                ? ListScreen<int>(
                    data: const [1],
                    keyOf: (i) => '$i',
                    renderItem: (i) => Body('$i'),
                    onRefresh: refresh,
                  )
                : Screen(
                    onRefresh: refresh,
                    children: const [Body('Nội dung')],
                  ),
          );
          expect(calls, 0);
          expect(find.byType(m.RefreshProgressIndicator), findsNothing);
          await tester.drag(
            find.byType(m.Scrollable).first,
            const m.Offset(0, 400),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(calls, 1);
          expect(find.byType(m.RefreshProgressIndicator), findsOneWidget);
          if (failure) {
            done.completeError(Exception('mạng'));
          } else {
            done.complete();
          }
          await tester.pumpAndSettle();
          expect(find.byType(m.RefreshProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
