import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import '../support/responsive.dart';

void main() {
  for (final label in ['Xem tất cả', 'Tất cả tính năng']) {
    testWidgets(
      'Section $label uses RN bottom alignment and precedes chevron',
      (t) async {
        await expectResponsive(t, () async {
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: kit.Section(
                    title: 'Truy cập nhanh',
                    eyebrow: '1 dự án được phân bổ',
                    action: (label: label, onPress: () {}),
                    child: const Text('Nội dung'),
                  ),
                ),
              ),
            ),
          );
          final title = find.text('Truy cập nhanh'), action = find.text(label);
          final chevron = find.byIcon(Ionicons.chevronForward);
          expect(
            t.getRect(action).right,
            lessThanOrEqualTo(t.getRect(chevron).left),
          );
          expect(
            t.getRect(action).bottom,
            closeTo(t.getRect(chevron).bottom, .1),
          );
          // RN places the action beside the heading when it fits, below otherwise.
          if (t.getRect(action).left >= t.getRect(title).right) {
            expect(
              t.getRect(action).bottom,
              closeTo(t.getRect(title).bottom, .1),
            );
          } else {
            expect(
              t.getRect(action).top,
              greaterThanOrEqualTo(t.getRect(title).bottom),
            );
          }
          final hit = find.ancestor(
            of: action,
            matching: find.byType(kit.Pressable),
          );
          expect(t.getSize(hit).height, greaterThanOrEqualTo(48));
        });
      },
    );
  }
}
