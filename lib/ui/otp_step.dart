import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/errors.dart';
import '../auth/messages.dart';
import '../auth/session.dart';
import 'captcha.dart';
import 'kit.dart' show Screen, Notice, Card, Field, Button;

class OtpStep extends ConsumerStatefulWidget {
  const OtpStep({
    super.key,
    required this.email,
    required this.password,
    required this.notice,
    required this.onBack,
  });
  final String email, password, notice;
  final VoidCallback onBack;
  @override
  ConsumerState<OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends ConsumerState<OtpStep> {
  String _code = '';
  String? _error;
  late String _info = widget.notice;
  bool _busy = false, _resending = false, _sending = false;

  Future<void> _verify() async {
    if (_busy || _code.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(authApiProvider)
          .verifyRegistration(widget.email, _code, widget.password);
      if (!mounted) return;
      await ref
          .read(sessionProvider.notifier)
          .signIn(response['token'] as String);
    } catch (error) {
      if (mounted) setState(() => _error = loginOutcome(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend(String? token) async {
    if (token == null || !_resending || _sending) return;
    setState(() {
      _resending = false;
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .resendRegistrationOtp(widget.email, token);
      if (mounted) {
        setState(
          () => _info =
              'Đã gửi mã mới tới ${widget.email}. Kiểm tra cả hộp thư Spam/Quảng cáo.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
    children: [
      Notice(tone: 'success', text: _info),
      Card(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Field(
              label: 'Mã xác thực (6 chữ số)',
              value: _code,
              onChangeText: (value) => setState(() => _code = value),
              placeholder: '123456',
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textInputAction: TextInputAction.go,
              onSubmit: (_) => _verify(),
            ),
            if (_error != null) Notice(tone: 'error', text: _error!),
            Button(
              title: 'Xác thực và đăng nhập',
              onPress: _verify,
              loading: _busy,
              disabled: _code.length != 6,
            ),
            if (_resending)
              Captcha(action: 'register', onToken: _resend)
            else
              Button(
                title: 'Gửi lại mã',
                kind: 'secondary',
                loading: _sending,
                onPress: () => setState(() => _resending = true),
              ),
            Button(title: 'Quay lại', kind: 'link', onPress: widget.onBack),
          ],
        ),
      ),
    ],
  );
}
