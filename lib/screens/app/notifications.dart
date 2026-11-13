import 'package:material_ui/material_ui.dart'
    hide Card, SearchBar, Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../api/sales.dart';
import '../../api/errors.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/search.dart';
import '../../ui/theme.dart' as c;

String? notificationRoute(String? href) {
  if (href == null) return null;
  final ann = RegExp(r'/sales/bang-tin/([^/?#]+)').firstMatch(href);
  if (ann != null) return '/bang-tin/${Uri.encodeComponent(ann[1]!)}';
  if (href.startsWith('/sales/ho-so')) return '/ho-so';
  if (href.startsWith('/sales/bang-tin')) return '/bang-tin';
  return null;
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  String q = '', only = 'all';
  bool marking = false;
  String? failure;
  Future<void> mark([List<String>? ids]) async {
    if (marking) return;
    setState(() {
      marking = true;
      failure = null;
    });
    try {
      await ref.read(markNotificationsReadProvider)(ids);
      if (mounted) ref.invalidate(fetchNotificationsProvider);
    } catch (e) {
      if (mounted) setState(() => failure = errorMessage(e));
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(fetchNotificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: ListScreen<Notification>(
        data: smartFilter(
          (list.value?.data ?? [])
              .where(
                (n) => only == 'all' || n.readAt == null || n.readAt!.isEmpty,
              )
              .toList(),
          q,
          (n) => [n.title],
        ),
        keyOf: (n) => n.id,
        top: SearchBar(
          value: q,
          onChangeText: (v) => setState(() => q = v),
          placeholder: 'Tìm trong thông báo…',
        ),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.hasError && list.value?.data.isNotEmpty == true)
              ErrorBox(
                error: list.error,
                onRetry: () => ref.invalidate(fetchNotificationsProvider),
              ),
            if (list.value?.data.isNotEmpty == true) ...[
              Segmented(
                value: only,
                onChange: (v) => setState(() => only = v),
                options: [
                  (key: 'all', label: 'Tất cả', count: list.value!.data.length),
                  (key: 'unread', label: 'Chưa đọc', count: list.value!.unread),
                ],
              ),
              if (list.value!.unread > 0)
                Button(
                  kind: 'link',
                  icon: Ionicons.checkmarkDone,
                  title: 'Đánh dấu đã đọc tất cả',
                  loading: marking,
                  onPress: mark,
                ),
            ],
            if (failure != null) Notice(tone: 'error', text: failure!),
          ],
        ),
        empty: AsyncView(
          value: list,
          onRetry: () => ref.invalidate(fetchNotificationsProvider),
          builder: (_) => q.trim().isNotEmpty
              ? Empty(
                  icon: Ionicons.searchOutline,
                  text: 'Không có thông báo nào khớp “${q.trim()}”.',
                  action: (
                    label: 'Xoá từ khoá',
                    onPress: () => setState(() => q = ''),
                  ),
                )
              : only == 'unread'
              ? Empty(
                  icon: Ionicons.checkmarkDoneOutline,
                  text: 'Bạn đã đọc hết thông báo.',
                  action: (
                    label: 'Xem tất cả',
                    onPress: () => setState(() => only = 'all'),
                  ),
                )
              : const Empty(
                  icon: Ionicons.notificationsOffOutline,
                  text: 'Chưa có thông báo.',
                ),
        ),
        renderItem: (n) {
          final unread = n.readAt == null || n.readAt!.isEmpty;
          final route = notificationRoute(n.href);
          return Card(
            onPress: route == null && !unread
                ? null
                : () {
                    if (unread) mark([n.id]);
                    if (route != null) context.push(route);
                  },
            accessibilityLabel: '${unread ? 'Chưa đọc. ' : ''}${n.title}',
            style: BoxDecoration(color: unread ? c.brandSoft : c.card),
            child: Row(
              spacing: 12,
              children: [
                Icon(
                  unread
                      ? Ionicons.notifications
                      : Ionicons.notificationsOutline,
                  color: unread ? c.brand : c.muted,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      Muted(fmtDate(n.insertedAt, true)),
                      if (route == null) const Muted('Chỉ thông báo'),
                    ],
                  ),
                ),
                if (route != null)
                  const Icon(Ionicons.chevronForward, size: 18),
              ],
            ),
          );
        },
        onRefresh: () => ref.refresh(fetchNotificationsProvider.future),
      ),
    );
  }
}
