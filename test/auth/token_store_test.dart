import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/auth/token_store.dart';

class MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  int reads = 0;
  int deletes = 0;
  bool fail = false;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads++;
    if (fail) throw Exception('private-token private-device');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) throw Exception('private-token private-device');
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletes++;
    if (fail) throw Exception('private-token private-device');
    values.remove(key);
  }
}

String jwt(Map<String, Object?> payload) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.sig';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final key in ['sd_session', 'sd_device']) {
    test('$key uses first unlock this device only on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      final store = SecureValue(key);
      await store.get();
      await store.set('value');
      await store.clear();
      expect(calls.map((c) => c.method), ['read', 'write', 'delete']);
      for (final call in calls) {
        final args = call.arguments as Map;
        expect(args['key'], key);
        expect(
          (args['options'] as Map)['accessibility'],
          'first_unlock_this_device',
        );
      }
    });
  }
  test(
    'storage failures surface without credential-bearing platform text',
    () async {
      final storage = MemoryStorage()..fail = true;
      final store = SecureValue('sd_session', storage: storage);
      for (final operation in [
        store.get,
        () => store.set('private-token'),
        store.clear,
      ]) {
        await expectLater(
          operation(),
          throwsA(predicate<Object>((e) => !e.toString().contains('private-'))),
        );
      }
      expect(await store.get(), isNull);
    },
  );
  test('persists across store instances', () async {
    final storage = MemoryStorage();
    await SecureValue('sd_session', storage: storage).set('abc');
    expect(await SecureValue('sd_session', storage: storage).get(), 'abc');
  });
  test('caches missing values after one read', () async {
    final storage = MemoryStorage();
    final store = SecureValue('sd_session', storage: storage);
    await store.get();
    await store.get();
    expect(storage.reads, 1);
  });
  test('clear removes cached and persisted token, retains device', () async {
    final storage = MemoryStorage();
    final store = SecureValue('sd_session', storage: storage);
    await SecureValue('sd_device', storage: storage).set('device');
    await store.set('abc');
    await store.clear();
    expect(await store.get(), isNull);
    expect(await SecureValue('sd_session', storage: storage).get(), isNull);
    expect(storage.values['sd_device'], 'device');
  });
  test('reads unpadded base64url exp', () {
    expect(tokenExp(jwt({'sub': 'u', 'exp': 1900000000})), 1900000000);
  });
  test('unreadable exp is left to backend', () {
    for (final token in [
      'not-a-jwt',
      jwt({}),
      jwt({'exp': '100'}),
      'e30.W10.sig',
    ]) {
      expect(tokenExp(token), isNull);
      expect(isExpired(token), isFalse);
    }
  });
  test('missing token and expiration boundary', () {
    expect(isExpired(null), isTrue);
    expect(isExpired(''), isTrue);
    expect(isExpired(jwt({'exp': 100}), 200), isTrue);
    expect(isExpired(jwt({'exp': 200}), 200), isTrue);
    expect(isExpired(jwt({'exp': 300}), 200), isFalse);
  });
}
