import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/project_history.dart';

import '../../realtime/fakes.dart';

void main() {
  late ApiClient client;
  late BoardUnits units;
  setUp(() {
    client = ApiClient();
    units = BoardUnits(client);
  });
  tearDown(() => client.close());
  Future<void> mount(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ProjectHistoryScreen(projectId: 'p'),
        ),
        GoRoute(
          path: '/can/:id',
          builder: (_, state) => Text('Unit ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(BoardSession.new),
          unitsApiProvider.overrideWithValue(units),
          inventorySocketProvider('p').overrideWithValue(BoardSocket()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('history reads labels from the shared inventory cache', (
    tester,
  ) async {
    units.history = Paged(
      data: [HistoryRow(id: 'h', unitId: 'u1', field: 'status')],
      total: 1,
      page: 1,
      perPage: 100,
    );
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(BoardSession.new),
        unitsApiProvider.overrideWithValue(units),
        inventorySocketProvider('p').overrideWithValue(BoardSocket()),
      ],
    );
    container.listen(inventoryUnitsProvider('p'), (_, _) {});
    await container.read(inventoryUnitsSourceProvider('p').future);
    units.units = [const Unit(id: 'u1', code: 'UNEXPECTED-REFETCH')];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectHistoryScreen(projectId: 'p')),
      ),
    );
    await tester.pumpAndSettle();
    expect(units.reads, 1);
    expect(find.textContaining('A-12.05'), findsOneWidget);
  });

  testWidgets('history empty and error states with retry', (tester) async {
    units.historyError = const ApiError(
      500,
      'server_error',
      'Có lỗi, vui lòng thử lại',
    );
    await mount(tester);
    expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
    units.historyError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thay đổi nào.'), findsOneWidget);
  });
  testWidgets(
    'code lookup, status labels, field filter, folded search and unit navigation',
    (tester) async {
      units.history = Paged(
        page: 1,
        perPage: 100,
        data: [
          HistoryRow(
            id: 'h1',
            unitId: 'u1',
            field: 'status',
            oldValue: 'available',
            newValue: 'sold',
            source: 'manual',
          ),
          HistoryRow(id: 'h2', unitId: 'u1', field: 'fund', newValue: 'cheo'),
        ],
        total: 10,
      );
      await mount(tester);
      expect(find.text('2/10 thay đổi gần nhất'), findsOneWidget);
      expect(
        find.text('A-12.05 · Trạng thái: Còn hàng → Đã bán'),
        findsOneWidget,
      );
      await tester.tap(find.text('Quỹ'));
      await tester.pumpAndSettle();
      expect(find.text('1 trong 2 thay đổi gần nhất'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('Không có thay đổi nào khớp.'), findsOneWidget);
      await tester.tap(find.text('Xoá tìm kiếm & bộ lọc'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'da ban');
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-12.05 · Trạng thái: Còn hàng → Đã bán'));
      await tester.pumpAndSettle();
      expect(find.text('Unit u1'), findsOneWidget);
    },
  );
}
