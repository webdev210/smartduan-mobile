import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/ui/stack_grid.dart';
import 'package:smartduan/ui/kit.dart' show Screen;

import '../../realtime/fakes.dart';

void main() {
  late ApiClient client;
  late BoardUnits units;
  late BoardProjects projects;
  late BoardSocket socket;
  setUp(() {
    client = ApiClient();
    units = BoardUnits(client);
    projects = BoardProjects(client);
    socket = BoardSocket();
  });
  tearDown(() => client.close());
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    List<String> roles = const ['sales'],
    String? block,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => BoardSession(roles)),
        unitsApiProvider.overrideWithValue(units),
        projectsApiProvider.overrideWithValue(projects),
        inventorySocketProvider('p').overrideWithValue(socket),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              BoardScreen(projectId: 'p', name: 'Dự án A', blockId: block),
        ),
        GoRoute(
          path: '/can/:id',
          builder: (_, state) => Text('Unit ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/bien-dong/:id',
          builder: (_, _) => const Text('History target'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'refresh starts units and stack while blocks are pending and tolerates failure',
    (tester) async {
      projects.blocks = [const Block(id: 'b', name: 'Block')];
      units.stackError = const ApiError(422, 'grid_too_large', 'large');
      await mount(tester);
      final pending = Completer<List<Block>>();
      projects.pendingBlocks = pending.future;
      final refresh = tester.widget<Screen>(find.byType(Screen)).onRefresh!();
      final completed = expectLater(refresh, completes);
      await tester.pump();
      final reads = units.reads;
      final stackReads = units.stackReads;
      pending.completeError(const ApiError(403, 'forbidden', 'forbidden'));
      await tester.pumpAndSettle();
      await completed;
      expect(reads, 2);
      expect(stackReads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flat board patch and reload update inventory without refetching blocks',
    (tester) async {
      await mount(tester);
      expect(find.text('A-12.05'), findsOneWidget);
      expect(find.textContaining('50.5 m²'), findsOneWidget);
      socket.handlers!.onSnapshot(null);
      await tester.pump();
      expect(find.text('Đang cập nhật trực tiếp'), findsOneWidget);
      socket.handlers!.onUnit(
        UnitPatch(unitId: 'u1', status: 'sold', version: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã bán'), findsOneWidget);
      expect(units.reads, 1);
      units.units = [
        ...units.units,
        const Unit(id: 'u2', code: 'B-01', status: 'available'),
      ];
      socket.handlers!.onReload();
      await tester.pumpAndSettle();
      expect(find.text('B-01'), findsOneWidget);
      expect(find.text('Đã bán'), findsNothing);
      expect(units.reads, 2);
      expect(projects.reads, 1);
      await tester.tap(find.text('B-01'));
      await tester.pumpAndSettle();
      expect(find.text('Unit u2'), findsOneWidget);
    },
  );
  testWidgets(
    'snapshot patches grid, hidden removes cell, reload refreshes only stack',
    (tester) async {
      projects.blocks = [const Block(id: 'b', name: 'Toà A')];
      await mount(tester);
      socket.handlers!.onSnapshot([
        UnitPatch(unitId: 'u1', status: 'sold', version: 2),
      ]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StackGrid>(find.byType(StackGrid))
            .plan
            .floors
            .single
            .cells
            .single
            .status,
        'sold',
      );
      expect(units.stackReads, 1);
      expect(units.reads, 0);
      socket.handlers!.onUnit(
        UnitPatch(unitId: 'u1', status: 'hidden', version: 3),
      );
      await tester.pumpAndSettle();
      expect(find.text('A-12.05'), findsNothing);
      socket.handlers!.onReload();
      await tester.pumpAndSettle();
      expect(units.stackReads, 2);
      expect(projects.reads, 1);
      expect(
        tester
            .widget<StackGrid>(find.byType(StackGrid))
            .plan
            .floors
            .single
            .cells
            .single
            .status,
        'available',
      );
    },
  );
  testWidgets('grid_too_large falls back to selected block list and filters', (
    tester,
  ) async {
    projects.blocks = [const Block(id: 'b', name: 'Toà A')];
    units.stackError = const ApiError(422, 'grid_too_large', 'large');
    await mount(tester);
    expect(
      find.text('Toà này quá nhiều căn để vẽ lưới — hiển thị dạng danh sách.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'not-found');
    await tester.pumpAndSettle();
    expect(find.text('Không có căn nào khớp bộ lọc.'), findsOneWidget);
  });
  testWidgets('export 403 shown and never retried', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Xuất Excel'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Không tải được file Excel: Bạn không có quyền thực hiện thao tác này',
      ),
      findsOneWidget,
    );
    expect(units.downloads, 1);
  });
  testWidgets('free sales cannot export; empty state; history navigation', (
    tester,
  ) async {
    units.units = [];
    await mount(tester, roles: ['sales_free']);
    expect(find.text('Xuất Excel'), findsNothing);
    expect(find.text('Không có căn nào khớp bộ lọc.'), findsOneWidget);
    await tester.tap(find.text('Biến động'));
    await tester.pumpAndSettle();
    expect(find.text('History target'), findsOneWidget);
  });
  testWidgets(
    'background leaves, resume rejoins, sign-out clears realtime data',
    (tester) async {
      final container = await mount(tester);
      socket.handlers!.onUnit(
        UnitPatch(unitId: 'u1', status: 'sold', version: 2),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(socket.leaves, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(socket.joins, 2);
      (container.read(sessionProvider.notifier) as BoardSession).endSession();
      await tester.pumpAndSettle();
      expect(container.read(inventoryChannelProvider('p')).patches, isEmpty);
      expect(socket.handlers, isNull);
    },
  );
}
