import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/gallery_viewer.dart';
import 'package:smartduan/api/models.dart';

import '../screens/auth/auth_fakes.dart' show TestSession;
import 'alignment_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final constraint in ['intrinsic', 'wide', 'tall']) {
        final scenario = '$platform $scale $constraint';
        testWidgets('TileGrid equal controls $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.TileGrid(
              children: [
                for (final label in ['Tìm căn', 'Tính lãi vay', 'Bảng tin'])
                  kit.Tile(
                    label: label,
                    icon: Ionicons.homeOutline,
                    onPress: () {},
                  ),
              ],
            ),
            scale,
            constraint == 'tall' ? 'wide' : constraint,
            platform,
          );
          final tiles = find.byType(kit.Tile);
          for (var i = 0; i < 3; i++) {
            expect(tester.getSize(tiles.at(i)), tester.getSize(tiles.first));
            expectCentered(tester, tiles.at(i), [
              find.descendant(of: tiles.at(i), matching: find.byType(Icon)),
              find.descendant(of: tiles.at(i), matching: find.byType(Text)),
            ]);
          }
        });
        testWidgets('Chips preset controls $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.Chips(
              children: [
                for (final years in [10, 15, 20, 25, 30])
                  kit.Chip(label: '$years năm', onPress: () {}),
              ],
            ),
            scale,
            constraint,
            platform,
          );
          for (final element in find.byType(kit.Chip).evaluate()) {
            final chip = find.byElementPredicate((e) => e == element);
            expectCentered(tester, chip, [
              find.descendant(of: chip, matching: find.byType(Text)),
            ]);
          }
        });
        testWidgets('SDK app-bar back and action $scenario', (tester) async {
          await pumpControl(
            tester,
            Scaffold(
              appBar: AppBar(
                leading: BackButton(onPressed: () {}),
                title: const Text('Dự án'),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Ionicons.shareOutline),
                  ),
                ],
              ),
            ),
            scale,
            'tall',
            platform,
          );
          for (final element in find.byType(IconButton).evaluate()) {
            final control = find.byElementPredicate((e) => e == element);
            expectCentered(tester, control, [
              find.descendant(of: control, matching: find.byType(Icon)),
            ]);
          }
        });
        testWidgets('switch row $scenario', (tester) async {
          await pumpControl(
            tester,
            kit.ListItem(
              title: 'Đồng ý liên hệ',
              onPress: () {},
              right: Switch(value: false, onChanged: (_) {}),
            ),
            scale,
            constraint,
            platform,
          );
          expectCentered(tester, find.byType(kit.ListItem), [
            find.byType(Switch),
          ], horizontal: false);
          expectCentered(tester, find.byType(kit.ListItem), [
            find.text('Đồng ý liên hệ'),
          ], horizontal: false);
        });
      }
      testWidgets(
        'RN compare chip, cover favourite and status $platform $scale',
        (tester) async {
          await pumpControl(
            tester,
            ProviderScope(
              overrides: [sessionProvider.overrideWith(TestSession.new)],
              child: ProjectCard(
                p: const Browsable(code: 'P', name: 'Dự án', status: 'selling'),
                onPress: () {},
              ),
            ),
            scale,
            'wide',
            platform,
          );
          for (final (label, icon) in [
            ('So sánh Dự án', Ionicons.gitCompareOutline),
            ('Yêu thích Dự án', Ionicons.heartOutline),
          ]) {
            expectCentered(tester, find.bySemanticsLabel(label), [
              find.byIcon(icon),
              if (icon == Ionicons.gitCompareOutline) find.text('So sánh'),
            ]);
            expect(
              tester.getSize(find.bySemanticsLabel(label)).height,
              greaterThanOrEqualTo(48),
            );
          }
          final label = find.text('Đang bán');
          final pill = find
              .ancestor(of: label, matching: find.byType(Container))
              .first;
          expectCentered(tester, pill, [label]);
        },
      );
      testWidgets('gallery close and retry $platform $scale', (tester) async {
        await pumpControl(
          tester,
          GalleryViewer(images: const [(url: '', caption: 'Ảnh')]),
          scale,
          'tall',
          platform,
        );
        await tester.pumpAndSettle();
        expectCentered(tester, find.byType(IconButton), [
          find.byIcon(Ionicons.close),
        ]);
        expectCentered(tester, find.byType(TextButton), [find.text('Thử lại')]);
      });
      testWidgets('sheet header footer $platform $scale', (tester) async {
        await pumpControl(
          tester,
          kit.Sheet(
            visible: true,
            onClose: () {},
            title: 'Bộ lọc',
            footer: kit.Button(title: 'Áp dụng', onPress: () {}),
            child: const Text('Nội dung'),
          ),
          scale,
          'wide',
          platform,
        );
        await tester.pumpAndSettle();
        final title = find.text('Bộ lọc');
        final header = find
            .ancestor(of: title, matching: find.byType(Padding))
            .first;
        expectCentered(tester, header, [title], horizontal: false);
        final close = find.ancestor(
          of: find.byIcon(Ionicons.close),
          matching: find.byType(kit.Pressable),
        );
        expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
        expectCentered(tester, close, [find.byIcon(Ionicons.close)]);
        expectCentered(tester, find.byType(kit.Button), [find.text('Áp dụng')]);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
