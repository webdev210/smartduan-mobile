import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import '../support/responsive.dart';

void main() {
  for (final label in ['Xem tất cả', 'Tất cả tính năng']) {
    testWidgets('Section $label follows title baseline and precedes chevron', (
      t,
    ) async {
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
        final scale = MediaQuery.textScalerOf(t.element(action)).scale(1);
        final titleBox = t.renderObject<RenderParagraph>(title);
        final actionBox = t.renderObject<RenderParagraph>(action);
        if (scale < 1.5) {
          final titleBaseline = titleBox
              .localToGlobal(
                Offset(
                  0,
                  titleBox.getDryBaseline(
                    BoxConstraints.tight(titleBox.size),
                    TextBaseline.alphabetic,
                  )!,
                ),
              )
              .dy;
          final actionBaseline = actionBox
              .localToGlobal(
                Offset(
                  0,
                  actionBox.getDryBaseline(
                    BoxConstraints.tight(actionBox.size),
                    TextBaseline.alphabetic,
                  )!,
                ),
              )
              .dy;
          expect(titleBaseline, closeTo(actionBaseline, .1));
          expect(actionBox.didExceedMaxLines, isFalse);
        }
        final hit = find.ancestor(
          of: action,
          matching: find.byType(kit.Pressable),
        );
        expect(t.getSize(hit).height, greaterThanOrEqualTo(48));
      });
    });
  }
}
