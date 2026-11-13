const minPassword = 10;
const consentRequired = 'Bạn cần đồng ý với Chính sách bảo mật.';

class RegisterForm {
  const RegisterForm({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });
  final String fullName;
  final String email;
  final String phone;
  final String password;
}

String? normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[\s.()-]'), '');
  final local = digits.startsWith('+84')
      ? '0${digits.substring(3)}'
      : digits.startsWith('84') && digits.length == 11
      ? '0${digits.substring(2)}'
      : digits;
  return RegExp(r'^0\d{9}$').hasMatch(local) ? local : null;
}

bool emailValid(String value) =>
    RegExp(r'^[^@,;\s]+@[^@,;\s]+$').hasMatch(value.trim());

Map<String, String> registerErrors(RegisterForm form, bool consent) => {
  if (form.fullName.trim().isEmpty) 'full_name': 'Vui lòng nhập họ tên',
  if (!emailValid(form.email)) 'email': 'Email không hợp lệ',
  if (normalizePhone(form.phone) == null)
    'phone': 'Số điện thoại chưa đúng, ví dụ 0912 345 678.',
  if (form.password.length < minPassword)
    'password': 'Mật khẩu phải có ít nhất $minPassword ký tự',
  if (!consent) 'consent': consentRequired,
};
