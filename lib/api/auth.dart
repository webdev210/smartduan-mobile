import 'dart:math';

import '../auth/token_store.dart';
import '../config.dart';
import 'client.dart';
import 'errors.dart';

class AuthApi {
  AuthApi(this.client, {SecureValue? devices})
    : devices = devices ?? deviceStore;
  final ApiClient client;
  final SecureValue devices;

  Map<String, dynamic> _map(Object? value) => switch (value) {
    final Map<String, dynamic> map => map,
    _ => throw const ApiError(
      0,
      'invalid_response',
      'Có lỗi xảy ra, thử lại sau',
    ),
  };

  Future<String> _deviceId() async {
    final saved = await devices.get();
    if (saved != null && saved.isNotEmpty) return saved;
    final reply = _map(await client.post('/devices'));
    if (reply['device_id'] case final String id when id.isNotEmpty) {
      await devices.set(id);
      return id;
    }
    throw const ApiError(0, 'invalid_response', 'Có lỗi xảy ra, thử lại sau');
  }

  Future<Map<String, dynamic>> _postWithDevice(
    String path,
    Map<String, Object?> body,
  ) async => _map(
    await client.request(
      path,
      method: 'POST',
      body: body,
      headers: {'X-Device-Id': await _deviceId()},
    ),
  );
  bool _hasToken(Map<String, dynamic> reply) =>
      reply['token'] is String && (reply['token'] as String).isNotEmpty;
  ApiError _pending(Map<String, dynamic> reply) => ApiError(
    202,
    reply['error'] is String && (reply['error'] as String).isNotEmpty
        ? reply['error'] as String
        : 'device_pending',
    'Thiết bị đang chờ quản trị duyệt',
    body: reply,
  );

  Future<Map<String, dynamic>> login(String email, String password) async {
    Map<String, dynamic> reply;
    try {
      reply = await _postWithDevice('/auth/login', {
        'email': email,
        'password': password,
      });
    } on ApiError catch (error) {
      if (error.code != 'device_required') rethrow;
      // Explicit protocol recovery only; transport requests never auto-retry.
      await devices.clear();
      reply = await _postWithDevice('/auth/login', {
        'email': email,
        'password': password,
      });
    }
    if (!_hasToken(reply)) throw _pending(reply);
    return reply;
  }

  Future<Map<String, dynamic>> register(Map<String, String> input) async =>
      _map(await client.post('/auth/register', {...input, 'consent': true}));
  Future<Map<String, dynamic>> resendRegistrationOtp(
    String email,
    String turnstileToken,
  ) async => _map(
    await client.post('/auth/register/resend', {
      'email': email,
      'turnstile_token': turnstileToken,
    }),
  );
  Future<Map<String, dynamic>> forgotPassword(
    String email,
    String turnstileToken,
  ) async => _map(
    await client.post('/auth/password/forgot', {
      'email': email,
      'turnstile_token': turnstileToken,
    }),
  );

  Future<Map<String, dynamic>> verifyRegistration(
    String email,
    String code,
    String password,
  ) async {
    Map<String, dynamic> reply;
    try {
      reply = await _postWithDevice('/auth/register/verify', {
        'email': email,
        'code': code,
        'password': password,
      });
    } on ApiError catch (error) {
      if (error.code == 'device_required') return login(email, password);
      rethrow;
    }
    if (_hasToken(reply)) return reply;
    if (reply['error'] is String && (reply['error'] as String).isNotEmpty) {
      throw _pending(reply);
    }
    return login(email, password);
  }

  // ponytail: M1 returns decoded maps; add typed models with their owning screens.
  Future<Map<String, dynamic>> fetchMe() async => _map(await client.get('/me'));
  Future<Map<String, dynamic>> logoutAll() async =>
      _map(await client.post('/auth/logout_all'));
  Future<Map<String, dynamic>> resetPassword(
    String token,
    String password,
  ) async => _map(
    await client.post('/auth/password/reset', {
      'token': token,
      'password': password,
    }),
  );
  Future<Map<String, dynamic>> wsToken() async =>
      _map(await client.post('/auth/ws-token'));
  Future<Map<String, dynamic>> basketToken(
    String projectId, [
    bool presenting = false,
  ]) async => _map(
    await client.post('/auth/basket-token', {
      'project_id': projectId,
      'presenting': presenting,
    }),
  );
}

String basketUrl(
  String embedUrl,
  String token, {
  String parent = webUrl,
  String? nonce,
}) {
  final base = embedUrl.split(RegExp('[?#]')).first;
  final path = base.endsWith('/') ? base : '$base/';
  if (parent.isEmpty) parent = 'https://smartduan.vn';
  final origin =
      RegExp(
        r'^[a-z]+://[^/]+',
        caseSensitive: false,
      ).firstMatch(parent)?.group(0) ??
      parent;
  nonce ??= Random.secure().nextInt(1 << 32).toRadixString(36);
  return '$path?embed=1&parent=${Uri.encodeComponent(origin)}&nonce=$nonce#sd_token=${Uri.encodeComponent(token)}';
}
