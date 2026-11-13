import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/accounts.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/auth/roles.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

AdminUser user([Map<String, dynamic> values = const {}]) => AdminUser.fromJson({
  'id': 'u1',
  'email': 'a@x.vn',
  'full_name': 'A',
  'phone': '0900000000',
  'status': 'pending',
  'roles': ['sales_free'],
  'phone_verified_at': '2026-11-01T00:00:00Z',
  'f2_request_version': 3,
  ...values,
});

void main() {
  late FakeHttp http;
  late AccountsApi api;
  setUp(() {
    http = FakeHttp(
      (_) => const Reply(200, {
        'data': [
          {'id': 'u1'},
        ],
      }),
    );
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('test', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    api = AccountsApi(client);
  });
  test('pending verified accounts can be decided; abandoned OTP cannot', () {
    expect(accountActions(user(), true, false), ['approve', 'reject']);
    final raw = user({'phone_verified_at': null});
    expect(accountActions(raw, true, false), isEmpty);
    expect(unverified(raw), true);
    expect(statusLabel(raw), 'Chưa xác thực');
    expect(
      accountActions(
        user({'phone_verified_at': null, 'email_verified_at': '2026-11-01'}),
        true,
        false,
      ),
      ['approve', 'reject'],
    );
  });
  test(
    'active locked rejected and F2 action matrix preserves superadmin gate',
    () {
      expect(accountActions(user({'status': 'active'}), true, false), [
        'reject',
        'lock',
      ]);
      expect(accountActions(user({'status': 'active'}), false, false), [
        'reject',
      ]);
      expect(accountActions(user({'status': 'locked'}), true, false), [
        'unlock',
      ]);
      expect(accountActions(user({'status': 'locked'}), false, false), isEmpty);
      expect(accountActions(user({'status': 'rejected'}), true, false), [
        'approve',
      ]);
      expect(
        accountActions(
          user({'status': 'active', 'f2_requested_at': '2026-11-02'}),
          false,
          false,
        ),
        ['approve', 'reject'],
      );
      final sa = user({
        'status': 'active',
        'roles': ['superadmin'],
      });
      expect(accountActions(sa, true, false), isEmpty);
      expect(accountActions(sa, true, true), ['reject', 'lock']);
      expect(statusLabel(user({'status': 'future'})), 'future');
      for (final status in userStatusLabel.keys) {
        expect(statusLabel(user({'status': status})), userStatusLabel[status]);
      }
    },
  );
  test('list defaults to all and trims F2 search', () async {
    expect(await api.listUsers(), hasLength(1));
    expect(http.seen[0].path, '/users');
    expect(http.seen[0].queryParameters, {'status': 'all'});
    await api.listUsers(f2: true, q: ' an ');
    expect(http.seen[1].queryParameters, {
      'status': 'all',
      'f2_requested': 'true',
      'q': 'an',
    });
  });
  test(
    'commands send exact bodies and F2 version only for F2 requests',
    () async {
      await api.approveUser(user({'f2_requested_at': '2026-11-02'}));
      expect(http.seen.last.path, '/auth/admin/users/u1/approve');
      expect(http.seen.last.data, {'f2_request_version': 3});
      await api.approveUser(user());
      expect(http.seen.last.data, isNull);
      await api.rejectUser(user(), 'thiếu giấy tờ');
      expect(http.seen.last.path, '/auth/admin/users/u1/reject');
      expect(http.seen.last.data, {'reason': 'thiếu giấy tờ'});
      await api.lockUser('u1');
      expect(http.seen.last.path, '/auth/admin/users/u1/lock');
      await api.rejectUser(
        user({'f2_requested_at': '2026-11-02'}),
        'chưa đủ hồ sơ',
      );
      expect(http.seen.last.data, {
        'reason': 'chưa đủ hồ sơ',
        'f2_request_version': 3,
      });
      await api.unlockUser('u1');
      expect(http.seen.last.path, '/auth/admin/users/u1/unlock');
      expect(http.seen.every((r) => r.method == 'POST'), true);
    },
  );
  test(
    'errors translate codes, preserve backend message, never retry writes',
    () async {
      for (final code in [
        'invalid_transition',
        'phone_not_verified',
        'reason_required',
        'not_found',
      ]) {
        http.respond = (_) => Reply(422, {'error': code, 'message': code});
        final before = http.seen.length;
        expect(
          accountError(await caught(api.approveUser(user()))),
          isNot(code),
        );
        expect(http.seen.length, before + 1);
      }
      expect(
        accountError(
          const ApiError(
            409,
            'already_decided',
            'Hồ sơ đã được người khác xử lý.',
          ),
        ),
        'Hồ sơ đã được người khác xử lý.',
      );
      expect(
        accountError(
          const ApiError(409, 'invalid_transition', 'invalid transition'),
        ),
        contains('Trạng thái tài khoản đã thay đổi'),
      );
      expect(
        accountError(
          const ApiError(422, 'phone_not_verified', 'phone not verified'),
        ),
        contains('chưa xác thực số điện thoại'),
      );
    },
  );
  test('accounts entry is admin superadmin manager only', () {
    for (final role in [
      'admin',
      'superadmin',
      'manager',
      'agent',
      'sales_partner',
      'sales_free',
    ]) {
      expect(
        screens['accounts']!([role]),
        ['admin', 'superadmin', 'manager'].contains(role),
      );
    }
  });
}
