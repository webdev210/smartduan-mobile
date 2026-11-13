import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/ui/kit.dart';

import 'kit_test.dart' show mount;

m.Size paintedCard(WidgetTester tester, Finder card) => tester.getSize(
  find.descendant(of: card, matching: find.byType(m.DecoratedBox)).first,
);

void main() {
  testWidgets('pressable callers retain their painted control heights', (
    tester,
  ) async {
    for (final kind in ['primary', 'secondary', 'soft', 'danger', 'link']) {
      for (final small in [false, true]) {
        await mount(
          tester,
          m.Center(
            child: Button(
              title: 'Save',
              kind: kind,
              size: small ? 'sm' : 'md',
              onPress: () {},
            ),
          ),
        );
        final painted = find
            .descendant(
              of: find.byType(Button),
              matching: find.byType(m.DecoratedBox),
            )
            .first;
        expect(tester.getSize(painted).height, small ? 48 : 52);
      }
    }
    await mount(
      tester,
      m.Center(
        child: Chip(label: 'A', onPress: () {}),
      ),
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(Chip),
              matching: find.byType(m.Material),
            ),
          )
          .height,
      38,
    );
    await mount(
      tester,
      m.Center(
        child: IconButton(icon: Ionicons.add, label: 'Add', onPress: () {}),
      ),
    );
    expect(
      tester.getSize(
        find
            .descendant(
              of: find.byType(IconButton),
              matching: find.byType(m.DecoratedBox),
            )
            .first,
      ),
      const m.Size(44, 44),
    );
    await mount(
      tester,
      m.Column(
        mainAxisSize: m.MainAxisSize.min,
        children: [
          Segmented(
            value: 'a',
            onChange: (_) {},
            options: const [
              (key: 'a', label: 'One', count: null),
              (key: 'b', label: 'Two', count: null),
            ],
          ),
        ],
      ),
    );
    final segments = find.descendant(
      of: find.byType(Segmented<String>),
      matching: find.byType(m.Material),
    );
    expect(segments, findsNWidgets(2));
    for (final element in segments.evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, 40);
    }
    await mount(
      tester,
      m.Center(
        child: ListItem(title: 'Item', onPress: () {}),
      ),
    );
    expect(tester.getSize(find.byType(ListItem)).height, 60);
  });

  testWidgets('pressable Card preserves expanded and stretched constraints', (
    tester,
  ) async {
    await mount(
      tester,
      m.Center(
        child: m.SizedBox(
          width: 300,
          height: 120,
          child: m.Row(
            crossAxisAlignment: m.CrossAxisAlignment.stretch,
            children: [
              m.Expanded(
                child: Card(onPress: () {}, child: const Body('A')),
              ),
            ],
          ),
        ),
      ),
    );
    expect(paintedCard(tester, find.byType(Card)), const m.Size(300, 120));
  });

  testWidgets('TileGrid painted tiles fill equal cells for different labels', (
    tester,
  ) async {
    await mount(
      tester,
      m.Center(
        child: m.SizedBox(
          width: 360,
          child: TileGrid(
            children: [
              for (final label in ['A', 'Two words', 'A longer wrapping label'])
                Tile(icon: Ionicons.home, label: label, onPress: () {}),
            ],
          ),
        ),
      ),
    );
    final sizes = [
      for (var i = 0; i < 3; i++) paintedCard(tester, find.byType(Card).at(i)),
    ];
    for (final size in sizes) {
      expect(size.width, closeTo(340 / 3, .001));
      expect(size.height, sizes.first.height);
    }
  });

  testWidgets(
    '24px pressable keeps paint and centres in a tappable 48px area',
    (tester) async {
      var taps = 0;
      await mount(
        tester,
        m.Center(
          child: Card(
            padding: m.EdgeInsets.zero,
            style: const m.BoxDecoration(border: m.Border()),
            onPress: () => taps++,
            child: const m.SizedBox(width: 24, height: 24),
          ),
        ),
      );
      final target = find.byType(Card);
      expect(tester.getSize(target), const m.Size(48, 48));
      expect(paintedCard(tester, target), const m.Size(24, 24));
      final paint = find
          .descendant(of: target, matching: find.byType(m.DecoratedBox))
          .first;
      expect(tester.getCenter(paint), tester.getCenter(target));
      await tester.tapAt(tester.getTopLeft(target) + const m.Offset(1, 1));
      expect(taps, 1);
    },
  );
}
