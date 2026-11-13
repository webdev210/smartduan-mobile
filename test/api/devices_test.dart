import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/devices.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/sales.dart';
import 'package:smartduan/auth/roles.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

AdminDevice dev([Map<String, dynamic> values = const {}]) =>
    AdminDevice.fromJson({
      'id': 'd1',
      'kind': 'mobile',
      'label': 'iPhone',
      'status': 'pending',
      'user': {'id': 'u1', 'full_name': 'A', 'email': 'a@x.vn'},
      ...values,
    });

void main() {
  final now = DateTime.parse('2026-11-09T00:00:00Z');
  late FakeHttp http;
  late ApiClient client;
  late DevicesApi api;
  setUp(() {
    http = FakeHttp(
      (_) => const Reply(200, {
        'data': [
          {'id': 'd1'},
        ],
      }),
    );
    client = ApiClient(
      adapter: http,
      tokens: SecureValue('test', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    api = DevicesApi(client);
  });
  test('pending devices approve reject or change kind', () {
    expect(deviceActions(dev(), false, now), ['approve', 'reject', 'kind']);
  });
  test('approved exception only with permission', () {
    expect(deviceActions(dev({'status': 'approved'}), false, now), [
      'revoke',
      'kind',
    ]);
    expect(deviceActions(dev({'status': 'approved'}), true, now), [
      'revoke',
      'kind',
      'allow_until',
    ]);
  });
  test('revoked only reopens if rejected', () {
    expect(
      deviceActions(dev({'status': 'revoked', 'rejected': true}), true, now),
      ['reopen'],
    );
    expect(deviceActions(dev({'status': 'revoked'}), true, now), isEmpty);
  });
  test('own device only revokes; expired devices have no actions', () {
    expect(
      deviceActions(dev({'status': 'approved', 'self': true}), true, now),
      ['revoke'],
    );
    expect(
      deviceActions(
        dev({'status': 'revoked', 'self': true, 'rejected': true}),
        true,
        now,
      ),
      isEmpty,
    );
    for (final expiry in ['2026-11-08T16:59:59Z', '2026-11-09T00:00:00Z']) {
      expect(
        deviceActions(
          dev({'status': 'approved', 'expires_at': expiry}),
          true,
          now,
        ),
        isEmpty,
      );
    }
  });
  test('list omits empty filters and uses user devices endpoint', () async {
    await api.listDevices('', '  ');
    await api.listDevices('pending', ' a@x ');
    await api.listUserDevices('u1');
    expect(http.seen[0].queryParameters, isEmpty);
    expect(http.seen[1].queryParameters, {'status': 'pending', 'q': 'a@x'});
    expect(http.seen[2].path, '/admin/users/u1/devices');
  });
  test('POST actions return typed device and exact body', () async {
    http.respond = (_) =>
        const Reply(200, {'id': 'd1', 'status': 'revoked', 'rejected': true});
    expect(
      (await api.updateDevice('d1', 'reject', {'reason': 'lạ'})).rejected,
      true,
    );
    expect(http.seen.last.method, 'POST');
    expect(http.seen.last.path, '/admin/devices/d1/reject');
    expect(http.seen.last.data, {'reason': 'lạ'});
    await api.updateDevice('d1', 'allow_until', {'expires_at': '2027-12-01'});
    expect(http.seen.last.data, {'expires_at': '2027-12-01'});
  });
  test(
    'errors translate every raw code; 403 stays generic; no write retry',
    () async {
      for (final code in [
        'limit',
        'reason_required',
        'invalid_transition',
        'invalid_kind',
        'invalid_status',
        'invalid_expiry',
      ]) {
        http.respond = (_) => Reply(422, {'error': code, 'message': code});
        final before = http.seen.length;
        expect(
          deviceError(await caught(api.updateDevice('d1', 'approve'))),
          isNot(code),
        );
        expect(http.seen.length, before + 1);
      }
      expect(
        deviceError(const ApiError(422, 'limit', 'limit')),
        contains('2 thiết bị cố định'),
      );
      expect(
        deviceError(
          const ApiError(
            422,
            'invalid_expiry',
            'expires_at must be within 90 days',
          ),
        ),
        contains('tối đa 90 ngày'),
      );
      http.respond = (_) => const Reply(403, {'error': 'forbidden'});
      expect(
        deviceError(await caught(api.listDevices())),
        'Bạn không có quyền thực hiện thao tác này',
      );
    },
  );
  test('devices entry is admin superadmin manager only', () {
    for (final role in [
      'admin',
      'superadmin',
      'manager',
      'agent',
      'sales_partner',
      'sales_free',
    ]) {
      expect(
        screens['devices']!([role]),
        ['admin', 'superadmin', 'manager'].contains(role),
      );
    }
  });
  test('branches uses existing typed sales API', () async {
    http.respond = (_) => const Reply(200, {
      'data': [
        {
          'id': 'b1',
          'code': 'HCM',
          'name': 'Hồ Chí Minh',
          'entity': null,
          'province': 'HCM',
        },
      ],
    });
    expect((await SalesApi(client).fetchBranches()).first.code, 'HCM');
    expect(http.seen.last.path, '/branches');
  });
  test('anomalies are typed', () async {
    http.respond = (_) => const Reply(200, {
      'shared_devices': [
        {
          'device_id': 'd1',
          'users': [
            {'id': 'u1'},
          ],
        },
      ],
      'ip_networks': [
        {
          'user': {'id': 'u1'},
          'networks': ['1.2.3.0/24'],
        },
      ],
    });
    final result = await api.fetchDeviceAnomalies();
    expect(result.sharedDevices.first.users.first.id, 'u1');
    expect(result.ipNetworks.first.networks, ['1.2.3.0/24']);
    expect(http.seen.last.path, '/admin/devices/anomalies');
  });
}
