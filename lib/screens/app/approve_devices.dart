import 'package:ionicons/ionicons.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart' hide Card, Chip, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/devices.dart';
import '../../auth/session.dart';
import '../../auth/roles.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/theme.dart' as c;

void _openUser(BuildContext context, String id, String name) => context.push(
  Uri(
    path: '/duyet-thiet-bi',
    queryParameters: {'userId': id, 'name': name},
  ).toString(),
);

class ApproveDevicesScreen extends ConsumerStatefulWidget {
  const ApproveDevicesScreen({super.key, this.userId, this.name});
  final String? userId, name;
  @override
  ConsumerState<ApproveDevicesScreen> createState() => _DevicesState();
}

class _DevicesState extends ConsumerState<ApproveDevicesScreen> {
  String tab = 'pending', q = '', query = '';
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId;
    final anomalies = id == null && tab == 'anomalies';
    final provider = listDevicesProvider((status: tab, q: query));
    final list = anomalies
        ? null
        : id == null
        ? ref.watch(provider)
        : ref.watch(listUserDevicesProvider(id));
    final anomalyData = anomalies
        ? ref.watch(fetchDeviceAnomaliesProvider)
        : null;
    Future<void> refresh() async {
      if (anomalies) {
        return ref.refresh(fetchDeviceAnomaliesProvider.future).then((_) {});
      } else if (id != null) {
        return ref.refresh(listUserDevicesProvider(id).future).then((_) {});
      } else {
        return ref.refresh(provider.future).then((_) {});
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          id == null ? 'Duyệt thiết bị' : 'Thiết bị · ${widget.name ?? ''}',
        ),
      ),
      body: ListScreen<AdminDevice>(
        data: list?.value ?? const [],
        keyOf: (d) => d.id,
        renderItem: (d) => _DeviceCard(device: d, showUser: id == null),
        onRefresh: refresh,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            if (list?.hasError == true && list?.value?.isNotEmpty == true)
              ErrorBox(
                error: list!.error,
                onRetry: () => id == null
                    ? ref.invalidate(provider)
                    : ref.invalidate(listUserDevicesProvider(id)),
              ),
            if (id == null) ...[
              if (!anomalies)
                SearchBar(
                  value: q,
                  onChangeText: (v) => setState(() {
                    q = v;
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 400), () {
                      setState(() => query = v.trim());
                    });
                  }),
                  placeholder: 'Tìm theo email, họ tên, tên máy…',
                ),
              ChipRail(
                children: [
                  for (final (key, label) in [
                    ('pending', 'Chờ duyệt'),
                    ('approved', 'Đã duyệt'),
                    ('revoked', 'Đã thu hồi'),
                    ('', 'Tất cả'),
                    ('anomalies', 'Bất thường'),
                  ])
                    Chip(
                      label:
                          key == 'pending' && tab == key && list?.value != null
                          ? '$label · ${list!.value!.length}'
                          : label,
                      active: tab == key,
                      onPress: () => setState(() => tab = key),
                    ),
                ],
              ),
            ],
            if (anomalies)
              AsyncView(
                value: anomalyData!,
                onRetry: () => ref.invalidate(fetchDeviceAnomaliesProvider),
                builder: (a) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    if (a.sharedDevices.isEmpty && a.ipNetworks.isEmpty)
                      const Empty(
                        icon: Ionicons.shieldCheckmarkOutline,
                        text: 'Không có dấu hiệu bất thường.',
                      ),
                    if (a.sharedDevices.isNotEmpty)
                      const Muted('Một máy đăng nhập nhiều tài khoản'),
                    for (final s in a.sharedDevices)
                      Card(
                        children: [
                          Muted(
                            'Mã máy ${s.deviceId.length > 8 ? s.deviceId.substring(0, 8) : s.deviceId}…',
                          ),
                          for (final u in s.users)
                            _UserLink(id: u.id, name: u.fullName ?? u.email),
                        ],
                      ),
                    if (a.ipNetworks.isNotEmpty)
                      const Muted('Một tài khoản đăng nhập từ nhiều mạng'),
                    for (final n in a.ipNetworks)
                      Card(
                        children: [
                          if (n.user case final u?)
                            _UserLink(id: u.id, name: u.fullName ?? u.email),
                          Muted(n.networks.join(', ')),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
        empty: anomalies
            ? null
            : AsyncView(
                value: list!,
                onRetry: () {
                  if (id == null) {
                    ref.invalidate(provider);
                  } else {
                    ref.invalidate(listUserDevicesProvider(id));
                  }
                },
                builder: (_) => const Empty(
                  icon: Ionicons.phonePortraitOutline,
                  text: 'Không có thiết bị.',
                ),
              ),
      ),
    );
  }
}

