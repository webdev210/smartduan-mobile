import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'alignment_test.dart' show contentRect;
import '../screens/app/task_h_fakes.dart';
import '../screens/app/m5d_r5_project_test.dart' show mount;
import '../screens/public/detail_screens_test.dart' show project;

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'internal developer aligns inside RN information card at $scale',
      (tester) async {
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
        expect(
          tester.getCenter(name).dy,
          closeTo(tester.getCenter(logo).dy, .5),
        );
        final card = find
            .ancestor(of: name, matching: find.byType(kit.Card))
            .first;
        expect(
          find.descendant(of: card, matching: find.text('Chủ đầu tư')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('Giá từ')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
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
      final identity = find
          .ancestor(of: name, matching: find.byType(Column))
          .first;
      final logoBox = find
          .ancestor(of: logo, matching: find.byType(SizedBox))
          .first;
      expect(
        tester.getCenter(identity).dy,
        closeTo(tester.getCenter(logoBox).dy, .5),
      );
      expect(tester.getSize(logoBox).height, 40);
      expect(
        tester.getRect(find.text('Chủ đầu tư')).bottom,
        closeTo(tester.getRect(name).top, .5),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
