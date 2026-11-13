import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'errors.dart';
import 'models.dart';
import 'projects.dart' show signedInClient, sessionQuery, sessionQueryFamily;

export 'models.dart'
    show
        AdminDevice,
        DeviceUser,
        DeviceAnomalies,
        AnomalyUser,
        SharedDevice,
        IpNetwork;

typedef DeviceStatus = String;
typedef DeviceKind = String;
typedef DeviceAction = String;
typedef DeviceFilter = ({String status, String q});
const deviceStatusLabel = {
  'pending': 'Chờ duyệt',
  'approved': 'Đã duyệt',
  'revoked': 'Đã thu hồi',
};
const deviceKindLabel = {'mobile': 'Di động', 'desktop': 'Máy tính'};
const deviceActionLabel = {
  'approve': 'Duyệt và thay thế',
  'reject': 'Từ chối',
  'reopen': 'Mở lại',
  'revoke': 'Thu hồi',
  'kind': 'Đổi loại',
  'allow_until': 'Cho thêm tạm thời đến…',
};

List<DeviceAction> deviceActions(
  AdminDevice d,
  bool allowException, [
  DateTime? now,
]) {
  final expiry = d.expiresAt == null ? null : DateTime.tryParse(d.expiresAt!);
  if (expiry != null && !expiry.isAfter(now ?? DateTime.now())) return [];
  if (d.self) return d.status == 'revoked' ? [] : ['revoke'];
  return switch (d.status) {
    'revoked' => d.rejected ? ['reopen'] : [],
    'pending' => ['approve', 'reject', 'kind'],
    _ => ['revoke', 'kind', if (allowException) 'allow_until'],
  };
}

String deviceError(Object e) => switch (e) {
  ApiError(:final code) => _deviceCodes[code] ?? errorMessage(e),
  _ => errorMessage(e),
};
const _deviceCodes = {
  'limit': 'Người này đã có đủ 2 thiết bị cố định khác — thu hồi bớt trước khi duyệt.',
  'reason_required': 'Cần nhập lý do.',
  'invalid_transition': 'Thiết bị đã đổi trạng thái — kéo xuống để làm mới.',
  'invalid_kind': 'Loại thiết bị không hợp lệ.',
  'invalid_status': 'Trạng thái lọc không hợp lệ.',
  'invalid_expiry':
      'Ngày hết hạn phải ở tương lai, tối đa 90 ngày (định dạng YYYY-MM-DD).',
};

class DevicesApi {
  const DevicesApi(this.client);
  final ApiClient client;
  Future<List<AdminDevice>> listDevices([
    String status = 'pending',
    String q = '',
  ]) async => jsonList(
    jsonObject(
      await client.get('/admin/devices', {
        if (status.isNotEmpty) 'status': status,
        if (q.trim().isNotEmpty) 'q': q.trim(),
      }),
    )['data'],
    AdminDevice.fromJson,
  );
  Future<List<AdminDevice>> listUserDevices(String userId) async => jsonList(
    jsonObject(await client.get('/admin/users/$userId/devices'))['data'],
    AdminDevice.fromJson,
  );
  Future<DeviceAnomalies> fetchDeviceAnomalies() async =>
      DeviceAnomalies.fromJson(
        jsonObject(await client.get('/admin/devices/anomalies')),
      );
  Future<AdminDevice> updateDevice(
    String id,
    DeviceAction action, [
    Map<String, Object?> body = const {},
  ]) async => AdminDevice.fromJson(
    jsonObject(await client.post('/admin/devices/$id/$action', body)),
  );
}

final devicesApiProvider = Provider.autoDispose(
  (ref) => DevicesApi(signedInClient(ref)),
);
final listDevicesProvider = sessionQueryFamily<List<AdminDevice>, DeviceFilter>(
  (ref, f) => ref.watch(devicesApiProvider).listDevices(f.status, f.q),
);
final listUserDevicesProvider = sessionQueryFamily<List<AdminDevice>, String>(
  (ref, id) => ref.watch(devicesApiProvider).listUserDevices(id),
);
final fetchDeviceAnomaliesProvider = sessionQuery(
  (ref) => ref.watch(devicesApiProvider).fetchDeviceAnomalies(),
);
final updateDeviceProvider = Provider.autoDispose(
  (ref) => ref.watch(devicesApiProvider).updateDevice,
);