class _UserLink extends StatelessWidget {
  const _UserLink({required this.id, required this.name});
  final String id, name;
  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: InkWell(
      onTap: () => _openUser(context, id, name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Body(
          name,
          style: const TextStyle(color: c.link, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({required this.device, required this.showUser});
  final AdminDevice device;
  final bool showUser;
  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard>
    with AutomaticKeepAliveClientMixin {
  String? mode;
  String text = '';
  bool busy = false;
  Object? failure;
  @override
  bool get wantKeepAlive => busy || mode != null || failure != null;
  Future<void> mutate(
    String action, [
    Map<String, Object?> body = const {},
  ]) async {
    if (busy) return;
    if (action == 'reject' &&
        (body['reason'] as String? ?? '').trim().isEmpty) {
      return;
    }
    if (action == 'allow_until' &&
        !can(ref.read(sessionProvider).roles, 'allow_device_exception')) {
      return;
    }
    setState(() {
      busy = true;
      failure = null;
    });
    updateKeepAlive();
    try {
      await ref.read(updateDeviceProvider)(widget.device.id, action, body);
      if (!mounted) return;
      setState(() {
        mode = null;
        text = '';
      });
      ref.invalidate(listDevicesProvider);
      ref.invalidate(listUserDevicesProvider);
      ref.invalidate(fetchDeviceAnomaliesProvider);
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        updateKeepAlive();
      }
    }
  }

  Future<void> run(String action) async {
    if (busy) return;
    if (action == 'reopen') {
      await mutate(action);
      return;
    }
    if (action == 'approve' || action == 'revoke') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(deviceActionLabel[action]!),
          content: Text(
            action == 'approve'
                ? 'Thiết bị cùng loại đang dùng sẽ bị thu hồi; các phiên trên đó sẽ kết thúc.'
                : 'Các phiên trên thiết bị này sẽ kết thúc ngay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            TextButton(
              style: action == 'revoke'
                  ? TextButton.styleFrom(foregroundColor: c.danger)
                  : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(deviceActionLabel[action]!),
            ),
          ],
        ),
      );
      if (yes == true && mounted) await mutate(action);
      return;
    }
    setState(() {
      text = '';
      mode = mode == action ? null : action;
    });
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = widget.device;
    final allowException = can(
      ref.watch(sessionProvider).roles,
      'allow_device_exception',
    );
    final u = d.user;
    final actions = deviceActions(d, allowException);
    return Card(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showUser && u != null)
                    _UserLink(id: u.id, name: u.fullName ?? u.email),
                  Muted(
                    [u?.email, u?.salesUnit?.name]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Pill(
                label: d.rejected
                    ? 'Đã từ chối'
                    : deviceStatusLabel[d.status] ?? d.status,
                soft: true,
                color: switch (d.status) {
                  'pending' => c.warn,
                  'approved' => c.success,
                  _ => c.muted,
                },
              ),
            ),
          ],
        ),
        Body(
          '${d.label ?? 'Thiết bị không tên'} · ${deviceKindLabel[d.kind] ?? 'Chưa rõ loại'}${d.self ? ' · máy của bạn' : ''}',
        ),
        Muted(
          'Lần đầu ${fmtDate(d.firstSeenAt, true)} · gần nhất ${fmtDate(d.lastSeenAt, true)}${d.lastIp?.isNotEmpty == true ? ' · IP ${d.lastIp}' : ''}',
        ),
        if (d.expiresAt?.isNotEmpty == true)
          Muted('Tạm thời đến ${fmtDate(d.expiresAt, true)}'),
        if (d.revokedReason?.isNotEmpty == true)
          Muted('Lý do: ${d.revokedReason}'),
        if (busy) const LinearProgressIndicator(),
        Chips(
          children: [
            for (final a in actions)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Chip(
                  label: deviceActionLabel[a]!,
                  active: mode == a,
                  onPress: busy ? null : () => run(a),
                ),
              ),
          ],
        ),
        if (mode == 'kind')
          Chips(
            children: [
              for (final k in ['mobile', 'desktop'])
                Chip(
                  label: deviceKindLabel[k]!,
                  active: d.kind == k,
                  onPress: busy
                      ? null
                      : () {
                          if (k != d.kind) mutate('kind', {'kind': k});
                        },
                ),
            ],
          ),
        if (mode == 'reject') ...[
          Field(
            label: 'Lý do từ chối',
            value: text,
            maxLength: 500,
            onChangeText: (v) => setState(() => text = v),
          ),
          Button(
            kind: 'danger',
            title: 'Từ chối thiết bị',
            disabled: text.trim().isEmpty,
            loading: busy,
            onPress: () => mutate('reject', {'reason': text.trim()}),
          ),
        ],
        if (mode == 'allow_until' && allowException) ...[
          Field(
            label: 'Cho dùng đến ngày (YYYY-MM-DD, tối đa 90 ngày)',
            value: text,
            placeholder: '2026-12-31',
            autocorrect: false,
            keyboardType: TextInputType.datetime,
            onChangeText: (v) => setState(() => text = v),
          ),
          Button(
            title: 'Cho phép tạm thời',
            disabled: !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text.trim()),
            loading: busy,
            onPress: () => mutate('allow_until', {'expires_at': text.trim()}),
          ),
        ],
        if (failure != null) Notice(tone: 'error', text: deviceError(failure!)),
      ],
    );
  }
}
