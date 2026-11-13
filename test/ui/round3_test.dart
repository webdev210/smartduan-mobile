// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:smartduan/ui/kit.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/theme.dart' as c;
import 'package:smartduan/screens/public/home.dart' show footerDisplayLabel;
import 'package:ionicons/ionicons.dart';

import 'board_filter_test.dart' show boardPlan;
import 'kit_test.dart' show mount;

void main() {
  testWidgets('AsyncView preserves bounded list constraints during refresh', (
    tester,
  ) async {
    await mount(
      tester,
      AsyncView<List<int>>(
        value: const AsyncLoading<List<int>>().copyWithPrevious(
          const AsyncData([1, 2]),
        ),
        builder: (rows) => ListScreen<int>(
          data: rows,
          keyOf: (i) => '$i',
          renderItem: (i) => Body('$i'),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(m.LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('project skeleton reserves card structure at scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const m.Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: m.MaterialApp(
            home: m.Scaffold(
              body: m.MediaQuery(
                data: m.MediaQueryData(textScaler: m.TextScaler.linear(scale)),
                child: m.Row(
                  crossAxisAlignment: m.CrossAxisAlignment.start,
                  children: [
                    const ProjectCardSkeleton(width: 320),
                    ProjectCard(
                      width: 320,
                      p: PublicProject(
                        id: 'p',
                        code: 'P',
                        name: 'A\nB',
                        status: 'selling',
                        province: 'Location',
                        developer: const ProjectDeveloper(
                          id: 'd',
                          name: 'Developer',
                        ),
                        projectType: 'apartment',
                      ),
                      onPress: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ProjectCardSkeleton)).height,
        closeTo(tester.getSize(find.byType(ProjectCard)).height, 2),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'sheet footer dismissal animates and sheet drag dismisses keyboard',
    (tester) async {
      var visible = true;
      late m.StateSetter update;
      await mount(
        tester,
        m.StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Sheet(
              visible: visible,
              onClose: () => setState(() => visible = false),
              title: 'Sheet title',
              children: const [
                Field(label: 'Sheet input'),
                m.SizedBox(height: 1400),
              ],
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(m.TextField));
      await tester.pump();
      await tester.drag(
        find.byType(m.SingleChildScrollView),
        const m.Offset(0, -200),
      );
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      update(() => visible = false);
      await tester.pump();
      expect(find.text('Sheet title'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Sheet title'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Sheet title'), findsNothing);
    },
  );
  test(
    'footer labels capitalise display text without dropping Vietnamese accents',
    () {
      expect(
        footerDisplayLabel('Dự án căn hộ Hồ Chí Minh'),
        'Căn hộ Hồ Chí Minh',
      );
      expect(footerDisplayLabel('đất nền'), 'Đất nền');
      expect(footerDisplayLabel(''), '');
    },
  );
  test('hidden status foreground meets AA', () {
    const background = m.Color(0xFF9CA3AF);
    final foreground = c.solidForeground(background);
    expect(
      (background.computeLuminance() + .05) /
          (foreground.computeLuminance() + .05),
      greaterThanOrEqualTo(4.5),
    );
  });
  testWidgets('chips and solid pills use the readable hidden foreground', (
    tester,
  ) async {
    await mount(
      tester,
      m.Column(
        children: [
          Chip(
            label: 'Hidden chip',
            active: true,
            color: const m.Color(0xFF9CA3AF),
            onPress: () {},
          ),
          const Pill(label: 'Hidden pill', color: m.Color(0xFF9CA3AF)),
        ],
      ),
    );
    for (final label in ['Hidden chip', 'Hidden pill']) {
      expect(tester.widget<m.Text>(find.text(label)).style!.color, c.text);
    }
  });
  testWidgets('loading button retains its wrapped label footprint', (
    tester,
  ) async {
    Future<void> show(bool loading) => mount(
      tester,
      m.MediaQuery(
        data: const m.MediaQueryData(textScaler: m.TextScaler.linear(2)),
        child: m.Align(
          child: m.SizedBox(
            width: 180,
            child: Button(
              title: 'A long button label',
              size: 'sm',
              loading: loading,
              onPress: () {},
            ),
          ),
        ),
      ),
    );
    await show(false);
    final size = tester.getSize(find.byType(Button));
    await show(true);
    expect(tester.getSize(find.byType(Button)), size);
  });
  testWidgets(
    'small controls have separate 48dp hit areas with original visuals',
    (tester) async {
      var presses = 0;
      await mount(
        tester,
        m.Column(
          children: [
            Chips(
              children: [
                Chip(label: 'A', onPress: () => presses++),
                Chip(label: 'B', onPress: () => presses++),
              ],
            ),
            IconButton(icon: Ionicons.add, label: 'Add', onPress: () {}),
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
      final a = tester.getRect(find.byType(Chip).first);
      final b = tester.getRect(find.byType(Chip).last);
      expect(a.height, greaterThanOrEqualTo(48));
      expect(a.width, greaterThanOrEqualTo(48));
      expect(a.overlaps(b), isFalse);
      await tester.tapAt(a.topCenter + const m.Offset(0, 1));
      expect(presses, 1);
      expect(tester.getSize(find.byType(IconButton)), const m.Size(48, 48));
    },
  );
  testWidgets('Screen drag dismisses the focused keyboard', (tester) async {
    await mount(
      tester,
      const Screen(
        children: [
          Field(label: 'Input'),
          m.SizedBox(height: 1400),
        ],
      ),
    );
    await tester.tap(find.byType(m.TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.drag(
      find.byType(m.SingleChildScrollView),
      const m.Offset(0, -200),
    );
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });
  testWidgets('Notice exposes its text as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await mount(tester, const Notice(text: 'Saved'));
    expect(
      tester.getSemantics(find.byType(Notice)),
      matchesSemantics(label: 'Saved', isLiveRegion: true),
    );
    handle.dispose();
  });
  testWidgets(
    'refresh retains the mounted editable content and reports failure',
    (tester) async {
      Future<void> show(AsyncValue<String> value) => mount(
        tester,
        AsyncView(
          value: value,
          builder: (_) => const Field(label: 'Name'),
        ),
      );
      await show(const AsyncData('data'));
      await tester.enterText(find.byType(m.TextField), 'unsaved');
      final element = tester.element(find.byType(m.TextField));
      await show(
        const AsyncLoading<String>().copyWithPrevious(const AsyncData('data')),
      );
      expect(tester.element(find.byType(m.TextField)), same(element));
      expect(find.text('unsaved'), findsOneWidget);
      expect(find.byType(m.LinearProgressIndicator), findsOneWidget);
      await show(
        AsyncError<String>(
          Exception(),
          StackTrace.empty,
        ).copyWithPrevious(const AsyncData('data')),
      );
      expect(tester.element(find.byType(m.TextField)), same(element));
      expect(find.byType(ErrorBox), findsOneWidget);
      await show(const AsyncLoading());
      expect(find.byType(m.TextField), findsNothing);
    },
  );

  testWidgets(
    'filled Field exposes one label and its error on the editable node',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(
        tester,
        const Field(label: 'Price', value: '12', error: 'Invalid'),
      );
      final node = tester.getSemantics(find.byType(m.TextField));
      expect(node.label, 'Price');
      expect(node.hint, contains('Invalid'));
      expect(find.bySemanticsLabel('Price'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'StackGrid cells and columns grow at text scale two without overflow',
    (tester) async {
      Future<void> show(double scale) => mount(
        tester,
        m.MediaQuery(
          data: m.MediaQueryData(textScaler: m.TextScaler.linear(scale)),
          child: StackGrid(plan: boardPlan, onOpen: (_) {}),
        ),
      );
      await show(1);
      final normal = tester.getSize(
        find
            .ancestor(
              of: find.text('A-01.01'),
              matching: find.byType(m.Material),
            )
            .first,
      );
      await show(2);
      final large = tester.getSize(
        find
            .ancestor(
              of: find.text('A-01.01'),
              matching: find.byType(m.Material),
            )
            .first,
      );
      expect(large.height, greaterThan(normal.height));
      expect(large.width, greaterThan(normal.width));
      expect(tester.takeException(), isNull);
    },
  );
}
