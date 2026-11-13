import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/theme.dart' as c;
import 'package:smartduan/ui/bottom_bar.dart';

Rect contentRect(WidgetTester tester, Finder finder) {
  final render = tester.renderObject(finder);
  if (render is RenderParagraph && tester.widget(finder) is Text) {
    final boxes = render.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: render.text.toPlainText().length,
      ),
    );
    // Measure the line's horizontal extent, but retain its line box vertically.
    // Font glyph ink is not symmetric (accents/descenders); leading is tested
    // independently at the application root. Wrapped labels use their block.
    if (boxes.length == 1) {
      final line = boxes.single.toRect().shift(
        render.localToGlobal(Offset.zero),
      );
      final block = tester.getRect(finder);
      return Rect.fromLTRB(line.left, block.top, line.right, block.bottom);
    }
  }
  return tester.getRect(finder);
}

void expectCentered(
  WidgetTester tester,
  Finder control,
  List<Finder> content, {
  bool horizontal = true,
}) {
  final outer = tester.getRect(control);
  final bounds = content
      .map((f) => contentRect(tester, f))
      .reduce((a, b) => a.expandToInclude(b));
  final delta = bounds.center - outer.center;
  expect(
    delta.dy.abs(),
    lessThanOrEqualTo(.5),
    reason: 'vertical offset ${delta.dy}dp; content $bounds; control $outer',
  );
  if (horizontal) {
    expect(
      delta.dx.abs(),
      lessThanOrEqualTo(.5),
      reason: 'horizontal offset ${delta.dx}dp',
    );
  }
}

