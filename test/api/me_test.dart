import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/me.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/auth/session.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

class TestSession extends Session {
  @override
  SessionState build() =>
      const SessionState(SessionStatus.signedIn, me: {'id': 'A'});
  void change(SessionState next) => state = next;
}

void main() {
  test(
    'profile downloads devices interests and survey match RN paths and verbs',
    () async {
      final http = FakeHttp(
        (c) => Reply(200, switch (c.path) {
          '/sales/profile' => {'id': 'p'},
          '/sales/profile/downloads' || '/me/devices' => {'data': <Object?>[]},
          '/sales/interests' => {
            'region': 'nam',
            'interested_project_ids': ['p'],
          },
          '/sales/survey' =>
            c.method == 'GET'
                ? {
                    'data': {'due': true},
                  }
                : {
                    'data': {'submitted': true},
                  },
          '/me/devices/d1' => <String, Object?>{},
          _ => throw StateError('Unexpected endpoint'),
        }),
      );
      final client = ApiClient(
        tokens: SecureValue('test', storage: MemoryStorage()),
        adapter: http,
      );
      addTearDown(client.close);
      final api = MeApi(client);
      expect((await api.fetchProfile()).id, 'p');
      expect(await api.fetchDownloads(), isEmpty);
      expect(await api.fetchDevices(), isEmpty);
      await api.removeDevice('d1');
      expect(http.seen.last.method, 'DELETE');
      expect(
        (await api.saveInterests(
          Interests.fromJson({
            'region': 'nam',
            'interested_project_ids': ['p'],
          }),
        )).toJson(),
        {
          'region': 'nam',
          'interested_project_ids': ['p'],
        },
      );
      expect(http.seen.last.method, 'PUT');
      expect(await api.getSurveyDue(), true);
      await api.submitSurvey({
        'ease_score': 5,
        'would_refer': true,
        'missing_text': 'Không',
      });
      expect(http.seen.last.data, {
        'ease_score': 5,
        'would_refer': true,
        'missing_text': 'Không',
      });
      expect(http.seen.last.method, 'POST');
      expect(await api.submitSurvey({'dismissed': true}), {
        'data': {'submitted': true},
      });
      expect(http.seen.last.data, {'dismissed': true});
    },
  );
  test(
    'saved-project provider discards previous account data on session changes',
    () async {
      var code = 'A';
      final http = FakeHttp(
        (_) => Reply(200, {
          'codes': [code],
        }),
      );
      final client = ApiClient(
        tokens: SecureValue('test', storage: MemoryStorage()),
        adapter: http,
      );
      addTearDown(client.close);
      final session = TestSession();
      final container = ProviderContainer.test(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          sessionProvider.overrideWith(() => session),
        ],
      );
      final sub = container.listen(fetchSavedProjectsProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(fetchSavedProjectsProvider.future), ['A']);
      code = 'B';
      session.change(
        const SessionState(SessionStatus.signedIn, me: {'id': 'B'}),
      );
      expect(await container.read(fetchSavedProjectsProvider.future), ['B']);
      expect(http.seen.length, 2);
      expect(
        () => container.read(fetchSavedProjectsProvider).requireValue.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('read, append, delete saved code in body return new codes', () async {
    final http = FakeHttp(
      (_) => const Reply(200, {
        'codes': ['SKY'],
      }),
    );
    final client = ApiClient(
      tokens: SecureValue('test', storage: MemoryStorage()),
      adapter: http,
    );
    addTearDown(client.close);
    final api = MeApi(client);
    expect(await api.fetchSavedProjects(), ['SKY']);
    expect(await api.saveProjects(['SKY']), ['SKY']);
    expect(await api.unsaveProject('OLD'), ['SKY']);
    expect(http.seen.map((c) => c.method), ['GET', 'POST', 'DELETE']);
    expect(http.seen.every((c) => c.path == '/me/saved-projects'), true);
    expect(http.seen[1].data, {
      'codes': ['SKY'],
    });
    expect(http.seen[2].data, {'code': 'OLD'});
  });
  test('full saved list preserves backend message', () async {
    final http = FakeHttp(
      (_) => const Reply(422, {
        'error': 'saved_projects_full',
        'message': 'Bạn đã lưu tối đa 50 dự án. Bỏ lưu một dự án rồi thử lại.',
      }),
    );
    final client = ApiClient(
      tokens: SecureValue('test', storage: MemoryStorage()),
      adapter: http,
    );
    addTearDown(client.close);
    expect(
      errorMessage(await caught(MeApi(client).saveProjects(['X']))),
      'Bạn đã lưu tối đa 50 dự án. Bỏ lưu một dự án rồi thử lại.',
    );
  });
}
