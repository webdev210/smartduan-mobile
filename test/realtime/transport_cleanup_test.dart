import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:smartduan/realtime/socket.dart';

import 'socket_test.dart' show handlers;

// Keep real Phoenix channels and pushes; replace only network I/O.
class LocalTransport extends PhoenixSocket {
  LocalTransport() : super('ws://localhost/socket/websocket');
  bool disposed = false;
  @override
  bool get isConnected => !disposed;
  @override
  Future<PhoenixSocket?> connect() async => this;
  @override
  Future<Message> sendMessage(Message message) async {
    await Future<void>.delayed(Duration.zero);
    if (disposed) throw PhoenixException();
    if (message.event == PhoenixChannelEvent.join) {
      channels[message.topic]?.trigger(
        Message(
          event: PhoenixChannelEvent.reply,
          topic: message.topic,
          ref: message.ref,
          joinRef: message.joinRef,
          payload: {'status': 'ok', 'response': <String, dynamic>{}},
        ),
      );
    }
    return message;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  for (final reconnect in [false, true]) {
    test(
      'joined transport cleanup has no uncaught error (reconnect: $reconnect)',
      () async {
        final errors = <Object>[];
        await runZonedGuarded(() async {
          final joined = Completer<void>();
          final socket = InventorySocket(
            fetchTicket: () async => 'ticket',
            createSocket: (_, _) => LocalTransport(),
          );
          await socket.joinProject(
            'p',
            handlers(snapshot: (_) => joined.complete()),
          );
          await joined.future;
          if (reconnect) await socket.joinProject('p', handlers());
          socket.disconnect();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }, (error, _) => errors.add(error));
        expect(errors, isEmpty);
      },
    );
  }
}
