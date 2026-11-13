import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/auth/register.dart';

void main() {
  for (final input in [
    '0912 345 678',
    '+84 912.345.678',
    '84912345678',
    '(091) 234-5678',
  ]) {
    test(
      'normalizes $input',
      () => expect(normalizePhone(input), '0912345678'),
    );
  }
  for (final input in ['', '091234567', '1912345678', '0912abc678']) {
    test('rejects phone $input', () => expect(normalizePhone(input), isNull));
  }
  test('valid registration has no errors', () {
    expect(
      registerErrors(
        const RegisterForm(
          fullName: 'Nguyễn Minh',
          email: 'a@b.vn',
          phone: '0912345678',
          password: '1234567890',
        ),
        true,
      ),
      isEmpty,
    );
  });
  test('invalid registration identifies every field', () {
    expect(
      registerErrors(
        const RegisterForm(
          fullName: ' ',
          email: 'ab.vn',
          phone: '12',
          password: '123456789',
        ),
        false,
      ),
      {
        'full_name': 'Vui lòng nhập họ tên',
        'email': 'Email không hợp lệ',
        'phone': 'Số điện thoại chưa đúng, ví dụ 0912 345 678.',
        'password': 'Mật khẩu phải có ít nhất 10 ký tự',
        'consent': 'Bạn cần đồng ý với Chính sách bảo mật.',
      },
    );
  });
  test('email trims but rejects separators and whitespace', () {
    expect(emailValid(' a@b.vn '), isTrue);
    for (final input in ['a b@c.vn', 'a,b@c.vn', 'a;b@c.vn', 'a@@b.vn']) {
      expect(emailValid(input), isFalse);
    }
  });
}
