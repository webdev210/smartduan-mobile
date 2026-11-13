import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/auth/messages.dart';
import 'package:smartduan/auth/roles.dart';

void main() {
  test('superadmin inherits admin', () {
    expect(can(['superadmin'], 'manage_users'), isTrue);
    expect(scopeFor(['superadmin'], 'view_units'), 'all');
  });
  test('no roles has no sales floor; free sales public; F2 allocated', () {
    expect(screens['salesFloor']!([]), isFalse);
    expect(screens['becomeSales']!([]), isTrue);
    expect(isFreeSales(['sales_free']), isTrue);
    expect(screens['requestF2']!(['sales_free']), isTrue);
    expect(isPartner(['sales_partner']), isTrue);
    expect(scopeFor(['sales_partner'], 'view_units'), 'allocated');
  });
  test('only managers see team; F2 cannot access training', () {
    expect(screens['team']!(['manager']), isTrue);
    expect(screens['team']!(['agent']), isFalse);
    expect(screens['training']!(['sales_partner']), isFalse);
    expect(screens['training']!(['agent']), isTrue);
  });
  final cases = <(ApiError, String)>[
    (
      const ApiError(
        202,
        'device_pending',
        'msg',
        body: {
          'contact': {'name': 'Hà', 'phone': '0901'},
        },
      ),
      'Thiết bị đang chờ quản trị duyệt. Liên hệ: Hà — 0901',
    ),
    (
      const ApiError(400, 'device_required', 'msg'),
      'Không lấy được mã thiết bị, thử lại sau',
    ),
    (
      const ApiError(503, 'device_signing_unavailable', 'msg'),
      'Máy chủ tạm thời chưa cấp được mã thiết bị, thử lại sau',
    ),
    (
      const ApiError(401, 'invalid_credentials', 'msg'),
      'Email hoặc mật khẩu không đúng',
    ),
    (const ApiError(403, 'account_pending', 'msg'), 'Tài khoản đang chờ duyệt'),
    (const ApiError(403, 'account_rejected', 'msg'), 'Tài khoản đã bị từ chối'),
    (const ApiError(403, 'account_locked', 'msg'), 'Tài khoản đã bị khoá'),
    (
      const ApiError(403, 'email_unverified', 'msg'),
      'Email chưa được xác thực — kiểm tra hộp thư',
    ),
    (
      const ApiError(
        403,
        'email_domain_not_allowed',
        'msg',
        body: {
          'allowed_domains': ['a.vn', 'b.vn'],
        },
      ),
      'Email phải thuộc: a.vn, b.vn',
    ),
    (
      const ApiError(403, 'device_revoked', 'msg'),
      'Thiết bị đã bị thu hồi — liên hệ quản trị',
    ),
    (
      const ApiError(
        423,
        'account_temporarily_locked',
        'msg',
        body: {'message': 'Thử lại sau 5 phút.'},
      ),
      'Thử lại sau 5 phút.',
    ),
    (
      const ApiError(429, 'rate_limited', 'msg', retryAfter: 30),
      'Thử lại sau 30 giây',
    ),
    (
      const ApiError(0, 'network', 'Không kết nối được máy chủ'),
      'Không kết nối được máy chủ',
    ),
    (
      const ApiError(202, 'device_pending', 'msg'),
      'Thiết bị đang chờ quản trị duyệt.',
    ),
    (const ApiError(429, 'rate_limited', 'msg'), 'Thử lại sau 60 giây'),
    (const ApiError(403, 'email_domain_not_allowed', 'msg'), 'msg'),
  ];
  for (final (error, expected) in cases) {
    test('login ${error.status}/${error.code}: $expected', () {
      final outcome = loginOutcome(error);
      expect(outcome, isA<LoginMessage>());
      expect(outcome.message, expected);
    });
  }
  test('pending verification selects OTP and email', () {
    final outcome = loginOutcome(
      const ApiError(
        403,
        'pending_verification',
        'msg',
        body: {'email': 'a@b.vn'},
      ),
    );
    expect(outcome, isA<LoginOtp>());
    expect((outcome as LoginOtp).email, 'a@b.vn');
    expect(
      outcome.message,
      'Tài khoản chưa xác thực. Mã OTP mới đã được gửi tới email của bạn.',
    );
  });
  test('unknown error uses generic message', () {
    expect(
      loginOutcome(Exception('secret')).message,
      'Có lỗi xảy ra, thử lại sau',
    );
  });
  final reasons = <String?, String?>{
    null: null,
    '': null,
    'logout_local': null,
    'f2_approved': 'Tài khoản đã lên F2, đăng nhập lại để dùng quyền mới',
    'role_changed': 'Vai trò đã thay đổi, vui lòng đăng nhập lại',
    'locked': 'Tài khoản bị khoá',
    'rejected': 'Tài khoản đã bị từ chối',
    'password_reset': 'Mật khẩu vừa được đổi, vui lòng đăng nhập lại',
    'logout': 'Bạn đã đăng xuất khỏi mọi thiết bị',
    'device_revoked':
        'Thiết bị đã bị thu hồi — liên hệ quản trị rồi đăng nhập lại',
    'whatever': 'Phiên đã hết hạn',
  };
  for (final MapEntry(:key, :value) in reasons.entries) {
    test('session ended $key', () => expect(sessionEndedMessage(key), value));
  }
}
