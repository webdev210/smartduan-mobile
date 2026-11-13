import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/project_facts.dart';

import 'alignment_test.dart' show contentRect;
import '../screens/app/task_h_fakes.dart';
import '../screens/app/m5d_r5_project_test.dart' show mount;
import '../screens/public/detail_screens_test.dart' show project;

double baseline(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderParagraph>(finder);
  return box
      .localToGlobal(
        Offset(
          0,
          box.getDryBaseline(
            BoxConstraints.tight(box.size),
            TextBaseline.alphabetic,
          )!,
        ),
      )
      .dy;
}

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('internal developer and price align at $scale', (tester) async {
      tester.view.physicalSize = const Size(414, 1400);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final env = HEnv();
      env.http.respond = (r) => r.path == '/projects/p'
          ? const Reply(200, {
              ...hProject,
              'developer_name': 'ACME',
              'developer_id': 'dev',
            })
          : hReply(r.path);
      await mount(tester, env.container, const ProjectScreen(id: 'p'));
      final name = find.text('ACME');
      await tester.ensureVisible(name);
      final logo = find.descendant(
        of: find.ancestor(of: name, matching: find.byType(kit.Pressable)),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 40 && w.height == 40,
        ),
      );
      expect(tester.getCenter(name).dy, closeTo(tester.getCenter(logo).dy, .5));
      final caption = find.text('Chủ đầu tư');
      if (scale <= 1.3) {
        expect(
          baseline(tester, caption),
          closeTo(baseline(tester, find.text('Giá từ')), .5),
        );
        // Price and name occupy the same value row, despite the 40dp logo.
        final price = find.descendant(
          of: find
              .descendant(
                of: find.byType(ProjectFacts),
                matching: find.byType(kit.Body),
              )
              .at(1),
          matching: find.byType(Text),
        );
        expect(
          tester.getCenter(name).dy,
          closeTo(tester.getCenter(price).dy, .5),
        );
        if (tester.getSize(name).height == tester.getSize(price).height) {
          expect(baseline(tester, name), closeTo(baseline(tester, price), .5));
        }
      }
      expect(tester.takeException(), isNull);
    });
    testWidgets('public developer logo aligns with name at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(414, 1400);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final env = HEnv(roles: []);
      final container = ProviderContainer.test(
        overrides: [
          apiClientProvider.overrideWithValue(env.client),
          fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
        ],
      );
      await mount(tester, container, const ProjectDetailScreen(code: 'SKY'));
      final boardIcon = find.byIcon(Ionicons.lockOpenOutline);
      final board = find.ancestor(
        of: boardIcon,
        matching: find.byType(kit.Pressable),
      );
      final boardText = find.descendant(of: board, matching: find.byType(Text));
      final group = contentRect(
        tester,
        boardIcon,
      ).expandToInclude(contentRect(tester, boardText));
      expect(group.center.dx, closeTo(tester.getCenter(board).dx, .5));
      final name = find.text('Chủ đầu tư A');
      await tester.ensureVisible(name);
      final card = find
          .ancestor(of: name, matching: find.byType(kit.Card))
          .first;
      final logo = find.descendant(
        of: card,
        matching: find.byIcon(Ionicons.businessOutline),
      );
      expect(tester.getCenter(name).dy, closeTo(tester.getCenter(logo).dy, .5));
      expect(tester.getSize(logo).height, 40);
      expect(
        tester.getRect(find.text('Chủ đầu tư')).bottom,
        lessThan(tester.getRect(name).top),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
