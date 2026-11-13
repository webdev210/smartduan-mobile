import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/accounts.dart';
import 'package:smartduan/api/devices.dart';
import 'package:smartduan/api/reports.dart';
import 'package:smartduan/api/me.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

class TestSession extends Session {
  @override
  SessionState build() =>
      const SessionState(SessionStatus.signedIn, me: {'id': 'A'});
  void change(SessionStatus status, [String id = 'B']) =>
      state = SessionState(status, me: {'id': id});
}

void main() {
  test('all new query trees discard data on account change and block guest requests', () async {
    final session = TestSession();
    var identity = 'A';
    final http = FakeHttp(
      (r) => Reply(200, switch (r.path) {
        '/sales/profile' => {'id': identity},
        '/users' ||
        '/admin/devices' ||
        '/me/devices' ||
        '/sales/profile/downloads' => {
          'data': [
            {'id': identity},
          ],
        },
        '/reports/inventory' => {
          'data': [
            {'project_id': identity},
          ],
        },
        _ => throw StateError('Unexpected endpoint'),
      }),
    );
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('test', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => session),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    final profile = container.listen(fetchProfileProvider, (_, _) {});
    final downloads = container.listen(fetchDownloadsProvider, (_, _) {});
    final devices = container.listen(fetchDevicesProvider, (_, _) {});
    final users = container.listen(
      listUsersProvider((status: '', f2: false, q: '')),
      (_, _) {},
    );
    final adminDevices = container.listen(
      listDevicesProvider((status: 'pending', q: '')),
      (_, _) {},
    );
    final inventory = container.listen(fetchInventoryReportProvider, (_, _) {});
    Future<void> settle() async {
      await Future.wait([
        container.read(fetchProfileProvider.future),
        container.read(fetchDownloadsProvider.future),
        container.read(fetchDevicesProvider.future),
        container.read(
          listUsersProvider((status: '', f2: false, q: '')).future,
        ),
        container.read(listDevicesProvider((status: 'pending', q: '')).future),
        container.read(fetchInventoryReportProvider.future),
      ]);
    }

    await settle();
    expect(profile.read().requireValue.id, 'A');
    identity = 'B';
    session.change(SessionStatus.signedIn);
    await container.pump();
    await settle();
    expect(profile.read().requireValue.id, 'B');
    expect(downloads.read().requireValue.single.id, 'B');
    expect(devices.read().requireValue.single.id, 'B');
    expect(users.read().requireValue.single.id, 'B');
    expect(adminDevices.read().requireValue.single.id, 'B');
    expect(inventory.read().requireValue.single.projectId, 'B');
    expect(http.seen, hasLength(12));
    session.change(SessionStatus.guest);
    await container.pump();
    expect(profile.read().value, isNull);
    expect(downloads.read().value, isNull);
    expect(devices.read().value, isNull);
    expect(users.read().value, isNull);
    expect(adminDevices.read().value, isNull);
    expect(inventory.read().value, isNull);
    expect(http.seen, hasLength(12));
  });
  test('watching every new command never writes; invoking a failed command never retries', () async {
    final http = FakeHttp((_) => const Reply(503, {'error': 'server_error'}));
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('test', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(TestSession.new),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    container.listen(approveUserProvider, (_, _) {});
    container.listen(rejectUserProvider, (_, _) {});
    container.listen(lockUserProvider, (_, _) {});
    container.listen(unlockUserProvider, (_, _) {});
    container.listen(updateDeviceProvider, (_, _) {});
    container.listen(removeDeviceProvider, (_, _) {});
    container.listen(saveInterestsProvider, (_, _) {});
    container.listen(saveProjectsProvider, (_, _) {});
    container.listen(unsaveProjectProvider, (_, _) {});
    container.listen(submitSurveyProvider, (_, _) {});
    await container.pump();
    expect(http.seen, isEmpty);
    final calls = <Future<Object?> Function()>[
      () => container.read(approveUserProvider)(AdminUser(id: 'u')),
      () => container.read(rejectUserProvider)(AdminUser(id: 'u'), 'Lý do'),
      () => container.read(lockUserProvider)('u'),
      () => container.read(unlockUserProvider)('u'),
      () => container.read(updateDeviceProvider)('d', 'reject', {
        'reason': 'Lý do',
      }),
      () => container.read(removeDeviceProvider)('d'),
      () => container.read(saveInterestsProvider)(Interests()),
      () => container.read(saveProjectsProvider)(['p']),
      () => container.read(unsaveProjectProvider)('p'),
      () => container.read(submitSurveyProvider)({'dismissed': true}),
    ];
    for (final call in calls) {
      final before = http.seen.length;
      await caught(call());
      await container.pump();
      expect(http.seen.length, before + 1);
    }
  });
}
