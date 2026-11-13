import 'package:material_ui/material_ui.dart' hide Card, Divider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../api/me.dart';
import '../../api/devices.dart' show deviceStatusLabel;
import '../../api/errors.dart';
import '../../auth/session.dart';
import '../../auth/roles.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/kit.dart' as kit show Row;
import '../../ui/regions.dart';
import '../../ui/theme.dart' as c;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  bool allDownloads = false;
  String? removing;
  Object? failure;
  Future<bool> confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> remove(String id) async {
    if (removing != null) return;
    if (!await confirm(
          'Gỡ thiết bị này?',
          'Thiết bị sẽ bị xoá khỏi danh sách thiết bị đăng nhập của bạn.',
          'Gỡ',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      removing = id;
      failure = null;
    });
    try {
      await ref.read(removeDeviceProvider)(id);
      if (mounted) ref.invalidate(fetchDevicesProvider);
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => removing = null);
    }
  }

  Future<void> refresh() async {
    ref.invalidate(fetchProfileProvider);
    ref.invalidate(fetchDevicesProvider);
    ref.invalidate(fetchDownloadsProvider);
    await Future.wait([
      ref.read(fetchProfileProvider.future),
      ref.read(fetchDevicesProvider.future),
      ref.read(fetchDownloadsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ')),
    body: Screen(
      onRefresh: refresh,
      children: [
        AsyncView(
          value: ref.watch(fetchProfileProvider),
          onRetry: () => ref.invalidate(fetchProfileProvider),
          builder: (p) => Column(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                children: [
                  Row(
                    spacing: 14,
                    children: [
                      Avatar(name: p.fullName ?? p.email, size: 60),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.fullName ?? p.email,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (p.fullName?.isNotEmpty == true) Muted(p.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: p.roles.isEmpty
                        ? [
                            const Pill(
                              label: 'Chưa có vai trò',
                              color: c.muted,
                              soft: true,
                            ),
                          ]
                        : [
                            for (final r in p.roles)
                              Pill(
                                label: roleName(r),
                                color: c.brand,
                                soft: true,
                              ),
                          ],
                  ),
                ],
              ),
              Section(
                title: 'Thông tin',
                child: Card(
                  children: [
                    kit.Row(label: 'Điện thoại', value: p.phone ?? '—'),
                    kit.Row(label: 'Mã sales', value: p.salesCode ?? '—'),
                    kit.Row(label: 'Chi nhánh', value: p.branch?.name ?? '—'),
                    kit.Row(label: 'Đại lý', value: p.salesUnit?.name ?? '—'),
                    kit.Row(
                      label: 'Miền',
                      value: p.region == null
                          ? 'Chưa chọn'
                          : regions
                                    .where((r) => r.key == p.region)
                                    .firstOrNull
                                    ?.label ??
                                '—',
                    ),
                    kit.Row(
                      label: 'Dự án quan tâm',
                      value: '${p.interestedProjectIds.length}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Card(
          padding: EdgeInsets.zero,
          children: [
            ListItem(
              icon: Ionicons.heartOutline,
              title: 'Dự án quan tâm',
              subtitle: 'Chọn miền và dự án để nhận thông báo',
              onPress: () => context.push('/quan-tam'),
            ),
            const Divider(),
            ListItem(
              icon: Ionicons.documentLockOutline,
              title: 'Chính sách bảo vệ dữ liệu',
              subtitle: 'Toàn văn chính sách đang áp dụng',
              onPress: () => context.push('/chinh-sach-bao-mat'),
            ),
          ],
        ),
        Section(
          title: 'Thiết bị đăng nhập',
          children: [
            Card(
              padding: EdgeInsets.zero,
              child: AsyncView(
                value: ref.watch(fetchDevicesProvider),
                onRetry: () => ref.invalidate(fetchDevicesProvider),
                builder: (devices) => devices.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Muted(
                          'Không có thiết bị nào được ghi nhận (máy chủ chưa bật kiểm soát thiết bị).',
                        ),
                      )
                    : Column(
                        children: [
                          for (final (i, d) in devices.indexed) ...[
                            if (i > 0) const Divider(),
                            ListItem(
                              icon: Ionicons.phonePortraitOutline,
                              title: d.label ?? d.kind ?? 'Thiết bị',
                              subtitle:
                                  '${deviceStatusLabel[d.status] ?? d.status} · lần cuối ${fmtDate(d.lastSeenAt, true)}',
                              right: Button(
                                kind: 'link',
                                title: 'Gỡ',
                                accessibilityLabel:
                                    'Gỡ thiết bị ${d.label ?? d.kind ?? ''}',
                                loading: removing == d.id,
                                disabled: removing != null,
                                onPress: () => remove(d.id),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            if (failure != null)
              Notice(tone: 'error', text: errorMessage(failure)),
          ],
        ),
        Section(
          title: 'Tài liệu đã tải',
          child: Card(
            child: AsyncView(
              value: ref.watch(fetchDownloadsProvider),
              onRetry: () => ref.invalidate(fetchDownloadsProvider),
              builder: (list) => list.isEmpty
                  ? const Muted('Chưa tải tài liệu nào.')
                  : Column(
                      children: [
                        Muted(
                          'Hiển thị ${allDownloads
                              ? list.length
                              : list.length > 10
                              ? 10
                              : list.length}/${list.length} lượt tải gần nhất',
                        ),
                        for (final d in allDownloads ? list : list.take(10))
                          kit.Row(
                            label: d.documentTitle,
                            value: fmtDate(d.downloadedAt ?? d.requestedAt),
                          ),
                        if (list.length > 10)
                          Button(
                            title: allDownloads
                                ? 'Thu gọn'
                                : 'Xem thêm (${list.length - 10})',
                            kind: 'link',
                            onPress: () =>
                                setState(() => allDownloads = !allDownloads),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        Button(
          kind: 'secondary',
          icon: Ionicons.logOutOutline,
          title: 'Đăng xuất',
          onPress: () => ref.read(sessionProvider.notifier).signOut(),
        ),
        Button(
          kind: 'danger',
          icon: Ionicons.shieldOutline,
          title: 'Đăng xuất mọi thiết bị',
          onPress: () async {
            if (await confirm(
                  'Đăng xuất mọi thiết bị',
                  'Mọi phiên đăng nhập (web và app) sẽ hết hiệu lực ngay.',
                  'Đăng xuất hết',
                ) &&
                mounted) {
              await ref
                  .read(sessionProvider.notifier)
                  .signOut(everywhere: true);
            }
          },
        ),
      ],
    ),
  );
}
