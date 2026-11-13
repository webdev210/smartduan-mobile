import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureValue {
  SecureValue(this.key, {FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final String key;
  final FlutterSecureStorage _storage;
  bool _loaded = false;
  String? _cached;

  Future<String?> get() async {
    if (!_loaded) {
      try {
        _cached = await _storage.read(key: key);
      } catch (_) {
        throw const FormatException('Không đọc được bộ nhớ bảo mật');
      }
      _loaded = true;
    }
    return _cached;
  }

  Future<void> set(String value) async {
    _cached = value;
    _loaded = true;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      throw const FormatException('Không ghi được bộ nhớ bảo mật');
    }
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _storage.delete(key: key);
    } catch (_) {
      throw const FormatException('Không xoá được bộ nhớ bảo mật');
    }
  }
}

final tokenStore = SecureValue('sd_session');
final deviceStore = SecureValue('sd_device');

/// Expiry is a local hint only. Roles always come from the authenticated API.
num? tokenExp(String token) {
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
    );
    return switch (payload) {
      {'exp': num exp} => exp,
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

bool isExpired(String? token, [num? nowSec]) {
  if (token == null || token.isEmpty) return true;
  final exp = tokenExp(token);
  return exp != null &&
      exp <= (nowSec ?? DateTime.now().millisecondsSinceEpoch / 1000);
}
