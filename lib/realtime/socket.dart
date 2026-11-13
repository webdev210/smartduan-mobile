import 'dart:async';

import 'package:phoenix_socket/phoenix_socket.dart';

import '../api/errors.dart';
import '../api/models.dart';
import '../config.dart';

int reconnectAfterMs(int tries) => switch (tries) {
  1 => 1000,
  2 => 2000,
  3 => 5000,
  4 => 10000,
  _ => 15000,
};

String socketEndpoint(String url) =>
    '${url.replaceFirst(RegExp(r'/websocket/?$'), '').replaceFirst(RegExp(r'/$'), '')}/websocket';

typedef SocketFactory = PhoenixSocket Function(String, PhoenixSocketOptions);

class ProjectHandlers {
  const ProjectHandlers({
    required this.onSnapshot,
    required this.onUnit,
    required this.onReload,
    required this.onError,
    required this.onDisconnected,
  });
  final void Function(List<UnitPatch>?) onSnapshot;
  final void Function(UnitPatch) onUnit;
  final void Function() onReload, onDisconnected;
  final void Function(Object) onError;
}

/// Owns reconnects: a transport and its ticket are used for exactly one attempt.
class InventorySocket {
  InventorySocket({required this.fetchTicket, SocketFactory? createSocket})
    : createSocket =
          createSocket ??
          ((url, options) => PhoenixSocket(url, socketOptions: options));
  final Future<String> Function() fetchTicket;
  final SocketFactory createSocket;
  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _retry;
  int _generation = 0, _attempts = 0;
  bool _stopped = true;
  String? _projectId;
  ProjectHandlers? _handlers;

  Future<void> joinProject(String projectId, ProjectHandlers handlers) async {
    disconnect();
    _stopped = false;
    _projectId = projectId;
    _handlers = handlers;
    await _connect();
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    var ticketFetched = false;
    bool current() => !_stopped && generation == _generation;
    try {
      final ticket = await fetchTicket();
      if (!current()) return;
      if (ticket.isEmpty) throw const FormatException('Invalid socket ticket');
      ticketFetched = true;
      var consumed = false;
      final socket = createSocket(
        socketEndpoint(wsUrl),
        PhoenixSocketOptions(
          // The package's reconnect timer must never reuse a consumed ticket.
          dynamicParams: () async {
            if (!current() || consumed) throw StateError('Connection ended');
            consumed = true;
            return {'token': ticket};
          },
        ),
      );
      _socket = socket;
      void failed() {
        if (current()) _failed();
      }

      _subscriptions.add(socket.errorStream.listen((_) => failed()));
      _subscriptions.add(socket.closeStream.listen((_) => failed()));
      await socket.connect().timeout(const Duration(seconds: 25));
      if (!current()) return;
      if (!socket.isConnected) {
        _failed();
        return;
      }
      _attempts = 0;
      final channel = socket.addChannel(topic: 'inventory:project:$_projectId');
      _channel = channel;
      _subscriptions.add(
        channel.messages.listen((message) {
          if (!current()) return;
          try {
            switch (message.event.value) {
              case 'unit_status_changed':
                _handlers!.onUnit(
                  UnitPatch.fromJson(jsonObject(message.payload)),
                );
              case 'inventory_reloaded':
                _handlers!.onReload();
              case 'phx_error':
                _handlers!.onError(StateError('Channel error'));
                failed();
            }
          } catch (error) {
            _handlers!.onError(error);
          }
        }),
      );
      channel.join()
        ..onReply('ok', (reply) {
          if (!current()) return;
          try {
            final units = jsonObject(
              reply.response ?? <String, dynamic>{},
            )['units'];
            _handlers!.onSnapshot(
              units == null
                  ? null
                  : jsonList(
                      units,
                      (j) => UnitPatch.fromJson({
                        ...j,
                        'unit_id': j['unit_id'] ?? j['id'],
                      }),
                    ),
            );
          } catch (error) {
            _handlers!.onError(error);
          }
        })
        ..onReply('error', (_) {
          if (!current()) return;
          _handlers!.onError(StateError('Channel join failed'));
          failed();
        })
        ..onReply('timeout', (_) {
          if (current()) _failed();
        });
    } catch (error) {
      if (!current()) return;
      _handlers?.onError(error);
      if (error case ApiError(status: 401)) {
        disconnect();
        return;
      }
      // Ticket minting is safe to repeat; business writes are never retried.
      if (error case ApiError(status: 0 || 429 || >= 500 && < 600)) {
        _failed(retryAfter: error.status == 429 ? error.retryAfter : null);
        return;
      }
      if (ticketFetched) {
        _failed();
        return;
      }
      disconnect();
    }
  }

  void _failed({num? retryAfter}) {
    _generation++;
    _handlers?.onDisconnected();
    _releaseTransport();
    _retry?.cancel();
    if (!_stopped) {
      var delayMs = reconnectAfterMs(++_attempts);
      if (retryAfter != null && retryAfter.isFinite && retryAfter > 0) {
        final minimumMs = (retryAfter * 1000).ceil();
        if (minimumMs > delayMs) delayMs = minimumMs;
      }
      _retry = Timer(Duration(milliseconds: delayMs), _connect);
    }
  }

  void _releaseTransport() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    // Closing the transport leaves its channels without an outstanding push.
    _channel?.close();
    _channel = null;
    _socket?.dispose();
    _socket = null;
  }

  void disconnect() {
    _stopped = true;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _attempts = 0;
    _releaseTransport();
    _handlers = null;
    _projectId = null;
  }
}
