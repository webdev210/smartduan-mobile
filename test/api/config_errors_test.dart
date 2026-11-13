import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/config.dart';
import 'package:smartduan/api/errors.dart';

void main() {
  test('production config and pubspec version name', () {
    expect(
      apiUrl,
      const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://smartduan.vn/m/api/v1',
      ),
    );
    expect(
      wsUrl,
      const String.fromEnvironment(
        'WS_URL',
        defaultValue: 'wss://smartduan.vn/m/socket',
      ),
    );
    expect(
      webUrl,
      const String.fromEnvironment(
        'WEB_URL',
        defaultValue: 'https://smartduan.vn',
      ),
    );
    expect(originUrl, apiUrl.replaceFirst(RegExp(r'/api/v1/?$'), ''));
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(appVersion, version);
  });
  test('error helpers preserve message and join field details', () {
    final error = ApiError(
      422,
      'validation_failed',
      'Sai',
      details: {
        'phone': ['a', 'b'],
      },
      body: {'token': 'secret'},
    );
    expect(errorMessage(error), 'Sai');
    expect(fieldError(error, 'phone'), 'a, b');
    expect(fieldError(error, 'email'), isNull);
    expect(fieldError('unknown', 'phone'), isNull);
    for (final unknown in [
      Exception('oops'),
      const FormatException('storage failed'),
      StateError('runtime'),
      'text',
      Object(),
    ]) {
      expect(errorMessage(unknown), 'Có lỗi xảy ra, thử lại sau');
    }
    expect(errorMessage(null), 'Có lỗi xảy ra, thử lại sau');
    expect(error.toString(), isNot(contains('secret')));
  });
}
