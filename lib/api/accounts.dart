import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'errors.dart';
import 'models.dart';
import 'projects.dart' show signedInClient, sessionQueryFamily;

export 'models.dart' show AdminUser;

typedef UserStatus = String;
typedef AccountAction = String;
typedef UserFilter = ({String status, bool f2, String q});

const userStatusLabel = {
  'pending': 'Chờ duyệt',
  'active': 'Đang hoạt động',
  'locked': 'Đã khoá',
  'rejected': 'Đã từ chối',
};
const accountActionLabel = {
  'approve': 'Duyệt',
  'reject': 'Từ chối',
  'lock': 'Khoá',
  'unlock': 'Mở khoá',
};

bool unverified(AdminUser u) =>
    u.status == 'pending' &&
    (u.emailVerifiedAt == null || u.emailVerifiedAt!.isEmpty) &&
    (u.phoneVerifiedAt == null || u.phoneVerifiedAt!.isEmpty);
String statusLabel(AdminUser u) =>
    unverified(u) ? 'Chưa xác thực' : userStatusLabel[u.status] ?? u.status;

List<AccountAction> accountActions(
  AdminUser u,
  bool canManageUsers,
  bool viewerIsSuper,
) {
  if (u.roles.contains('superadmin') && !viewerIsSuper) return [];
  final ready = u.status == 'pending' && !unverified(u);
  return [
    if (ready ||
        u.status == 'rejected' ||
        (u.f2RequestedAt?.isNotEmpty ?? false))
      'approve',
    if (ready || u.status == 'active') 'reject',
    if (canManageUsers && u.status == 'active') 'lock',
    if (canManageUsers && u.status == 'locked') 'unlock',
  ];
}

String accountError(Object e) => switch (e) {
  ApiError(:final code) => _accountCodes[code] ?? errorMessage(e),
  _ => errorMessage(e),
};
const _accountCodes = {
  'invalid_transition':
      'Trạng thái tài khoản đã thay đổi. Kéo xuống để tải lại danh sách.',
  'phone_not_verified':
      'Tài khoản chưa xác thực số điện thoại nên chưa duyệt được.',
  'reason_required': 'Nhập lý do từ chối.',
  'not_found': 'Không tìm thấy tài khoản trong phạm vi bạn được duyệt.',
};

class AccountsApi {
  const AccountsApi(this.client);
  final ApiClient client;
  Future<List<AdminUser>> listUsers({
    String status = '',
    bool f2 = false,
    String q = '',
  }) async => jsonList(
    jsonObject(
      await client.get('/users', {
        'status': status.isEmpty ? 'all' : status,
        if (f2) 'f2_requested': 'true',
        if (q.trim().isNotEmpty) 'q': q.trim(),
      }),
    )['data'],
    AdminUser.fromJson,
  );
  Map<String, Object?> _f2Version(AdminUser u) => {
    if (u.f2RequestedAt?.isNotEmpty ?? false)
      'f2_request_version': u.f2RequestVersion,
  };
  Future<Object?> approveUser(AdminUser u) => client.post(
    '/auth/admin/users/${u.id}/approve',
    (u.f2RequestedAt?.isNotEmpty ?? false) ? _f2Version(u) : null,
  );
  Future<Object?> rejectUser(AdminUser u, String reason) => client.post(
    '/auth/admin/users/${u.id}/reject',
    {'reason': reason, ..._f2Version(u)},
  );
  Future<Object?> lockUser(String id) =>
      client.post('/auth/admin/users/$id/lock');
  Future<Object?> unlockUser(String id) =>
      client.post('/auth/admin/users/$id/unlock');
}

final accountsApiProvider = Provider.autoDispose(
  (ref) => AccountsApi(signedInClient(ref)),
);
final listUsersProvider = sessionQueryFamily<List<AdminUser>, UserFilter>(
  (ref, f) => ref
      .watch(accountsApiProvider)
      .listUsers(status: f.status, f2: f.f2, q: f.q),
);
final approveUserProvider = Provider.autoDispose(
  (ref) => ref.watch(accountsApiProvider).approveUser,
);
final rejectUserProvider = Provider.autoDispose(
  (ref) => ref.watch(accountsApiProvider).rejectUser,
);
final lockUserProvider = Provider.autoDispose(
  (ref) => ref.watch(accountsApiProvider).lockUser,
);
final unlockUserProvider = Provider.autoDispose(
  (ref) => ref.watch(accountsApiProvider).unlockUser,
);
