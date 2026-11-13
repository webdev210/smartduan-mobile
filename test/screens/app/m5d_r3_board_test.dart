import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import '../../realtime/fakes.dart';
import 'task_h_fakes.dart';

class BlockUnits extends BoardUnits {
  BlockUnits(super.client);
  @override
  Future<StackPlan> fetchStackPlan(String blockId) async => StackPlan(
    block: BlockRef(id: blockId),
    layout: 'floors',
    axes: ['01', '02'],
    floors: [
      StackFloor(
        floor: 1,
        cells: [
          StackCell(
            id: 'u1',
            code: 'A101',
            axis: '01',
            status: 'available',
            bedrooms: 1,
          ),
          if (blockId == 'a')
            StackCell(
              id: 'u2',
              code: 'A102',
              axis: '02',
              status: 'available',
              bedrooms: 2,
            ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets(
    'changing blocks preserves customer criteria and explains incompatibility',
    (tester) async {
      final env = HEnv();
      final projects = BoardProjects(env.client)
        ..blocks = [
          const Block(id: 'a', name: 'Toà A'),
          const Block(id: 'b', name: 'Toà B'),
        ];
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(() => env.session),
          apiClientProvider.overrideWithValue(env.client),
          projectsApiProvider.overrideWithValue(projects),
          unitsApiProvider.overrideWithValue(BlockUnits(env.client)),
          inventorySocketProvider('p').overrideWithValue(BoardSocket()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BoardScreen(projectId: 'p')),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<kit.SearchBar>(find.byType(kit.SearchBar)).onFilter!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 PN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem 1 căn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toà B'));
      await tester.pumpAndSettle();
      expect(find.text('2 PN'), findsOneWidget);
      expect(find.textContaining('Bộ lọc vẫn được giữ'), findsOneWidget);
    },
  );
}
