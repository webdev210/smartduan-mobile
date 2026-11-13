import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/api/sales.dart';
import 'package:smartduan/api/content.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

class TestSession extends Session {
  @override
  SessionState build() => const SessionState(SessionStatus.signedIn);
  void change(SessionStatus status) => state = SessionState(status);
}

void main() {
  test(
    'a late old-account response cannot replace the new account query',
    () async {
      final old = Completer<Reply>();
      var calls = 0;
      final http = FakeHttp(
        (_) => ++calls == 1
            ? old.future
            : const Reply(200, {'data': <Object?>[], 'unread': 2}),
      );
      final session = TestSession();
      final client = ApiClient(
        adapter: http,
        tokens: SecureValue('late', storage: MemoryStorage()),
      );
      addTearDown(client.close);
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          sessionProvider.overrideWith(() => session),
          apiClientProvider.overrideWithValue(client),
        ],
      );
      final sub = container.listen(fetchNotificationsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      session.change(SessionStatus.signedIn);
      await container.pump();
      expect(
        (await container.read(fetchNotificationsProvider.future)).unread,
        2,
      );
      old.complete(const Reply(200, {'data': <Object?>[], 'unread': 99}));
      await container.pump();
      expect(sub.read().value?.unread, 2);
    },
  );
  test('all four API provider trees drop private data on sign-out and refetch on sign-in', () async {
    final session = TestSession();
    final http = FakeHttp(
      (_) => const Reply(200, {'data': <Object?>[], 'unread': 4}),
    );
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('providers', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => session),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    final projects = container.listen(fetchAllProjectsProvider, (_, _) {});
    final units = container.listen(fetchEnumsProvider, (_, _) {});
    final sales = container.listen(fetchNotificationsProvider, (_, _) {});
    final content = container.listen(fetchFaqsProvider('p'), (_, _) {});
    await Future.wait([
      container.read(fetchAllProjectsProvider.future),
      container.read(fetchEnumsProvider.future),
      container.read(fetchNotificationsProvider.future),
      container.read(fetchFaqsProvider('p').future),
    ]);
    expect(sales.read().value?.unread, 4);
    expect(http.seen, hasLength(4));
    session.change(SessionStatus.guest);
    await container.pump();
    expect(projects.read().hasError, isTrue);
    expect(units.read().hasError, isTrue);
    expect(sales.read().hasError, isTrue);
    expect(content.read().hasError, isTrue);
    expect(sales.read().value, isNull);
    expect(http.seen, hasLength(4));
    session.change(SessionStatus.signedIn);
    await container.pump();
    await container.read(fetchNotificationsProvider.future);
    expect(sales.read().value?.unread, 4);
    expect(http.seen, hasLength(8));
  });
  test('watching command providers never sends or retries a write', () async {
    final http = FakeHttp(
      (_) => const Reply(503, {'error': 'lead_delivery_unknown'}),
    );
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('commands', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(TestSession.new),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    container.listen(submitConsultProvider, (_, _) {});
    container.listen(documentDownloadUrlProvider, (_, _) {});
    container.listen(createShareLinkProvider, (_, _) {});
    await container.pump();
    expect(http.seen, isEmpty);
    final error = await caught(
      container.read(submitConsultProvider)({'consent': true}),
    );
    expect(error.code, 'lead_delivery_unknown');
    await container.pump();
    expect(http.seen, hasLength(1));
  });
}
