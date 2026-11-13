import '../api/errors.dart';

sealed class LoginOutcome {
  const LoginOutcome(this.message);
  final String message;
}

final class LoginMessage extends LoginOutcome {
  const LoginMessage(super.message);
}

final class LoginOtp extends LoginOutcome {
  const LoginOtp(super.message, this.email);
  final String? email;
}

const _accountState = {
  'account_pending': 'Tài khoản đang chờ duyệt',
  'account_rejected': 'Tài khoản đã bị từ chối',
  'account_locked': 'Tài khoản đã bị khoá',
  'email_unverified': 'Email chưa được xác thực — kiểm tra hộp thư',
  'device_revoked': 'Thiết bị đã bị thu hồi — liên hệ quản trị',
  'device_required': 'Không lấy được mã thiết bị, thử lại sau',
  'device_signing_unavailable':
      'Máy chủ tạm thời chưa cấp được mã thiết bị, thử lại sau',
};

LoginOutcome loginOutcome(Object? error) {
  if (error is! ApiError) {
    return const LoginMessage('Có lỗi xảy ra, thử lại sau');
  }
  final ApiError(:status, :code, :body, :retryAfter) = error;
  final data = body is Map<String, dynamic> ? body : <String, dynamic>{};
  if (status == 202 || code == 'device_pending') {
    final contact = data['contact'];
    final who = contact is Map<String, dynamic>
        ? ' Liên hệ: ${[contact['name'], contact['phone']].whereType<String>().where((s) => s.isNotEmpty).join(' — ')}'
        : '';
    return LoginMessage('Thiết bị đang chờ quản trị duyệt.$who');
  }
  if (status == 401 || code == 'invalid_credentials') {
    return const LoginMessage('Email hoặc mật khẩu không đúng');
  }
  if (code == 'pending_verification') {
    return LoginOtp(
      'Tài khoản chưa xác thực. Mã OTP mới đã được gửi tới email của bạn.',
      data['email'] is String ? data['email'] as String : null,
    );
  }
  if (code == 'email_domain_not_allowed') {
    final domains = data['allowed_domains'];
    return LoginMessage(
      domains is List &&
              domains.isNotEmpty &&
              domains.every((dynamic d) => d is String)
          ? 'Email phải thuộc: ${domains.join(', ')}'
          : error.message,
    );
  }
  if (_accountState[code] case final String message) {
    return LoginMessage(message);
  }
  if (status == 423) {
    return LoginMessage(
      data['message'] is String ? data['message'] as String : error.message,
    );
  }
  if (status == 429) {
    return LoginMessage('Thử lại sau ${retryAfter ?? 60} giây');
  }
  return LoginMessage(error.message);
}

String? sessionEndedMessage(String? reason) => switch (reason) {
  null || '' || 'logout_local' => null,
  'f2_approved' => 'Tài khoản đã lên F2, đăng nhập lại để dùng quyền mới',
  'role_changed' => 'Vai trò đã thay đổi, vui lòng đăng nhập lại',
  'locked' => 'Tài khoản bị khoá',
  'rejected' => 'Tài khoản đã bị từ chối',
  'password_reset' => 'Mật khẩu vừa được đổi, vui lòng đăng nhập lại',
  'logout' => 'Bạn đã đăng xuất khỏi mọi thiết bị',
  'device_revoked' =>
    'Thiết bị đã bị thu hồi — liên hệ quản trị rồi đăng nhập lại',
  _ => 'Phiên đã hết hạn',
};
