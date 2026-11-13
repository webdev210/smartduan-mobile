import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/realtime/socket.dart';

import 'fakes.dart';
import 'socket_test.dart' show FakeSocket;

void main() {
  for (final manual in [false, true]) {
    testWidgets(
      '${manual ? 'refresh' : 'reload'} clears old patches and accepts later versions',
      (tester) async {
        final socket = BoardSocket();
        final container = ProviderContainer.test(
          overrides: [
            sessionProvider.overrideWith(BoardSession.new),
            inventorySocketProvider('p').overrideWithValue(socket),
          ],
        );
        final provider = inventoryChannelProvider('p');
        container.listen(provider, (_, _) {});
        await tester.pump();
        socket.handlers!.onSnapshot(null);
        socket.handlers!.onUnit(
          UnitPatch(unitId: 'u1', status: 'sold', version: 9),
        );
        if (manual) {
          container.read(provider.notifier).refresh();
        } else {
          socket.handlers!.onReload();
        }
        expect(container.read(provider).patches, isEmpty);
        expect(container.read(provider).revision, 1);
        socket.handlers!.onUnit(
          UnitPatch(unitId: 'u1', status: 'reserved', version: 10),
        );
        socket.handlers!.onUnit(
          UnitPatch(unitId: 'u1', status: 'sold', version: 9),
        );
        expect(container.read(provider).patches['u1']!.status, 'reserved');
      },
    );
  }
  testWidgets(
    'resume after sign-out never requests a ticket or reports an error',
    (tester) async {
      var tickets = 0;
      final socket = InventorySocket(
        fetchTicket: () async => 'ticket-${++tickets}',
        createSocket: (url, opts) => FakeSocket(url, opts),
      );
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(BoardSession.new),
          inventorySocketProvider('p').overrideWithValue(socket),
        ],
      );
      final provider = inventoryChannelProvider('p');
      container.listen(provider, (_, _) {});
      await tester.pump();
      final notifier = container.read(provider.notifier);
      (container.read(sessionProvider.notifier) as BoardSession).endSession();
      expect(container.read(provider).live, isFalse);
      await tester.pump();
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 1));
      expect(tickets, 1);
      expect(container.read(provider).error, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final resume in [false, true]) {
    testWidgets(
      'offline provider recovers and resets backoff on ${resume ? 'resume' : 'refresh'}',
      (tester) async {
        var tickets = 0;
        var offline = true;
        late FakeSocket transport;
        final socket = InventorySocket(
          fetchTicket: () async {
            tickets++;
            if (offline) throw const ApiError(0, 'offline', 'offline');
            return 'ticket-$tickets';
          },
          createSocket: (url, opts) => transport = FakeSocket(url, opts),
        );
        final container = ProviderContainer.test(
          overrides: [
            sessionProvider.overrideWith(BoardSession.new),
            inventorySocketProvider('p').overrideWithValue(socket),
          ],
        );
        final provider = inventoryChannelProvider('p');
        container.listen(provider, (_, _) {});
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 2));
        expect(tickets, 3);
        expect(container.read(provider).live, isFalse);
        final notifier = container.read(provider.notifier);
        if (resume) {
          notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
          notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        } else {
          notifier.refresh();
        }
        await tester.pump();
        expect(tickets, 4);
        await tester.pump(const Duration(milliseconds: 999));
        expect(tickets, 4);
        offline = false;
        await tester.pump(const Duration(milliseconds: 1));
        expect(tickets, 5);
        transport.joined.single.joinPush.reply('ok');
        expect(container.read(provider).live, isTrue);
        await tester.pump(const Duration(seconds: 15));
        expect(tickets, 5);
      },
    );
  }

  for (final fail in [false, true]) {
    testWidgets(
      'widget disposal during ticket request ignores late ${fail ? 'failure' : 'success'}',
      (tester) async {
        var creates = 0;
        final ticket = Completer<String>();
        final socket = InventorySocket(
          fetchTicket: () => ticket.future,
          createSocket: (url, opts) {
            creates++;
            return FakeSocket(url, opts);
          },
        );
        final container = ProviderContainer(
          overrides: [
            sessionProvider.overrideWith(BoardSession.new),
            inventorySocketProvider('p').overrideWithValue(socket),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (_, ref, _) {
                ref.watch(inventoryChannelProvider('p'));
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
        if (fail) {
          ticket.completeError(const ApiError(0, 'offline', 'offline'));
        } else {
          ticket.complete('late-ticket');
        }
        await tester.pump(const Duration(minutes: 1));
        expect(creates, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
