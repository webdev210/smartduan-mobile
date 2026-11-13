import 'dart:io';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config.dart';
import 'errors.dart';

bool isNoAuth(String url) => const [
  '/auth/login',
  '/auth/google',
  '/auth/register',
  '/auth/password/',
  '/auth/verify-email',
  '/auth/revoked',
  '/public/',
  '/devices',
].any(url.startsWith);

String androidUserAgent([String version = appVersion, String release = '']) =>
    'SmartDuAn/$version Flutter Dalvik/ (Android $release)';
String iosUserAgent([String version = appVersion]) =>
    'SmartDuAn/$version Flutter CFNetwork/ Darwin';

String revokedReason(Map<String, dynamic>? data) {
  if (data?['reason'] == 'role_changed' &&
      data?['roles'] is List &&
      (data!['roles'] as List<dynamic>).contains('sales_partner')) {
    return 'f2_approved';
  }
  return data?['reason'] is String ? data!['reason'] as String : 'expired';
}

class ApiClient {
  ApiClient({
    SecureValue? tokens,
    HttpClientAdapter? adapter,
    HttpClientAdapter? revokedAdapter,
    String baseUrl = apiUrl,
  }) : tokens = tokens ?? tokenStore,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 30),
           sendTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
           followRedirects: false,
           headers: {
             'Accept': 'application/json',
             'User-Agent': Platform.isIOS
                 ? iosUserAgent()
                 : androidUserAgent(
                     appVersion,
                     Platform.operatingSystemVersion,
                   ),
           },
         ),
       ),
       _revoked = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           sendTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 10),
           followRedirects: false,
         ),
       ) {
    _revoked.options.headers['User-Agent'] = _dio.options.headers['User-Agent'];
    if (adapter != null) _dio.httpClientAdapter = adapter;
    if (revokedAdapter != null) _revoked.httpClientAdapter = revokedAdapter;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            options.extra['sessionEpoch'] = _sessionEpoch;
            options.headers.removeWhere(
              (key, _) => key.toLowerCase() == 'authorization',
            );
            if (_authenticated(options)) {
              final token = await this.tokens.get();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            handler.next(options);
          } catch (_) {
            handler.reject(
              _safeException(
                const ApiError(
                  0,
                  'storage',
                  'Không đọc được phiên đăng nhập, thử lại sau',
                ),
              ),
            );
          }
        },
        onError: (error, handler) async {
          if (error.error is ApiError) {
            handler.next(error);
            return;
          }
          try {
            handler.reject(_safeException(await _mapError(error)));
          } catch (_) {
            handler.reject(
              _safeException(
                const ApiError(
                  0,
                  'storage',
                  'Không xoá được phiên đăng nhập, thử lại sau',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  final SecureValue tokens;
  final Dio _dio;
  final Dio _revoked;
  void Function(String reason)? onSessionEnded;
  Future<void>? _ending;
  int _sessionEpoch = 0;

  bool _authenticated(RequestOptions options) {
    final base = Uri.parse(_dio.options.baseUrl);
    final target = options.uri;
    if (target.origin != base.origin) return false;
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    if (!target.path.startsWith('$basePath/')) return false;
    final path = target.path.substring(basePath.length);
    return !isNoAuth(path);
  }

  // Do not let Dio stringify request headers, bodies or transport exceptions.
  DioException _safeException(ApiError error) => DioException(
    requestOptions: RequestOptions(),
    error: error,
    message: 'API request failed',
  );

  Future<ApiError> _mapError(DioException error) async {
    final response = error.response;
    if (response == null) {
      return const ApiError(
        0,
        'network',
        'Không kết nối được máy chủ, kiểm tra mạng rồi thử lại',
      );
    }
    final status = response.statusCode ?? 0;
    final body = response.data;
    final data = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final parsedRetry = num.tryParse(
      response.headers.value('retry-after') ?? '',
    );
    final retry =
        parsedRetry != null && parsedRetry.isFinite && parsedRetry != 0
        ? parsedRetry
        : null;
    if (status == 401 && _authenticated(response.requestOptions)) {
      final sent = response.requestOptions.headers['Authorization'] as String?;
      await _endSession(
        sent?.replaceFirst('Bearer ', ''),
        data['error'] == 'device_revoked' ? 'device_revoked' : null,
        response.requestOptions.extra['sessionEpoch'] as int,
      );
      return ApiError(
        401,
        'unauthorized',
        'Phiên đã hết hạn, vui lòng đăng nhập lại',
        body: body,
      );
    }
    var message = data['message'] is String
        ? data['message'] as String
        : 'Có lỗi xảy ra, thử lại sau';
    if (status == 429 && data['error'] != 'cooldown') {
      message = 'Quá nhiều yêu cầu, thử lại sau ${retry ?? 60} giây';
    }
    if (status == 404 &&
        (data['message'] == null ||
            message.isEmpty ||
            message == 'Resource not found')) {
      message = 'Không tìm thấy hoặc bạn không có quyền xem';
    }
    if (status == 403 &&
        (data['message'] == null ||
            message.isEmpty ||
            message == 'Not allowed')) {
      message = 'Bạn không có quyền thực hiện thao tác này';
    }
    Map<String, List<String>>? details;
    if (data['details'] case final Map<String, dynamic> raw) {
      if (raw.values.every(
        (v) => v is List && v.every((dynamic item) => item is String),
      )) {
        details = raw.map(
          (key, dynamic value) =>
              MapEntry(key, (value as List<dynamic>).cast<String>()),
        );
      }
    }
    return ApiError(
      status,
      data['error'] is String ? data['error'] as String : 'error',
      _redact(message, response.requestOptions),
      details: details,
      retryAfter: retry,
      body: body,
    );
  }

  String _redact(String message, RequestOptions request) {
    final secrets = <String>[];
    for (final MapEntry(:key, :value) in request.headers.entries) {
      if (value is String &&
          (key.toLowerCase() == 'authorization' ||
              key.toLowerCase() == 'x-device-id')) {
        secrets.add(value);
        if (value.startsWith('Bearer ')) secrets.add(value.substring(7));
      }
    }
    if (request.data case final Map<String, dynamic> body) {
      for (final key in ['token', 'password', 'turnstile_token']) {
        if (body[key] case final String value) secrets.add(value);
      }
    }
    for (final secret in secrets) {
      if (secret.isNotEmpty) message = message.replaceAll(secret, '[redacted]');
    }
    return message;
  }

  Future<void> _endSession(String? deadToken, String? knownReason, int epoch) {
    if (epoch != _sessionEpoch) return _ending ?? Future<void>.value();
    return _ending ??= _finishSession(deadToken, knownReason).whenComplete(() {
      if (_sessionEpoch == epoch + 1) _ending = null;
    });
  }

  Future<void> _finishSession(String? deadToken, String? knownReason) async {
    // Responses sent before this end belong to one session, even if they arrive
    // after the single-flight future has completed.
    final epoch = ++_sessionEpoch;
    var reason = knownReason ?? 'expired';
    if (deadToken != null && knownReason == null) {
      try {
        final response = await _revoked.get<Object?>(
          '/auth/revoked',
          options: Options(headers: {'Authorization': 'Bearer $deadToken'}),
        );
        reason = revokedReason(
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      } catch (_) {
        /* A missing revocation record means ordinary expiry. */
      }
    }
    if (epoch != _sessionEpoch) return;
    await tokens.clear();
    if (epoch != _sessionEpoch) return;
    onSessionEnded?.call(reason);
  }

  Future<void> setSessionToken(String? token) {
    _sessionEpoch++;
    _ending = null;
    return token == null ? tokens.clear() : tokens.set(token);
  }

  Future<void> endSessionLocally([String? reason = 'logout_local']) async {
    await setSessionToken(null);
    if (reason != null) onSessionEnded?.call(reason);
  }

  Future<Object?> request(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, dynamic>? params,
    Map<String, dynamic>? headers,
  }) async {
    try {
      return (await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: params,
        options: Options(method: method, headers: headers),
      )).data;
    } on DioException catch (error) {
      if (error.error case final ApiError apiError) throw apiError;
      throw const ApiError(
        0,
        'network',
        'Không kết nối được máy chủ, kiểm tra mạng rồi thử lại',
      );
    }
  }

  Future<Object?> get(String path, [Map<String, dynamic>? params]) =>
      request(path, params: params);
  Future<Object?> post(String path, [Object? body]) =>
      request(path, method: 'POST', body: body);
  Future<Object?> put(String path, [Object? body]) =>
      request(path, method: 'PUT', body: body);
  Future<Object?> patch(String path, [Object? body]) =>
      request(path, method: 'PATCH', body: body);
  Future<Object?> del(String path, [Object? body]) =>
      request(path, method: 'DELETE', body: body);
  void close() {
    _dio.close();
    _revoked.close();
  }
}
