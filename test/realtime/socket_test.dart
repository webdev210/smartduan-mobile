import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/auth.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/realtime/socket.dart';

import '../api/fake_http.dart';
import '../auth/token_store_test.dart' show MemoryStorage;

class FakePush implements Push {
  final replies = <String, ReceiverCallback>{};
  @override
  void onReply(String status, ReceiverCallback callback) =>
      replies[status] = callback;
  void reply(String status, [Object? value]) =>
      replies[status]?.call(PushResponse(status: status, response: value));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChannel implements PhoenixChannel {
  FakeChannel(this.topic);
  @override
  final String topic;
  final events = StreamController<Message>.broadcast();
  final joinPush = FakePush();
  bool left = false;
  @override
  Stream<Message> get messages => events.stream;
  @override
  Push join([Duration? timeout]) => joinPush;
  @override
  Push leave({Duration? timeout}) {
    left = true;
    return joinPush;
  }

  @override
  void close() {
    if (!events.isClosed) events.close();
  }

  void event(String name, Map<String, dynamic> payload) => events.add(
    Message(event: PhoenixChannelEvent.custom(name), payload: payload),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSocket implements PhoenixSocket {
  FakeSocket(this.endpoint, this.options);
  @override
  final String endpoint;
  final PhoenixSocketOptions options;
  final errors = StreamController<PhoenixSocketErrorEvent>.broadcast(
    sync: true,
  );
  final closes = StreamController<PhoenixSocketCloseEvent>.broadcast(
    sync: true,
  );
  final joined = <FakeChannel>[];
  Map<String, String>? params;
  bool disposed = false;
  bool failConnect = false;
  @override
  bool isConnected = false;
  @override
  Stream<PhoenixSocketErrorEvent> get errorStream => errors.stream;
  @override
  Stream<PhoenixSocketCloseEvent> get closeStream => closes.stream;
  @override
  Future<PhoenixSocket?> connect() async {
    params = await options.getParams();
    isConnected = !failConnect;
    return this;
  }

  @override
  PhoenixChannel addChannel({
    required String topic,
    Map<String, dynamic>? parameters,
    Duration? timeout,
  }) {
    final channel = FakeChannel(topic);
    joined.add(channel);
    return channel;
  }

  @override
  void dispose() {
    disposed = true;
    isConnected = false;
  }

  void fail() => errors.add(const PhoenixSocketErrorEvent());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProjectHandlers handlers({
  void Function(List<UnitPatch>?)? snapshot,
  void Function(UnitPatch)? unit,
  void Function()? reload,
  void Function(Object)? error,
  void Function()? disconnected,
}) => ProjectHandlers(
  onSnapshot: snapshot ?? (_) {},
  onUnit: unit ?? (_) {},
  onReload: reload ?? () {},
  onError: error ?? (_) {},
  onDisconnected: disconnected ?? () {},
);

void main() {
  for (final joinError in [false, true]) {
    testWidgets(
      'channel ${joinError ? 'join error' : 'phx_error'} retries with fresh tickets and stops on 401',
      (tester) async {
        var tickets = 0;
        final transports = <FakeSocket>[];
        final errors = <Object>[];
        final socket = InventorySocket(
          fetchTicket: () async {
            tickets++;
            if (tickets == 3) throw const ApiError(401, 'expired', 'expired');
            return 'ticket-$tickets';
          },
          createSocket: (url, opts) {
            final transport = FakeSocket(url, opts);
            transports.add(transport);
            return transport;
          },
        );
        addTearDown(socket.disconnect);
        await socket.joinProject('p', handlers(error: errors.add));
        for (var attempt = 0; attempt < 2; attempt++) {
          final transport = transports[attempt];
          final channel = transport.joined.single;
          if (joinError) {
            channel.joinPush.reply('error');
          } else {
            channel.joinPush.reply('ok');
            channel.event('phx_error', {});
            await tester.pump();
          }
          expect(errors, hasLength(attempt + 1));
          expect(transport.disposed, isTrue);
          await tester.pump(const Duration(milliseconds: 999));
          expect(tickets, attempt + 1);
          await tester.pump(const Duration(milliseconds: 1));
          expect(tickets, attempt + 2);
        }
        expect(transports.map((s) => s.params!['token']), [
          'ticket-1',
          'ticket-2',
        ]);
        await tester.pump(const Duration(minutes: 1));
        expect(tickets, 3);
        expect(errors.last, isA<ApiError>());
      },
    );
  }
  testWidgets(
    'failed transport attempts follow every backoff interval with fresh tickets',
    (tester) async {
      var tickets = 0;
      final socket = InventorySocket(
        fetchTicket: () async => 'ticket-${++tickets}',
        createSocket: (url, opts) => FakeSocket(url, opts)..failConnect = true,
      );
      await socket.joinProject('p', handlers());
      for (final delay in [1000, 2000, 5000, 10000, 15000, 15000]) {
        final before = tickets;
        await tester.pump(Duration(milliseconds: delay - 1));
        expect(tickets, before);
        await tester.pump(const Duration(milliseconds: 1));
        expect(tickets, before + 1);
      }
      socket.disconnect();
    },
  );
  test(
    'ws ticket 401 runs normal session-end path and clears secure token',
    () async {
      final tokens = SecureValue('sd_session', storage: MemoryStorage());
      await tokens.set('session-token');
      final http = FakeHttp((_) => const Reply(401, {'error': 'unauthorized'}));
      final client = ApiClient(
        tokens: tokens,
        adapter: http,
        revokedAdapter: FakeHttp(
          (_) => const Reply(200, {'reason': 'expired'}),
        ),
      );
      addTearDown(client.close);
      final ended = <String>[];
      client.onSessionEnded = ended.add;
      final auth = AuthApi(client);
      final socket = InventorySocket(
        fetchTicket: () async => (await auth.wsToken())['token'] as String,
      );
      await socket.joinProject('p', handlers());
      expect(http.seen.single.path, '/auth/ws-token');
      expect(http.seen.single.method, 'POST');
      expect(await tokens.get(), isNull);
      expect(ended, ['expired']);
      socket.disconnect();
    },
  );
  test('RN backoff table caps at 15 seconds', () {
    expect([1, 2, 3, 4, 5, 50].map(reconnectAfterMs), [
      1000,
      2000,
      5000,
      10000,
      15000,
      15000,
    ]);
    expect(
      socketEndpoint('wss://host/m/socket'),
      'wss://host/m/socket/websocket',
    );
    expect(
      socketEndpoint('wss://host/m/socket/websocket'),
      'wss://host/m/socket/websocket',
    );
  });
  testWidgets(
    'ticket per connect and reconnect; one error listener; sign-out stops retry',
    (tester) async {
      var tickets = 0;
      final sockets = <FakeSocket>[];
      final socket = InventorySocket(
        fetchTicket: () async => 'ticket-${++tickets}',
        createSocket: (url, options) {
          final s = FakeSocket(url, options);
          sockets.add(s);
          return s;
        },
      );
      await socket.joinProject('p1', handlers());
      expect(sockets.single.params!['token'], 'ticket-1');
      expect(sockets.single.errors.hasListener, isTrue);
      sockets.first.fail();
      await tester.pump(const Duration(milliseconds: 999));
      expect(tickets, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tickets, 2);
      expect(sockets.last.params!['token'], 'ticket-2');
      socket.disconnect();
      sockets.last.fail();
      await tester.pump(const Duration(seconds: 30));
      expect(tickets, 2);
    },
  );
  test('join topic, snapshot omission, patch, reload and join error', () async {
    late FakeSocket transport;
    final snapshots = <List<UnitPatch>?>[],
        patches = <UnitPatch>[],
        errors = <Object>[];
    var reloads = 0;
    final socket = InventorySocket(
      fetchTicket: () async => 'ticket',
      createSocket: (url, options) => transport = FakeSocket(url, options),
    );
    await socket.joinProject(
      'p1',
      handlers(
        snapshot: snapshots.add,
        unit: patches.add,
        reload: () => reloads++,
        error: errors.add,
      ),
    );
    final channel = transport.joined.single;
    expect(channel.topic, 'inventory:project:p1');
    final patch = {'unit_id': 'u1', 'status': 'sold', 'version': 2};
    channel.joinPush.reply('ok', {
      'units': [patch],
    });
    channel.joinPush.reply('ok', <String, dynamic>{});
    channel.event('unit_status_changed', patch);
    channel.event('inventory_reloaded', {'reason': 'snapshot_too_large'});
    await Future<void>.delayed(Duration.zero);
    channel.joinPush.reply('error', {'reason': 'forbidden'});
    expect(snapshots.first!.single.unitId, 'u1');
    expect(snapshots.last, isNull);
    expect(patches.single.status, 'sold');
    expect(reloads, 1);
    expect(errors, hasLength(1));
    socket.disconnect();
    expect(transport.disposed, isTrue);
  });
  test('sign-out during ticket request never opens a socket', () async {
    final ticket = Completer<String>();
    var creates = 0;
    final socket = InventorySocket(
      fetchTicket: () => ticket.future,
      createSocket: (url, opts) {
        creates++;
        return FakeSocket(url, opts);
      },
    );
    final pending = socket.joinProject('p', handlers());
    socket.disconnect();
    ticket.complete('late-ticket');
    await pending;
    expect(creates, 0);
  });
  testWidgets('401 and permanent ticket failures surface and stop', (
    tester,
  ) async {
    for (final status in [401, 403, 404]) {
      var calls = 0;
      final errors = <Object>[];
      final socket = InventorySocket(
        fetchTicket: () async {
          calls++;
          throw ApiError(status, 'unauthorized', 'expired');
        },
      );
      await socket.joinProject('p', handlers(error: errors.add));
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 1);
      expect(
        errors.single,
        isA<ApiError>().having((e) => e.status, 'status', status),
      );
      socket.disconnect();
    }
  });
  for (final status in [0, 500, 503, 599]) {
    testWidgets('ticket $status retries the backoff table and recovers', (
      tester,
    ) async {
      var tickets = 0, disconnected = 0, snapshots = 0;
      var online = false;
      final transports = <FakeSocket>[];
      final socket = InventorySocket(
        fetchTicket: () async {
          tickets++;
          if (!online) throw ApiError(status, 'unavailable', 'unavailable');
          return 'ticket-$tickets';
        },
        createSocket: (url, opts) {
          final transport = FakeSocket(url, opts);
          transports.add(transport);
          return transport;
        },
      );
      addTearDown(socket.disconnect);
      await socket.joinProject(
        'p',
        handlers(
          disconnected: () => disconnected++,
          snapshot: (_) => snapshots++,
        ),
      );
      for (final delay in [1000, 2000, 5000, 10000, 15000, 15000]) {
        final before = tickets;
        await tester.pump(Duration(milliseconds: delay - 1));
        expect(tickets, before);
        await tester.pump(const Duration(milliseconds: 1));
        expect(tickets, before + 1);
      }
      expect(disconnected, tickets);
      expect(transports, isEmpty);
      online = true;
      await tester.pump(const Duration(seconds: 15));
      expect(tickets, 8);
      expect(transports.single.params!['token'], 'ticket-8');
      transports.single.joined.single.joinPush.reply('ok');
      expect(snapshots, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(tickets, 8);
    });
  }
  for (final retryAfter in [0.25, 7.5]) {
    testWidgets('429 waits for backoff and Retry-After $retryAfter', (
      tester,
    ) async {
      var tickets = 0;
      final socket = InventorySocket(
        fetchTicket: () async {
          tickets++;
          throw ApiError(429, 'limited', 'limited', retryAfter: retryAfter);
        },
      );
      addTearDown(socket.disconnect);
      await socket.joinProject('p', handlers());
      final delay = retryAfter == 0.25 ? 1000 : 7500;
      await tester.pump(Duration(milliseconds: delay - 1));
      expect(tickets, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tickets, 2);
    });
  }
}
