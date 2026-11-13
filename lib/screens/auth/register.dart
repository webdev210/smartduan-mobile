import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/public.dart';
import '../../auth/register.dart';
import '../../auth/session.dart';
import '../../ui/captcha.dart';
import '../../ui/kit.dart'
    show Screen, Muted, Card, Field, Notice, Button, AsyncView;
import '../../ui/otp_step.dart';
import '../../ui/theme.dart' as theme;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = {'full_name': '', 'email': '', 'phone': '', 'password': ''};
  late final _focus = {for (final field in _form.keys) field: FocusNode()};
  late final _keys = {
    for (final field in [..._form.keys, 'consent']) field: GlobalKey(),
  };
  Map<String, String> _fieldErrors = {};
  String? _token, _error, _sentTo;
  bool _consent = false, _busy = false;
  int _captchaKey = 0;
  late final _privacyLink = TapGestureRecognizer()
    ..onTap = () => context.push('/chinh-sach-bao-mat');

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    _privacyLink.dispose();
    super.dispose();
  }

  void _set(String field, String value) => setState(() {
    _form[field] = value;
    _fieldErrors.remove(field);
  });

  void _revealError() {
    final field = _keys.keys.where(_fieldErrors.containsKey).firstOrNull;
    if (field == null) return;
    _focus[field]?.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[field]?.currentContext;
      if (mounted && target != null) Scrollable.ensureVisible(target);
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final errors = registerErrors(
      RegisterForm(
        fullName: _form['full_name']!,
        email: _form['email']!,
        phone: _form['phone']!,
        password: _form['password']!,
      ),
      _consent,
    );
    setState(() => _fieldErrors = errors);
    _revealError();
    final version = ref.read(fetchPrivacyPolicyProvider).asData?.value.version;
    final token = _token;
    if (errors.isNotEmpty ||
        version == null ||
        version.isEmpty ||
        token == null) {
      return;
    }
    final email = _form['email']!.trim().toLowerCase();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).register({
        'full_name': _form['full_name']!.trim(),
        'email': email,
        'phone': normalizePhone(_form['phone']!)!,
        'password': _form['password']!,
        'consent_version': version,
        'turnstile_token': token,
      });
      if (mounted) setState(() => _sentTo = email);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error case ApiError(code: 'consent_required')) {
          _fieldErrors = {'consent': consentRequired};
        } else {
          _fieldErrors = {
            for (final field in _form.keys)
              if (fieldError(error, field) case final String message)
                field: message,
          };
          _error = errorMessage(error);
        }
      });
      _revealError();
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
  Widget build(BuildContext context) {
    final policy = ref.watch(fetchPrivacyPolicyProvider);
    final version = policy.asData?.value.version;
    if (_sentTo != null) {
      return OtpStep(
        email: _sentTo!,
        password: _form['password']!,
        notice:
            'Mã xác thực đã gửi tới email $_sentTo. Kiểm tra cả hộp thư Spam/Quảng cáo.',
        onBack: () => setState(() => _sentTo = null),
      );
    }
    return AutofillGroup(
      child: Screen(
        children: [
          const Muted(
            'Tài khoản miễn phí cho chuyên viên kinh doanh, xác nhận bằng mã OTP gửi qua email. Sau đó đăng ký làm sale tự do ở Menu.',
            style: TextStyle(fontSize: 15),
          ),
          Card(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Field(
                  key: _keys['full_name'],
                  focusNode: _focus['full_name'],
                  textInputAction: TextInputAction.next,
                  onSubmit: (_) => _focus['email']!.requestFocus(),
                  label: 'Họ và tên',
                  value: _form['full_name'],
                  onChangeText: (v) => _set('full_name', v),
                  error: _fieldErrors['full_name'],
                  placeholder: 'Nguyễn Minh…',
                  autofillHints: const [AutofillHints.name],
                  maxLength: 120,
                ),
                Field(
                  key: _keys['email'],
                  focusNode: _focus['email'],
                  textInputAction: TextInputAction.next,
                  onSubmit: (_) => _focus['phone']!.requestFocus(),
                  label: 'Email',
                  value: _form['email'],
                  onChangeText: (v) => _set('email', v),
                  error: _fieldErrors['email'],
                  placeholder: 'ten@congty.vn',
                  autoCapitalize: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  maxLength: 254,
                ),
                Field(
                  key: _keys['phone'],
                  focusNode: _focus['phone'],
                  textInputAction: TextInputAction.next,
                  onSubmit: (_) => _focus['password']!.requestFocus(),
                  label: 'Số điện thoại',
                  value: _form['phone'],
                  onChangeText: (v) => _set('phone', v),
                  error: _fieldErrors['phone'],
                  placeholder: '0901 234 567',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  maxLength: 20,
                ),
                Field(
                  key: _keys['password'],
                  focusNode: _focus['password'],
                  textInputAction: TextInputAction.done,
                  onSubmit: (_) => _submit(),
                  label: 'Mật khẩu (ít nhất 10 ký tự)',
                  value: _form['password'],
                  onChangeText: (v) => _set('password', v),
                  error: _fieldErrors['password'],
                  placeholder: '••••••••••',
                  obscureText: true,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newPassword],
                  maxLength: 128,
                ),
                Row(
                  key: _keys['consent'],
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 12,
                  children: [
                    Semantics(
                      label: 'Đồng ý Chính sách bảo mật',
                      child: Switch(
                        value: _consent,
                        onChanged: (v) => setState(() {
                          _consent = v;
                          _fieldErrors.remove('consent');
                        }),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Tôi đồng ý cho Smart Dự Án xử lý dữ liệu cá nhân theo ',
                          children: [
                            TextSpan(
                              text: 'Chính sách bảo mật',
                              semanticsLabel: 'Chính sách bảo mật',
                              style: const TextStyle(
                                color: theme.link,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: _privacyLink,
                            ),
                            if (version != null && version.isNotEmpty)
                              TextSpan(text: ' (phiên bản $version)'),
                          ],
                        ),
                        style: const TextStyle(
                          color: theme.text,
                          fontSize: 15,
                          height: 22 / 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_fieldErrors['consent'] case final String message)
                  Notice(tone: 'error', text: message),
                if (policy.hasError) ...[
                  const Notice(
                    tone: 'error',
                    text: 'Chưa tải được phiên bản chính sách bảo mật.',
                  ),
                  Button(
                    title: 'Tải lại',
                    kind: 'link',
                    onPress: () => ref.invalidate(fetchPrivacyPolicyProvider),
                  ),
                ] else if (policy.isLoading)
                  AsyncView(
                    value: policy,
                    builder: (_) => const SizedBox.shrink(),
                  ),
                Captcha(
                  key: ValueKey(_captchaKey),
                  action: 'register',
                  onToken: (token) {
                    if (mounted) setState(() => _token = token);
                  },
                ),
                if (_error != null) Notice(tone: 'error', text: _error!),
                Button(
                  title: _token != null
                      ? 'Đăng ký và xác thực'
                      : 'Đang chờ xác minh…',
                  onPress: _submit,
                  loading: _busy,
                  disabled:
                      _token == null || version == null || version.isEmpty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
