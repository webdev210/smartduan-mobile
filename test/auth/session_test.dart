import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/auth.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/main.dart' as app;

import '../api/fake_http.dart';
import 'token_store_test.dart' show MemoryStorage, jwt;

Future<SessionState> untilState(
  ProviderContainer container,
  SessionStatus status,
) async {
  final done = Completer<SessionState>();
  final sub = container.listen(sessionProvider, (_, next) {
    if (next.status == status && !done.isCompleted) done.complete(next);
  }, fireImmediately: true);
  try {
    return await done.future.timeout(const Duration(seconds: 3));
  } finally {
    sub.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStorage storage;
  late SecureValue tokens;
  late FakeHttp http;
  late FakeHttp revoked;
  late ApiClient client;
  late ProviderContainer container;
  setUp(() {
    storage = MemoryStorage();
    tokens = SecureValue('sd_session', storage: storage);
    http = FakeHttp(
      (_) => const Reply(200, {
        'id': 'u',
        'roles': ['agent'],
      }),
    );
    revoked = FakeHttp((_) => const Reply(200, {'reason': 'locked'}));
    client = ApiClient(tokens: tokens, adapter: http, revokedAdapter: revoked);
    container = ProviderContainer(
      overrides: [authApiProvider.overrideWithValue(AuthApi(client))],
    );
  });
  tearDown(() {
    container.dispose();
    client.close();
  });

  for (final boundary in ['signOut+signIn', 'signIn', 'local end']) {
    test('late 401 cannot end session after $boundary', () async {
      await tokens.set('A');
      await untilState(container, SessionStatus.signedIn);
      final notifier = container.read(sessionProvider.notifier);
      final started = Completer<void>();
      final response = Completer<Reply>();
      http.respond = (r) {
        if (r.path == '/projects') {
          started.complete();
          return response.future;
        }
        return const Reply(200, {
          'id': 'B',
          'roles': ['manager'],
        });
      };
      final pending = caught(client.get('/projects'));
      await started.future;
      if (boundary == 'signOut+signIn') await notifier.signOut();
      if (boundary == 'local end') await client.endSessionLocally('expired');
      await notifier.signIn('B');
      final ended = <String>[];
      client.onSessionEnded = ended.add;
      response.complete(const Reply(401));
      expect((await pending).status, 401);
      expect(await tokens.get(), 'B');
      expect(ended, isEmpty);
      expect(revoked.seen, isEmpty);
      expect(container.read(sessionProvider).me?['id'], 'B');
    });
  }
  test(
    'new sign-in with offline me drops previous profile and roles',
    () async {
      await tokens.set('A');
      await untilState(container, SessionStatus.signedIn);
      http.respond = (r) => throw DioException(requestOptions: r);
      await container.read(sessionProvider.notifier).signIn('B');
      final state = container.read(sessionProvider);
      expect(state.status, SessionStatus.offline);
      expect(state.me, isNull);
      expect(state.roles, isEmpty);
      expect(await tokens.get(), 'B');
    },
  );
  test('pending revocation lookup cannot clear a new sign-in', () async {
    await tokens.set('A');
    await untilState(container, SessionStatus.signedIn);
    final started = Completer<void>();
    final lookup = Completer<Reply>();
    revoked.respond = (_) {
      started.complete();
      return lookup.future;
    };
    http.respond = (_) => const Reply(401);
    final pending = caught(client.get('/projects'));
    await started.future;
    http.respond = (_) => const Reply(200, {'id': 'B'});
    await container.read(sessionProvider.notifier).signIn('B');
    final ended = <String>[];
    client.onSessionEnded = ended.add;
    lookup.complete(const Reply(200, {'reason': 'locked'}));
    await pending;
    expect(await tokens.get(), 'B');
    expect(ended, isEmpty);
  });

  test('boot without token transitions loading to guest', () async {
    expect(container.read(sessionProvider).status, SessionStatus.loading);
    final state = await untilState(container, SessionStatus.guest);
    expect(state.me, isNull);
    expect(state.roles, isEmpty);
    expect(http.seen, isEmpty);
  });
  test('boot expired token clears it without API call', () async {
    await tokens.set(jwt({'exp': 1}));
    await untilState(container, SessionStatus.guest);
    expect(await tokens.get(), isNull);
    expect(http.seen, isEmpty);
  });
  test('boot valid token loads me and roles', () async {
    await tokens.set('opaque');
    final state = await untilState(container, SessionStatus.signedIn);
    expect(state.me?['id'], 'u');
    expect(state.roles, ['agent']);
    expect(http.seen.single.path, '/me');
  });
  test('network boot is offline; retry sets loading and recovers', () async {
    await tokens.set('opaque');
    http.respond = (r) => throw DioException(requestOptions: r);
    await untilState(container, SessionStatus.offline);
    expect(await tokens.get(), 'opaque');
    http.respond = (_) => const Reply(200, {
      'roles': ['manager'],
    });
    final retry = container.read(sessionProvider.notifier).retry();
    expect(container.read(sessionProvider).status, SessionStatus.loading);
    await retry;
    expect(container.read(sessionProvider).roles, ['manager']);
  });
  test('boot backend failure is offline', () async {
    await tokens.set('opaque');
    http.respond = (_) => const Reply(503);
    await untilState(container, SessionStatus.offline);
  });
  test('401 handler makes guest and keeps ended reason', () async {
    await tokens.set('opaque');
    http.respond = (_) => const Reply(401);
    final state = await untilState(container, SessionStatus.guest);
    expect(state.endedReason, 'locked');
    expect(await tokens.get(), isNull);
  });
  test('sign in clears ended reason and sign out drops user data', () async {
    await untilState(container, SessionStatus.guest);
    final notifier = container.read(sessionProvider.notifier);
    await client.endSessionLocally('expired');
    await notifier.signIn('new');
    expect(await tokens.get(), 'new');
    expect(container.read(sessionProvider).status, SessionStatus.signedIn);
    expect(container.read(sessionProvider).endedReason, isNull);
    await notifier.signOut();
    final state = container.read(sessionProvider);
    expect(state.status, SessionStatus.guest);
    expect(state.me, isNull);
    expect(state.roles, isEmpty);
    expect(state.endedReason, isNull);
  });
  test(
    'logout everywhere clears locally even when server is offline',
    () async {
      await tokens.set('opaque');
      await untilState(container, SessionStatus.signedIn);
      http.respond = (r) => throw DioException(requestOptions: r);
      await container.read(sessionProvider.notifier).signOut(everywhere: true);
      expect(http.seen.last.path, '/auth/logout_all');
      expect(http.seen.last.method, 'POST');
      expect(await tokens.get(), isNull);
      expect(container.read(sessionProvider).endedReason, 'logout');
    },
  );
  test('refresh offline preserves me and roles', () async {
    await tokens.set('opaque');
    await untilState(container, SessionStatus.signedIn);
    http.respond = (r) => throw DioException(requestOptions: r);
    await container.read(sessionProvider.notifier).refreshMe();
    expect(container.read(sessionProvider).status, SessionStatus.offline);
    expect(container.read(sessionProvider).roles, ['agent']);
  });
  test('resume expires session locally without revoked lookup', () async {
    await tokens.set('opaque');
    await untilState(container, SessionStatus.signedIn);
    await tokens.set(jwt({'exp': 1}));
    container
        .read(sessionProvider.notifier)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    final state = await untilState(container, SessionStatus.guest);
    expect(state.endedReason, 'expired');
    expect(revoked.seen, isEmpty);
    expect(http.seen, hasLength(1));
  });
  test('resume with live token refreshes me', () async {
    await tokens.set('opaque');
    await untilState(container, SessionStatus.signedIn);
    final refreshed = Completer<void>();
    final sub = container.listen(sessionProvider, (_, next) {
      if (next.roles.contains('manager')) refreshed.complete();
    });
    http.respond = (_) => const Reply(200, {
      'roles': ['manager'],
    });
    container
        .read(sessionProvider.notifier)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await refreshed.future.timeout(const Duration(seconds: 3));
    sub.close();
    expect(container.read(sessionProvider).roles, ['manager']);
  });
  test('a late me response cannot restore a signed-out user', () async {
    await tokens.set('opaque');
    await untilState(container, SessionStatus.signedIn);
    final gate = Completer<Reply>();
    http.respond = (_) => gate.future;
    final refresh = container.read(sessionProvider.notifier).refreshMe();
    await container.read(sessionProvider.notifier).signOut();
    gate.complete(
      const Reply(200, {
        'roles': ['admin'],
      }),
    );
    await refresh;
    expect(container.read(sessionProvider).status, SessionStatus.guest);
    expect(container.read(sessionProvider).roles, isEmpty);
  });
  testWidgets('entry point wraps app with ProviderScope', (tester) async {
    await tester.runAsync(app.main);
    await tester.pump();
    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(app.MyApp), findsOneWidget);
  });
}
