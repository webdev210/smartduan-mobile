import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../auth/register.dart';
import '../../auth/session.dart';
import '../../ui/captcha.dart';
import '../../ui/kit.dart' show Screen, Muted, Card, Field, Notice, Button;

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  String _email = '';
  String? _token, _error, _sent;
  bool _busy = false;
  int _captchaKey = 0;

  Future<void> _submit() async {
    if (_busy) return;
    if (!emailValid(_email)) {
      setState(() => _error = 'Email không hợp lệ');
      return;
    }
    final token = _token;
    if (token == null) return;
    final to = _email.trim().toLowerCase();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).forgotPassword(to, token);
      if (mounted) setState(() => _sent = to);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _token = null;
          _captchaKey++;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
    children: [
      if (_sent != null)
        Notice(
          tone: 'success',
          text:
              'Nếu $_sent có tài khoản, link đặt lại mật khẩu đã được gửi tới email này. Link dùng một lần và hết hạn sau 60 phút. Đặt xong quay lại app đăng nhập bằng mật khẩu mới.',
        )
      else
        const Muted(
          'Nhập email đăng ký, chúng tôi sẽ gửi link đặt lại mật khẩu.',
        ),
      Card(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Field(
              label: 'Email',
              value: _email,
              onChangeText: (v) => setState(() {
                _email = v;
                _error = null;
              }),
              placeholder: 'ten@congty.vn',
              autoCapitalize: TextCapitalization.none,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              maxLength: 254,
            ),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  // ponytail: CAPTCHA retry row has an intrinsic-width button; remove when shared CAPTCHA wraps it.
                  width: MediaQuery.textScalerOf(context)
                      .scale(220)
                      .clamp(constraints.maxWidth, double.infinity),
                  child: Captcha(
                    key: ValueKey(_captchaKey),
                    action: 'forgot-password',
                    onToken: (token) {
                      if (mounted) setState(() => _token = token);
                    },
                  ),
                ),
              ),
            ),
            if (_error != null) Notice(tone: 'error', text: _error!),
            Button(
              title: _token == null
                  ? 'Đang chờ xác minh…'
                  : _sent == null
                  ? 'Gửi link đặt lại'
                  : 'Gửi lại link',
              onPress: _submit,
              loading: _busy,
              disabled: _token == null || _email.isEmpty,
            ),
          ],
        ),
      ),
    ],
  );
}
