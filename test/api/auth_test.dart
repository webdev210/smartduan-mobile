import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/auth.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

void main() {
  late MemoryStorage storage;
  late SecureValue devices;
  late FakeHttp http;
  late ApiClient client;
  late AuthApi auth;
  var issued = 0;
  const ok = Reply(200, {
    'token': 'jwt',
    'user': {
      'id': 'u',
      'email': 'a@b.vn',
      'full_name': null,
      'roles': <String>[],
    },
  });
  Reply issue() => Reply(201, {'device_id': 'dev-${++issued}.sig'});
  setUp(() {
    storage = MemoryStorage();
    devices = SecureValue('sd_device', storage: storage);
    issued = 0;
    http = FakeHttp((r) => r.path == '/devices' ? issue() : ok);
    client = ApiClient(
      tokens: SecureValue('sd_session', storage: storage),
      adapter: http,
    );
    auth = AuthApi(client, devices: devices);
  });
  tearDown(() => client.close());
  test('first login issues, persists and sends device id', () async {
    expect((await auth.login('a@b.vn', 'pw'))['token'], 'jwt');
    expect(http.seen.map((r) => r.path), ['/devices', '/auth/login']);
    expect(http.seen.first.headers['Authorization'], isNull);
    expect(http.seen.last.headers['X-Device-Id'], 'dev-1.sig');
    expect(await SecureValue('sd_device', storage: storage).get(), 'dev-1.sig');
  });
  test('saved device is reused', () async {
    await devices.set('saved.sig');
    await auth.login('a@b.vn', 'pw');
    expect(http.seen.map((r) => r.path), ['/auth/login']);
    expect(http.seen.single.headers['X-Device-Id'], 'saved.sig');
  });
  test('device_required replaces stale device exactly once', () async {
    await devices.set('stale.sig');
    http.respond = (r) => r.path == '/devices'
        ? issue()
        : r.headers['X-Device-Id'] == 'stale.sig'
        ? const Reply(400, {'error': 'device_required'})
        : ok;
    expect((await auth.login('a@b.vn', 'pw'))['token'], 'jwt');
    expect(http.seen.map((r) => r.path), [
      '/auth/login',
      '/devices',
      '/auth/login',
    ]);
    expect(await devices.get(), 'dev-1.sig');
  });
  test('second device_required surfaces without looping', () async {
    http.respond = (r) => r.path == '/devices'
        ? issue()
        : const Reply(400, {'error': 'device_required'});
    final e = await caught(auth.login('a@b.vn', 'pw'));
    expect((e.status, e.code), (400, 'device_required'));
    expect(http.seen.where((r) => r.path == '/auth/login'), hasLength(2));
  });
  test('202 pending retains device', () async {
    http.respond = (r) => r.path == '/devices'
        ? issue()
        : const Reply(202, {'error': 'device_pending'});
    final e = await caught(auth.login('a@b.vn', 'pw'));
    expect((e.status, e.code), (202, 'device_pending'));
    expect(await devices.get(), 'dev-1.sig');
  });
  test('503 device_signing_unavailable fixture prevents login', () async {
    http.respond = (_) =>
        const Reply(503, {'error': 'device_signing_unavailable'});
    final e = await caught(auth.login('a@b.vn', 'pw'));
    expect((e.status, e.code), (503, 'device_signing_unavailable'));
    expect(http.seen.map((r) => r.path), ['/devices']);
  });
  test('register sends consent, policy version and captcha', () async {
    http.respond = (_) => const Reply(201, {'status': 'pending_verification'});
    const input = {
      'full_name': 'A',
      'email': 'a@b.vn',
      'phone': '0912345678',
      'password': '1234567890',
      'consent_version': 'v3',
      'turnstile_token': 'tok',
    };
    await auth.register(input);
    expect(http.seen.single.path, '/auth/register');
    expect(http.seen.single.data, {...input, 'consent': true});
  });
  test('resend and forgot each send fresh captcha', () async {
    await auth.resendRegistrationOtp('a@b.vn', 't1');
    await auth.forgotPassword('a@b.vn', 't2');
    expect(http.seen.map((r) => <Object?>[r.path, r.data]), [
      [
        '/auth/register/resend',
        {'email': 'a@b.vn', 'turnstile_token': 't1'},
      ],
      [
        '/auth/password/forgot',
        {'email': 'a@b.vn', 'turnstile_token': 't2'},
      ],
    ]);
  });
  test('OTP success sends device and returns session', () async {
    await devices.set('saved.sig');
    expect(
      (await auth.verifyRegistration('a@b.vn', '123456', 'pw'))['token'],
      'jwt',
    );
    expect(http.seen.single.path, '/auth/register/verify');
    expect(http.seen.single.data, {
      'email': 'a@b.vn',
      'code': '123456',
      'password': 'pw',
    });
    expect(http.seen.single.headers['X-Device-Id'], 'saved.sig');
  });
  test('verified without token logs in without reusing OTP', () async {
    await devices.set('saved.sig');
    http.respond = (r) => r.path == '/auth/register/verify'
        ? const Reply(200, {'status': 'verified'})
        : ok;
    expect(
      (await auth.verifyRegistration('a@b.vn', '123456', 'pw'))['token'],
      'jwt',
    );
    expect(http.seen.map((r) => r.path), [
      '/auth/register/verify',
      '/auth/login',
    ]);
  });
  test('device_required after OTP uses login then refreshes device', () async {
    await devices.set('stale.sig');
    http.respond = (r) => r.path == '/devices'
        ? issue()
        : r.headers['X-Device-Id'] == 'stale.sig'
        ? const Reply(400, {'error': 'device_required'})
        : ok;
    expect(
      (await auth.verifyRegistration('a@b.vn', '123456', 'pw'))['token'],
      'jwt',
    );
    expect(http.seen.map((r) => r.path), [
      '/auth/register/verify',
      '/auth/login',
      '/devices',
      '/auth/login',
    ]);
  });
  test('OTP pending and invalid code surface without replay', () async {
    await devices.set('saved.sig');
    http.respond = (_) => const Reply(202, {'error': 'device_pending'});
    var e = await caught(auth.verifyRegistration('a@b.vn', '123456', 'pw'));
    expect((e.status, e.code), (202, 'device_pending'));
    http.respond = (_) => const Reply(422, {
      'error': 'invalid_otp',
      'message': 'Mã xác thực không đúng hoặc đã hết hạn',
    });
    e = await caught(auth.verifyRegistration('a@b.vn', '000000', 'pw'));
    expect((e.status, e.code), (422, 'invalid_otp'));
    expect(http.seen, hasLength(2));
  });
  test('all remaining auth endpoints preserve method and bodies', () async {
    await auth.fetchMe();
    await auth.logoutAll();
    await auth.resetPassword('reset', 'new');
    await auth.wsToken();
    await auth.basketToken('p');
    await auth.basketToken('p', true);
    expect(http.seen.map((r) => <Object?>[r.method, r.path, r.data]), [
      ['GET', '/me', null],
      ['POST', '/auth/logout_all', null],
      [
        'POST',
        '/auth/password/reset',
        {'token': 'reset', 'password': 'new'},
      ],
      ['POST', '/auth/ws-token', null],
      [
        'POST',
        '/auth/basket-token',
        {'project_id': 'p', 'presenting': false},
      ],
      [
        'POST',
        '/auth/basket-token',
        {'project_id': 'p', 'presenting': true},
      ],
    ]);
  });
  test('basket URL drops old query/hash and keeps ticket in fragment', () {
    expect(
      basketUrl(
        'https://basket.vn/a?old=1#old',
        'a+b/',
        parent: 'https://smartduan.vn/path',
        nonce: 'nonce',
      ),
      'https://basket.vn/a/?embed=1&parent=https%3A%2F%2Fsmartduan.vn&nonce=nonce#sd_token=a%2Bb%2F',
    );
  });
  test(
    'malformed issued device never reaches login or secure storage',
    () async {
      http.respond = (_) => const Reply(201, {'device_id': 123});
      expect((await caught(auth.login('a', 'b'))).code, 'invalid_response');
      expect(http.seen, hasLength(1));
      expect(await devices.get(), isNull);
    },
  );
}
