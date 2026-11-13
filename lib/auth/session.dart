import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/auth.dart';
import '../api/client.dart';
import '../api/errors.dart';
import 'token_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

/// Every provider holding user data must watch this provider so sign-in and
/// sign-out drop cached data (the RN app used queryClient.clear()).
final sessionProvider = NotifierProvider<Session, SessionState>(Session.new);

enum SessionStatus { loading, guest, signedIn, offline }

class SessionState {
  const SessionState(this.status, {this.me, this.endedReason});
  final SessionStatus status;
  final Map<String, dynamic>? me;
  final String? endedReason;
  List<String> get roles {
    final value = me?['roles'];
    return value is List && value.every((dynamic role) => role is String)
        ? List<String>.unmodifiable(value.cast<String>())
        : const [];
  }
}

class Session extends Notifier<SessionState> with WidgetsBindingObserver {
  late AuthApi _auth;
  int _generation = 0;

  @override
  SessionState build() {
    _auth = ref.watch(authApiProvider);
    _auth.client.onSessionEnded = _toGuest;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _generation++;
      _auth.client.onSessionEnded = null;
      WidgetsBinding.instance.removeObserver(this);
    });
    unawaited(Future<void>.microtask(_boot));
    return const SessionState(SessionStatus.loading);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  void _toGuest(String? reason) {
    _generation++;
    if (ref.mounted) {
      state = SessionState(SessionStatus.guest, endedReason: reason);
    }
  }

  Future<void> _boot() async {
    final generation = _generation;
    try {
      final token = await _auth.client.tokens.get();
      if (!_current(generation)) return;
      if (isExpired(token)) {
        if (token != null && token.isNotEmpty) {
          await _auth.client.endSessionLocally(null);
        }
        if (_current(generation)) {
          state = SessionState(
            SessionStatus.guest,
            me: state.me,
            endedReason: state.endedReason,
          );
        }
        return;
      }
      await refreshMe();
    } catch (_) {
      if (_current(generation)) {
        state = SessionState(
          SessionStatus.offline,
          me: state.me,
          endedReason: state.endedReason,
        );
      }
    }
  }

  Future<void> refreshMe() async {
    final generation = _generation;
    try {
      final me = await _auth.fetchMe();
      if (_current(generation)) {
        state = SessionState(
          SessionStatus.signedIn,
          me: Map<String, dynamic>.unmodifiable(me),
          endedReason: state.endedReason,
        );
      }
    } on ApiError catch (error) {
      if (!_current(generation) || error.status == 401) return;
      if (error.status == 0) {
        state = SessionState(
          SessionStatus.offline,
          me: state.me,
          endedReason: state.endedReason,
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> signIn(String token) async {
    _generation++;
    await _auth.client.setSessionToken(token);
    if (!ref.mounted) return;
    // A new snapshot invalidates dependent user-data providers before /me.
    state = SessionState(state.status);
    await refreshMe();
  }

  Future<void> signOut({bool everywhere = false}) async {
    _generation++;
    if (everywhere) {
      try {
        await _auth.logoutAll();
      } catch (_) {
        /* Still remove the local session. */
      }
    }
    await _auth.client.endSessionLocally(null);
    _toGuest(everywhere ? 'logout' : null);
  }

  Future<void> retry() {
    state = SessionState(
      SessionStatus.loading,
      me: state.me,
      endedReason: state.endedReason,
    );
    return _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        this.state.status == SessionStatus.signedIn) {
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    final generation = _generation;
    try {
      final token = await _auth.client.tokens.get();
      if (!_current(generation)) return;
      if (isExpired(token)) {
        await _auth.client.endSessionLocally('expired');
      } else {
        await refreshMe();
      }
    } catch (_) {
      /* Foreground refresh failures must not become unhandled errors. */
    }
  }
}
