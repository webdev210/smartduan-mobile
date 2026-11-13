import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/public.dart';
import '../../auth/messages.dart';
import '../../auth/session.dart';
import '../../config.dart';
import '../../ui/kit.dart'
    show Screen, Muted, Card, Field, Notice, Button, ButtonGroup;
import '../../ui/otp_step.dart';
import '../../ui/theme.dart' as c;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.notice});
  final String? notice;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _email = '', _password = '';
  bool _busy = false;
  String? _error;
  ({String email, String notice})? _otp;
  ({String state, String text})? _diag;

  Future<void> _submit() async {
    if (_busy || _email.isEmpty || _password.isEmpty) return;
    final email = _email.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authApiProvider).login(email, _password);
      if (!mounted) return;
      await ref
          .read(sessionProvider.notifier)
          .signIn(result['token'] as String);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        switch (loginOutcome(error)) {
          case LoginOtp(email: final serverEmail, :final message):
            _otp = (email: serverEmail ?? email, notice: message);
          case LoginMessage(:final message):
            _error = message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkConnection() async {
    if (_diag?.state == 'checking') return;
    setState(() => _diag = (state: 'checking', text: 'Đang kiểm tra…'));
    final timer = Stopwatch()..start();
    final api = ref.read(publicApiProvider);
    try {
      await api.health();
      final provinces = await api.fetchProvinces();
      if (mounted) {
        setState(
          () => _diag = (
            state: 'ok',
            text:
                'Kết nối OK · ${provinces.length} tỉnh/thành · ${timer.elapsedMilliseconds}ms',
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _diag = (state: 'error', text: errorMessage(error)));
      }
    } finally {
      timer.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ended = sessionEndedMessage(
      ref.watch(sessionProvider.select((s) => s.endedReason)),
    );
    if (_otp case final otp?) {
      return OtpStep(
        email: otp.email,
        password: _password,
        notice: otp.notice,
        onBack: () => setState(() => _otp = null),
      );
    }
    return Screen(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Image.asset(
                'assets/smartland-mark.png',
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                semanticLabel: 'Smartland',
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    'Smart Dự Án',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Muted(
                    'Bảng hàng, giữ căn và tài liệu dự án dành cho sales.',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (ended != null) Notice(tone: 'warn', text: ended),
        if (widget.notice?.isNotEmpty == true)
          Notice(tone: 'success', text: widget.notice!),
        Card(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Field(
                label: 'Email',
                value: _email,
                onChangeText: (v) => setState(() => _email = v),
                placeholder: 'ten@congty.vn',
                autoCapitalize: TextCapitalization.none,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
              ),
              Field(
                label: 'Mật khẩu',
                value: _password,
                onChangeText: (v) => setState(() => _password = v),
                placeholder: '••••••••',
                obscureText: true,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.go,
                onSubmit: (_) => _submit(),
              ),
              if (_error != null) Notice(tone: 'error', text: _error!),
              Button(
                title: 'Đăng nhập',
                onPress: _submit,
                loading: _busy,
                disabled: _email.isEmpty || _password.isEmpty,
              ),
              ButtonGroup(
                spacing: 12,
                children: [
                  Button(
                    title: 'Quên mật khẩu?',
                    kind: 'link',
                    onPress: () => context.push('/quen-mat-khau'),
                  ),
                  Button(
                    title: 'Đăng ký tài khoản',
                    kind: 'link',
                    onPress: () => context.push('/dang-ky'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Row(
                spacing: 8,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (_diag?.state) {
                        'ok' => c.success,
                        'error' => c.danger,
                        _ => c.subtle,
                      },
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _diag?.text ?? 'Máy chủ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ),
                  Button(
                    title: _diag?.state == 'checking' ? '…' : 'Kiểm tra',
                    kind: 'link',
                    size: 'sm',
                    accessibilityLabel: 'Kiểm tra kết nối máy chủ',
                    onPress: _checkConnection,
                    disabled: _diag?.state == 'checking',
                  ),
                ],
              ),
              if (kDebugMode)
                const Muted(apiUrl, style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Button(
          title: 'Chính sách bảo mật',
          kind: 'link',
          onPress: () => context.push('/chinh-sach-bao-mat'),
        ),
      ],
    );
  }
}
