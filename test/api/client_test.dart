import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

void main() {
  late MemoryStorage storage;
  late SecureValue tokens;
  late FakeHttp http;
  late FakeHttp revoked;
  late ApiClient client;
  late List<String> ended;
  setUp(() {
    storage = MemoryStorage();
    tokens = SecureValue('sd_session', storage: storage);
    http = FakeHttp((_) => const Reply(200, {'ok': 1}));
    revoked = FakeHttp((_) => const Reply(404));
    client = ApiClient(tokens: tokens, adapter: http, revokedAdapter: revoked);
    ended = [];
    client.onSessionEnded = ended.add;
  });
  tearDown(() => client.close());
  test('same-origin URLs outside API path never receive Bearer', () async {
    await tokens.set('T1');
    http.respond = (_) => const Reply(401);
    for (final path in ['/xac-minh-app', '/media/file', '/m/api/v10/me']) {
      await caught(client.get('https://smartduan.vn$path'));
    }
    expect(
      http.seen.every((r) => !r.headers.containsKey('Authorization')),
      isTrue,
    );
    expect(await tokens.get(), 'T1');
    expect(ended, isEmpty);
    expect(revoked.seen, isEmpty);
  });
  test(
    'trailing base slash preserves public routes and authenticated me',
    () async {
      client.close();
      client = ApiClient(
        tokens: tokens,
        adapter: http,
        revokedAdapter: revoked,
        baseUrl: 'https://smartduan.vn/m/api/v1/',
      );
      client.onSessionEnded = ended.add;
      await tokens.set('T1');
      http.respond = (_) => const Reply(401);
      for (final path in ['/auth/login', '/devices']) {
        await caught(client.post(path, {}));
        await caught(client.get('https://smartduan.vn/m/api/v1$path'));
      }
      expect(
        http.seen.every((r) => !r.headers.containsKey('Authorization')),
        isTrue,
      );
      expect(ended, isEmpty);
      expect(await tokens.get(), 'T1');
      http.respond = (_) => const Reply(200);
      await client.get('/me');
      expect(http.seen.last.headers['Authorization'], 'Bearer T1');
    },
  );
  test('revocation request uses the main client mobile User-Agent', () async {
    await tokens.set('DEAD');
    http.respond = (_) => const Reply(401);
    await caught(client.get('/me'));
    expect(
      revoked.seen.single.headers['User-Agent'],
      http.seen.single.headers['User-Agent'],
    );
  });
  test('Bearer on authenticated routes and JSON defaults', () async {
    await tokens.set('T1');
    expect(await client.get('/me'), {'ok': 1});
    final request = http.seen.single;
    expect(request.headers['Authorization'], 'Bearer T1');
    expect(request.headers['Accept'], 'application/json');
    expect(request.connectTimeout, const Duration(seconds: 30));
    expect(request.receiveTimeout, const Duration(seconds: 30));
    expect(request.sendTimeout, const Duration(seconds: 30));
  });
  test(
    'all public prefixes exclude Bearer, including absolute API URLs',
    () async {
      await tokens.set('T1');
      for (final path in [
        '/auth/login',
        '/auth/google',
        '/auth/register/verify',
        '/auth/password/reset',
        '/auth/verify-email',
        '/auth/revoked',
        '/public/provinces',
        '/devices',
      ]) {
        await client.post(path, {});
        await client.get('https://smartduan.vn/m/api/v1$path');
      }
      expect(
        http.seen.every((r) => !r.headers.containsKey('Authorization')),
        isTrue,
      );
      expect(isNoAuth('/auth/logout_all'), isFalse);
      expect(isNoAuth('/auth/ws-token'), isFalse);
      expect(isNoAuth('/auth/register/verify'), isTrue);
    },
  );
  test('external absolute URLs never receive Bearer or end session', () async {
    await tokens.set('T1');
    http.respond = (_) => const Reply(401);
    await caught(client.get('https://other.example/me'));
    expect(http.seen.single.headers.containsKey('Authorization'), isFalse);
    expect(await tokens.get(), 'T1');
    expect(ended, isEmpty);
  });
  test(
    'network and timeout become status 0 without leaking transport text',
    () async {
      http.respond = (r) => throw DioException(
        requestOptions: r,
        message: 'secret device Authorization',
        type: DioExceptionType.connectionTimeout,
      );
      final e = await caught(client.get('/me'));
      expect(e.status, 0);
      expect(e.code, 'network');
      expect(
        e.message,
        'Không kết nối được máy chủ, kiểm tra mạng rồi thử lại',
      );
      expect(e.toString(), isNot(contains('secret')));
    },
  );
  test('401 login keeps backend code and existing session', () async {
    await tokens.set('T1');
    http.respond = (_) =>
        const Reply(401, {'error': 'invalid_credentials', 'message': 'Sai'});
    expect(
      (await caught(client.post('/auth/login', {}))).code,
      'invalid_credentials',
    );
    expect(ended, isEmpty);
    expect(await tokens.get(), 'T1');
  });
  test('401 queries revocation outside interceptor with dead token', () async {
    await tokens.set('DEAD');
    http.respond = (_) => const Reply(401, {'error': 'unauthorized'});
    revoked.respond = (_) => const Reply(200, {
      'reason': 'role_changed',
      'roles': ['sales_partner'],
    });
    final e = await caught(client.get('/me'));
    expect(e.status, 401);
    expect(e.code, 'unauthorized');
    expect(e.message, 'Phiên đã hết hạn, vui lòng đăng nhập lại');
    expect(revoked.seen.single.uri.path, '/m/api/v1/auth/revoked');
    expect(revoked.seen.single.headers['Authorization'], 'Bearer DEAD');
    expect(revoked.seen.single.receiveTimeout, const Duration(seconds: 10));
    expect(ended, ['f2_approved']);
    expect(await tokens.get(), isNull);
  });
  test('device_revoked skips lookup', () async {
    await tokens.set('DEAD');
    http.respond = (_) => const Reply(401, {'error': 'device_revoked'});
    await caught(client.get('/me'));
    expect(revoked.seen, isEmpty);
    expect(ended, ['device_revoked']);
    expect(await tokens.get(), isNull);
  });
  test('concurrent 401s clear and notify exactly once', () async {
    await tokens.set('DEAD');
    http.respond = (_) => const Reply(401);
    final gate = Completer<Reply>();
    revoked.respond = (_) => gate.future;
    final pending = [
      '/me',
      '/sales/notifications',
      '/projects',
    ].map((p) => caught(client.get(p))).toList();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete(const Reply(404));
    await Future.wait(pending);
    expect(revoked.seen, hasLength(1));
    expect(storage.deletes, 1);
    expect(ended, ['expired']);
  });
  test('429 retry header, default and business cooldown', () async {
    http.respond = (_) => const Reply(
      429,
      {'error': 'rate_limited'},
      {
        'retry-after': ['42'],
      },
    );
    final e = await caught(client.get('/sales/units/search'));
    expect(e.retryAfter, 42);
    expect(e.message, 'Quá nhiều yêu cầu, thử lại sau 42 giây');
    http.respond = (_) => const Reply(429);
    expect(
      (await caught(client.get('/a'))).message,
      'Quá nhiều yêu cầu, thử lại sau 60 giây',
    );
    http.respond = (_) =>
        const Reply(429, {'error': 'cooldown', 'message': 'Chờ phê duyệt'});
    expect((await caught(client.get('/a'))).message, 'Chờ phê duyệt');
  });
  for (final (status, generic, translated) in [
    (404, 'Resource not found', 'Không tìm thấy hoặc bạn không có quyền xem'),
    (403, 'Not allowed', 'Bạn không có quyền thực hiện thao tác này'),
  ]) {
    test(
      '$status missing/generic message translated, specific message preserved',
      () async {
        for (final message in [null, '', generic]) {
          http.respond = (_) => Reply(status, {'message': message});
          expect((await caught(client.get('/a'))).message, translated);
        }
        http.respond = (_) => Reply(status, {
          'message':
              'Chỉ quản trị cấp cao được đặt link rổ hàng ngoài danh sách',
        });
        expect(
          (await caught(client.get('/c'))).message,
          'Chỉ quản trị cấp cao được đặt link rổ hàng ngoài danh sách',
        );
      },
    );
  }
  test('422 keeps details and body', () async {
    const body = {
      'error': 'validation_failed',
      'message': 'Sai',
      'details': {
        'phone': ['không hợp lệ'],
      },
    };
    http.respond = (_) => const Reply(422, body);
    final e = await caught(client.post('/c', {}));
    expect(e.details, {
      'phone': ['không hợp lệ'],
    });
    expect(e.body, body);
  });
  for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    test('$method never auto-retries', () async {
      http.respond = (_) =>
          const Reply(503, {'error': 'lead_delivery_unknown'});
      await caught(
        client.request(
          '/sales/consult',
          method: method,
          body: {'consent': true},
        ),
      );
      expect(http.seen, hasLength(1));
    });
  }
  test('revokedReason defaults and role mapping', () {
    expect(
      revokedReason({
        'reason': 'role_changed',
        'roles': ['agent'],
      }),
      'role_changed',
    );
    expect(revokedReason({'reason': null}), 'expired');
    expect(revokedReason(null), 'expired');
  });
  test('mobile user agents match backend classifiers', () {
    final android = RegExp(
      r'okhttp\/|Dalvik\/|Expo\/.*Android',
      caseSensitive: false,
    );
    expect(
      androidUserAgent('1.0.0', '15'),
      'SmartDuAn/1.0.0 Flutter Dalvik/ (Android 15)',
    );
    expect(android.hasMatch(androidUserAgent('1.0.0', '15')), isTrue);
    expect(android.hasMatch('ExpoGo/58.0.5'), isFalse);
    expect(iosUserAgent('1.0.0'), 'SmartDuAn/1.0.0 Flutter CFNetwork/ Darwin');
    expect(
      RegExp(
        r'(?:CFNetwork\/|Expo\/).*Darwin',
        caseSensitive: false,
      ).hasMatch(iosUserAgent('1.0.0')),
      isTrue,
    );
  });
  test(
    'concurrent device revocations notify only once without lookup',
    () async {
      await tokens.set('DEAD');
      http.respond = (_) => const Reply(401, {'error': 'device_revoked'});
      await Future.wait(
        [
          '/me',
          '/projects',
          '/sales/notifications',
        ].map((path) => caught(client.get(path))),
      );
      expect(storage.deletes, 1);
      expect(ended, ['device_revoked']);
      expect(revoked.seen, isEmpty);
    },
  );
  test(
    'backend echo of credentials is removed from exception message',
    () async {
      await tokens.set('private-session');
      http.respond = (_) => const Reply(403, {
        'message': 'Rejected Bearer private-session private-device',
      });
      final error = await caught(
        client.request('/me', headers: {'X-Device-Id': 'private-device'}),
      );
      expect(error.message, isNot(contains('private-session')));
      expect(error.message, isNot(contains('private-device')));
      expect(error.toString(), isNot(contains('private-')));
    },
  );
}
