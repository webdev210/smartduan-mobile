import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/api/auth.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';

class TestAuth extends AuthApi {
  TestAuth() : super(ApiClient());
  Object? failure;
  final registrations = <Map<String, String>>[];
  final verifications = <List<String>>[];
  final logins = <List<String>>[];
  final resends = <List<String>>[];
  final resets = <List<String>>[];
  void check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, String> input) async {
    registrations.add(input);
    check();
    return {'status': 'pending_verification'};
  }

  @override
  Future<Map<String, dynamic>> verifyRegistration(
    String email,
    String code,
    String password,
  ) async {
    verifications.add([email, code, password]);
    check();
    return {'token': 'jwt'};
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    logins.add([email, password]);
    check();
    return {'token': 'jwt'};
  }

  @override
  Future<Map<String, dynamic>> resendRegistrationOtp(
    String email,
    String token,
  ) async {
    resends.add([email, token]);
    check();
    return {};
  }

  @override
  Future<Map<String, dynamic>> forgotPassword(
    String email,
    String token,
  ) async {
    resets.add([email, token]);
    check();
    return {};
  }
}

class TestSession extends Session {
  TestSession({this.reason});
  final String? reason;
  final tokens = <String>[];
  @override
  SessionState build() =>
      SessionState(SessionStatus.guest, endedReason: reason);
  @override
  Future<void> signIn(String token) async {
    tokens.add(token);
  }
}

Widget authApp(Widget screen, TestAuth api, TestSession session) =>
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api),
        sessionProvider.overrideWith(() => session),
        fetchPrivacyPolicyProvider.overrideWith(
          (ref) async => const PrivacyPolicy(
            version: 'v3',
            title: 'Policy',
            url: null,
            effectiveFrom: '2026-11-12',
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: screen)),
    );
