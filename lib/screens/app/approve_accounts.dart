import 'package:ionicons/ionicons.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart' hide Card, Chip, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/accounts.dart';
import '../../auth/session.dart';
import '../../auth/roles.dart' as roles;
import '../../ui/format.dart' show fmtDate;
import '../../ui/kit.dart' hide Row;
import '../../ui/theme.dart' as c;

const _tabs = {
  'pending': 'Chờ duyệt',
  'f2': 'Xin lên F2',
  'active': 'Đang hoạt động',
  'locked': 'Đã khoá',
  'rejected': 'Đã từ chối',
  'all': 'Tất cả',
};

class ApproveAccountsScreen extends ConsumerStatefulWidget {
  const ApproveAccountsScreen({super.key});
  @override
  ConsumerState<ApproveAccountsScreen> createState() => _AccountsState();
}

class _AccountsState extends ConsumerState<ApproveAccountsScreen> {
  String tab = 'pending', q = '', query = '';
  Timer? debounce;
  int shown = 30;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = roles.can(
      ref.watch(sessionProvider).roles,
      'manage_users',
    );
    final selected = canManage ? tab : 'f2';
    final filter = (
      status: ['f2', 'all'].contains(selected) ? '' : selected,
      f2: selected == 'f2',
      q: query,
    );
    final provider = listUsersProvider(filter);
    final list = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Duyệt tài khoản')),
      body: Screen(
        onRefresh: () => ref.refresh(provider.future),
        slivers: [
          if (list.value?.isNotEmpty == true)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: list.value!.length > shown
                    ? shown + 1
                    : list.value!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, i) => i == shown
                    ? Button(
                        kind: 'secondary',
                        title:
                            'Xem thêm (${list.value!.length - shown} tài khoản)',
                        onPress: () => setState(() => shown += 30),
                      )
                    : _AccountCard(
                        key: ValueKey(list.value![i].id),
                        user: list.value![i],
                        canManage: canManage,
                      ),
              ),
            ),
        ],
        children: [
          SearchBar(
            value: q,
            placeholder: 'Tìm theo email, họ tên, số điện thoại…',
            onChangeText: (v) => setState(() {
              q = v;
              shown = 30;
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 400), () {
                setState(() => query = v.trim());
              });
            }),
          ),
          if (canManage)
            ChipRail(
              children: [
                for (final MapEntry(:key, :value) in _tabs.entries)
                  Chip(
                    label: key == selected && list.value != null
                        ? '$value · ${list.value!.length}'
                        : value,
                    active: key == selected,
                    onPress: () => setState(() {
                      tab = key;
                      shown = 30;
                    }),
                  ),
              ],
            )
          else
            const Muted('Hồ sơ xin lên cộng tác viên (F2) vào đại lý của bạn.'),
          AsyncView(
            value: list,
            onRetry: () => ref.invalidate(provider),
            builder: (rows) => rows.isEmpty
                ? const Empty(
                    icon: Ionicons.peopleOutline,
                    text: 'Không có tài khoản.',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard({super.key, required this.user, required this.canManage});
  final AdminUser user;
  final bool canManage;
  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => busy || rejecting || failure != null;
  bool rejecting = false, busy = false;
  String reason = '';
  Object? failure;
  String get who => widget.user.fullName?.isNotEmpty == true
      ? widget.user.fullName!
      : widget.user.email;
  Future<void> mutate(String action) async {
    if (busy || (action == 'reject' && reason.trim().isEmpty)) return;
    setState(() {
      busy = true;
      failure = null;
    });
    updateKeepAlive();
    try {
      final u = widget.user;
      await switch (action) {
        'approve' => ref.read(approveUserProvider)(u),
        'reject' => ref.read(rejectUserProvider)(u, reason.trim()),
        'lock' => ref.read(lockUserProvider)(u.id),
        _ => ref.read(unlockUserProvider)(u.id),
      };
      if (!mounted) return;
      setState(() {
        rejecting = false;
        reason = '';
      });
      ref.invalidate(listUsersProvider);
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
    if (action == 'reject') {
      setState(() => rejecting = !rejecting);
      updateKeepAlive();
      return;
    }
    if (action == 'unlock') {
      await mutate(action);
      return;
    }
    final u = widget.user;
    final f2 = u.f2RequestedAt?.isNotEmpty == true;
    final title = action == 'approve'
        ? (f2 ? 'Duyệt tài khoản F2?' : 'Duyệt tài khoản?')
        : 'Khoá tài khoản?';
    final message = action == 'approve'
        ? (f2
              ? 'Duyệt $who vào ${u.requestedSalesUnitName ?? 'đại lý đã chọn'}? Người này sẽ xem được quỹ hàng theo phân bổ của đại lý.'
              : 'Duyệt $who? Tài khoản sẽ được kích hoạt với vai trò hiện có.')
        : '$who sẽ không đăng nhập được nữa; phiên đăng nhập hiện tại mất hiệu lực trong ≤ 5 giây. Mở khoá được sau.';
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accountActionLabel[action]!),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await mutate(action);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final u = widget.user;
    final isSuper = ref.watch(sessionProvider).roles.contains('superadmin');
    final actions = accountActions(u, widget.canManage, isSuper);
    final details = [
      u.roles.map(roles.roleName).join(', '),
      u.salesUnitName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
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
                  Body(
                    who,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (u.email.isNotEmpty || u.phone?.isNotEmpty == true)
                    Muted(
                      [u.email, u.phone]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                    ),
                ],
              ),
            ),
            Flexible(
              child: Pill(
                label: statusLabel(u),
                soft: true,
                color: unverified(u)
                    ? c.muted
                    : switch (u.status) {
                        'pending' => c.warn,
                        'active' => c.success,
                        'rejected' => c.danger,
                        _ => c.muted,
                      },
              ),
            ),
          ],
        ),
        Muted(details.isEmpty ? 'Chưa có vai trò' : details),
        if (u.f2RequestedAt?.isNotEmpty == true)
          Body(
            'Xin lên F2${u.f2Company?.isNotEmpty == true ? ': ${u.f2Company}' : ''}${u.requestedSalesUnitName?.isNotEmpty == true ? '\nVào đại lý: ${u.requestedSalesUnitName}${u.requestedManagerName?.isNotEmpty == true ? ' (quản lý ${u.requestedManagerName})' : ''}' : ''}${u.address?.isNotEmpty == true ? '\nĐịa chỉ: ${u.address}' : ''}',
          ),
        if (u.f2RejectedReason?.isNotEmpty == true)
          Muted('Lần F2 trước bị từ chối: ${u.f2RejectedReason}'),
        if (unverified(u)) const Muted('Người dùng chưa nhập mã OTP.'),
        Muted(
          u.lastLoginAt?.isNotEmpty == true
              ? 'Đăng nhập cuối ${fmtDate(u.lastLoginAt, true)}'
              : 'Chưa đăng nhập',
        ),
        if (u.roles.contains('superadmin') && !isSuper)
          const Muted('Chỉ quản trị sàn sửa được.'),
        if (busy) const LinearProgressIndicator(),
        if (actions.isNotEmpty)
          Chips(
            children: [
              for (final a in actions)
                Chip(
                  label: accountActionLabel[a]!,
                  active: a == 'reject' && rejecting,
                  onPress: busy ? null : () => run(a),
                ),
            ],
          ),
        if (rejecting) ...[
          Field(
            label: 'Lý do từ chối (người dùng sẽ thấy)',
            value: reason,
            maxLength: 500,
            onChangeText: (v) => setState(() => reason = v),
          ),
          Button(
            kind: 'danger',
            title: u.f2RequestedAt?.isNotEmpty == true
                ? 'Từ chối hồ sơ F2'
                : 'Từ chối tài khoản',
            disabled: reason.trim().isEmpty,
            loading: busy,
            onPress: () => mutate('reject'),
          ),
        ],
        if (failure != null)
          Notice(tone: 'error', text: accountError(failure!)),
      ],
    );
  }
}