Future<void> pumpControl(
  WidgetTester tester,
  Widget child,
  double scale,
  String constraint,
  TargetPlatform platform,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: c.lightTheme.copyWith(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: DefaultTextHeightBehavior(
          textHeightBehavior: const TextHeightBehavior(
            leadingDistribution: TextLeadingDistribution.even,
          ),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: constraint == 'intrinsic'
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: child,
                )
              : SizedBox(
                  width: 374,
                  height: constraint == 'tall' ? 220 : null,
                  child: child,
                ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final constraint in ['intrinsic', 'wide', 'tall']) {
        final scenario = '$platform $scale $constraint';
        for (final label in ['Tìm căn', 'Tính lãi\nvay']) {
          testWidgets('Tile $label $scenario', (tester) async {
            await pumpControl(
              tester,
              kit.Tile(
                icon: Ionicons.homeOutline,
                label: label,
                onPress: () {},
              ),
              scale,
              constraint,
              platform,
            );
            expectCentered(tester, find.byType(kit.Tile), [
              find.byIcon(Ionicons.homeOutline),
              find.text(label),
            ]);
          });
        }
        for (final kind in ['primary', 'secondary', 'soft', 'danger', 'link']) {
          for (final size in ['sm', 'md']) {
            for (final state in ['label', 'icon', 'loading', 'loadingIcon']) {
              testWidgets('Button $kind $size $state $scenario', (
                tester,
              ) async {
                await pumpControl(
                  tester,
                  kit.Button(
                    title: 'Tìm căn',
                    onPress: () {},
                    kind: kind,
                    size: size,
                    loading: state.startsWith('loading'),
                    icon: state == 'icon' || state == 'loadingIcon'
                        ? Ionicons.homeOutline
                        : null,
                  ),
                  scale,
                  constraint,
                  platform,
                );
                expectCentered(tester, find.byType(kit.Pressable), [
                  if (state.startsWith('loading'))
                    find.byType(CircularProgressIndicator)
                  else ...[
                    find.text('Tìm căn'),
                    if (state == 'icon') find.byIcon(Ionicons.homeOutline),
                  ],
                ]);
              });
            }
          }
        }
        testWidgets('Chip $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Chip(
              label: 'Tìm căn',
              icon: Ionicons.homeOutline,
              onPress: () {},
            ),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.Chip), [
            find.text('Tìm căn'),
            find.byIcon(Ionicons.homeOutline),
          ]);
        });
        testWidgets('IconButton badge $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.IconButton(
              label: 'Thông báo',
              icon: Ionicons.homeOutline,
              badge: 3,
              onPress: () {},
            ),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.IconButton), [
            find.byIcon(Ionicons.homeOutline),
          ]);
        });
        testWidgets('Segmented equal widths $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Segmented(
              value: 'a',
              onChange: (_) {},
              options: const [
                (key: 'a', label: 'Miền Bắc', count: null),
                (key: 'b', label: 'Miền Trung', count: null),
                (key: 'c', label: 'Miền Nam', count: null),
              ],
            ),
            scale,
            constraint,
            platform,
          );
          final controls = find.byType(kit.Pressable);
          final widths = <double>[];
          for (var i = 0; i < 3; i++) {
            widths.add(tester.getSize(controls.at(i)).width);
            expectCentered(tester, controls.at(i), [
              find.descendant(of: controls.at(i), matching: find.byType(Text)),
            ]);
          }
          expect(widths.last, closeTo(widths.first, .5));
        });
        testWidgets('ListItem $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.ListItem(
              title: 'Dự án',
              subtitle: 'Thông tin',
              icon: Ionicons.homeOutline,
              onPress: () {},
            ),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.ListItem), [
            find.text('Dự án'),
            find.text('Thông tin'),
          ], horizontal: false);
          expectCentered(tester, find.byType(kit.ListItem), [
            find.byIcon(Ionicons.homeOutline),
          ], horizontal: false);
        });
        testWidgets('tappable Card $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Card(
              onPress: () {},
              children: const [Text('Dự án'), Text('Thông tin')],
            ),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.Card), [
            find.text('Dự án'),
            find.text('Thông tin'),
          ], horizontal: false);
        });
        testWidgets('Notice $scenario', (tester) async {
          await pumpControl(
            tester,
            const kit.Notice(text: 'Thông tin\ndự án'),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.Notice), [
            find.text('Thông tin\ndự án'),
          ], horizontal: false);
          expectCentered(tester, find.byType(kit.Notice), [
            find.byIcon(Ionicons.informationCircle),
          ], horizontal: false);
        });
        testWidgets('Pressable small child $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Pressable(
              onPress: () {},
              child: const SizedBox(
                width: 20,
                height: 20,
                child: Icon(Ionicons.add),
              ),
            ),
            scale,
            constraint,
            platform,
          );
          // The icon's glyph is inside Icon's own Align, even under tight constraints.
          expectCentered(tester, find.byType(kit.Pressable), [
            find.byType(RichText),
          ]);
        });
        testWidgets('Card single child $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Card(onPress: () {}, child: const Text('Dự án')),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.Card), [
            find.text('Dự án'),
          ], horizontal: false);
        });
        testWidgets('Section action icon and text $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Section(
              title: 'Dự án',
              action: (label: 'Tất cả', onPress: () {}),
              child: const SizedBox(),
            ),
            scale,
            constraint,
            platform,
          );
          final action = find.text('Tất cả');
          final icon = find.byIcon(Ionicons.chevronForward);
          expect(
            tester.getCenter(action).dy,
            closeTo(tester.getCenter(icon).dy, .5),
          );
          expectCentered(tester, find.byType(kit.Pressable), [action, icon]);
        });
        testWidgets('ButtonGroup $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.ButtonGroup(
              children: [
                kit.Button(title: 'Lưu', onPress: () {}),
                kit.Button(title: 'Huỷ', onPress: () {}, kind: 'secondary'),
              ],
            ),
            scale,
            constraint,
            platform,
          );
          for (final label in ['Lưu', 'Huỷ']) {
            expectCentered(
              tester,
              find.ancestor(
                of: find.text(label),
                matching: find.byType(kit.Pressable),
              ),
              [find.text(label)],
            );
          }
        });
        testWidgets('bottom tabs with badge $scenario', (tester) async {
          await pumpControl(
            tester,
            GuestBar(
              items: [
                BarItem(
                  key: 'home',
                  label: 'Trang chủ',
                  icon: Ionicons.homeOutline,
                  iconOn: Ionicons.home,
                  onPress: () {},
                  badge: '3',
                ),
                BarItem(
                  key: 'news',
                  label: 'Bảng tin',
                  icon: Ionicons.newspaperOutline,
                  iconOn: Ionicons.newspaper,
                  onPress: () {},
                ),
              ],
            ),
            scale,
            constraint,
            platform,
          );
          for (final (label, icon) in [
            ('Trang chủ', Ionicons.homeOutline),
            ('Bảng tin', Ionicons.newspaperOutline),
          ]) {
            final text = find.text(label);
            expectCentered(
              tester,
              find.ancestor(of: text, matching: find.byType(InkWell)),
              [
                find.ancestor(
                  of: find.byIcon(icon),
                  matching: find.byType(TabIcon),
                ),
                text,
              ],
            );
          }
        });
        testWidgets('Search input clear and filter $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.SearchBar(
              value: 'Dự án',
              onChangeText: (_) {},
              onFilter: () {},
              filterCount: 2,
            ),
            scale,
            constraint,
            platform,
          );
          final input = find.byType(TextField);
          final icon = find.byIcon(Ionicons.search);
          expect(
            tester.getCenter(input).dy,
            closeTo(tester.getCenter(icon).dy, .5),
          );
          for (final data in [Ionicons.closeCircle, Ionicons.optionsOutline]) {
            final icon = find.byIcon(data);
            expectCentered(
              tester,
              find.ancestor(of: icon, matching: find.byType(kit.Pressable)),
              [icon],
            );
          }
        });
        testWidgets('Field label input error $scenario', (tester) async {
          await pumpControl(
            tester,
            const kit.Field(label: 'Họ tên', value: 'An', error: 'Bắt buộc'),
            scale,
            constraint,
            platform,
          );
          final input = find.byType(TextField);
          expectCentered(tester, input, [
            find.byType(EditableText),
          ], horizontal: false);
          expect(
            tester.getRect(find.text('Họ tên')).bottom,
            lessThan(tester.getRect(input).top),
          );
          expect(
            tester.getRect(find.text('Bắt buộc')).top,
            greaterThan(tester.getRect(input).bottom),
          );
        });
      }
    }
  }
}
