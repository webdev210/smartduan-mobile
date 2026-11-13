import 'package:material_ui/material_ui.dart' hide Card, Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/sales.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;

class BecomeSalesScreen extends ConsumerWidget {
  const BecomeSalesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(sessionProvider).roles;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký làm sale')),
      body: Screen(
        children: [
          isPartner(roles)
              ? const Notice(tone: 'success', text: 'Bạn đã là đại lý F2.')
              : hasNoRole(roles)
              ? const _BecomeFree()
              : const _RequestF2(),
        ],
      ),
    );
  }
}

class _BecomeFree extends ConsumerStatefulWidget {
  const _BecomeFree();
  @override
  ConsumerState<_BecomeFree> createState() => _BecomeFreeState();
}

class _BecomeFreeState extends ConsumerState<_BecomeFree> {
  String? branch;
  String referrer = '';
  bool busy = false, success = false;
  Object? failure;
  Future<void> submit() async {
    if (busy || success) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await ref.read(becomeSalesProvider)({
        if (branch != null) 'branch_code': branch,
        if (referrer.trim().isNotEmpty)
          'referred_by_sales_code': referrer.trim(),
      });
      if (!mounted) return;
      setState(() => success = true);
      await ref.read(sessionProvider.notifier).refreshMe();
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(fetchBranchesProvider);
    final me = ref.watch(sessionProvider).me;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const H2('Bước 1: Trở thành sale tự do'),
        const Muted(
          'Cần số điện thoại đã xác thực. Chi nhánh và mã người giới thiệu là tuỳ chọn.',
        ),
        if (me?['phone_verified_at'] == null)
          const Notice(
            tone: 'warn',
            text: 'Số điện thoại chưa xác thực — máy chủ sẽ từ chối (phone_not_verified).',
          ),
        const Muted('Chi nhánh (tuỳ chọn)'),
        Chips(
          children: [
            Chip(
              label: 'Không chọn',
              active: branch == null,
              onPress: () => setState(() => branch = null),
            ),
            for (final b in branches.value ?? <Branch>[])
              Chip(
                label: b.province?.isNotEmpty == true
                    ? '${b.name} · ${b.province}'
                    : b.name,
                active: branch == b.code,
                onPress: () => setState(() => branch = b.code),
              ),
          ],
        ),
        if (branches.hasError)
          Notice(
            tone: 'warn',
            text:
                'Không tải được danh sách chi nhánh: ${errorMessage(branches.error)}',
          ),
        if (fieldError(failure, 'branch_code') case final String text)
          Notice(tone: 'error', text: 'Chi nhánh: $text'),
        Field(
          label: 'Mã sales người giới thiệu (tuỳ chọn)',
          textInputAction: TextInputAction.done,
          onSubmit: (_) => submit(),
          value: referrer,
          onChangeText: (v) => setState(() => referrer = v),
          autoCapitalize: TextCapitalization.characters,
          error: fieldError(failure, 'referred_by_sales_code'),
        ),
        if (failure != null) Notice(tone: 'error', text: errorMessage(failure)),
        if (success)
          const Notice(
            tone: 'success',
            text: 'Đã thành sale tự do. Nếu app báo phiên hết hạn, hãy đăng nhập lại để dùng quyền mới.',
          ),
        Button(
          title: 'Đăng ký làm sale',
          loading: busy,
          disabled: success,
          onPress: submit,
        ),
      ],
    );
  }
}

class _RequestF2 extends ConsumerStatefulWidget {
  const _RequestF2();
  @override
  ConsumerState<_RequestF2> createState() => _RequestF2State();
}

class _RequestF2State extends ConsumerState<_RequestF2> {
  String? picked;
  late String fullName, address;
  String company = '';
  bool busy = false;
  Object? failure;
  @override
  void initState() {
    super.initState();
    final me = ref.read(sessionProvider).me;
    fullName = me?['full_name'] as String? ?? '';
    address = me?['address'] as String? ?? '';
  }

  String? get managerId =>
      picked ?? ref.read(sessionProvider).me?['referred_manager_id'] as String?;
  Future<void> submit() async {
    if (busy ||
        managerId == null ||
        fullName.trim().isEmpty ||
        address.trim().isEmpty) {
      return;
    }
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await ref.read(requestF2Provider)({
        'manager_id': managerId,
        'full_name': fullName.trim(),
        'address': address.trim(),
        if (company.trim().isNotEmpty) 'company': company.trim(),
      });
      if (mounted) await ref.read(sessionProvider.notifier).refreshMe();
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).me;
    final managers = ref.watch(fetchManagersProvider);
    if (me?['f2_requested_at'] case final String at when at.isNotEmpty) {
      return Card(
        children: [
          const H2('Đang chờ duyệt F2'),
          Muted(
            'Gửi lúc ${fmtDate(at, true)}${me?['requested_sales_unit_name'] != null ? ' tới đại lý ${me!['requested_sales_unit_name']}' : ''}${me?['requested_manager_name'] != null ? ' (quản lý ${me!['requested_manager_name']})' : ''}.',
          ),
          const Muted(
            'Khi được duyệt, app sẽ yêu cầu đăng nhập lại để dùng quyền F2.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const H2('Bước 2: Xin xác nhận F2'),
        if (me?['f2_rejected_reason'] case final String reason
            when reason.isNotEmpty)
          Notice(tone: 'warn', text: 'Yêu cầu trước bị từ chối: $reason'),
        const Muted('Chọn quản lý đại lý'),
        if (managers.isLoading) const Loading(),
        if (managers.hasError)
          ErrorBox(
            error: managers.error,
            onRetry: () => ref.invalidate(fetchManagersProvider),
          ),
        Chips(
          children: [
            for (final m in managers.value ?? <ManagerOption>[])
              Chip(
                label: '${m.fullName} · ${m.salesUnit?.name ?? ''}',
                active: managerId == m.id,
                onPress: () => setState(() => picked = m.id),
              ),
          ],
        ),
        if (fieldError(failure, 'manager_id') case final String text)
          Notice(tone: 'error', text: 'Quản lý: $text'),
        Field(
          label: 'Họ tên',
          textInputAction: TextInputAction.next,
          value: fullName,
          onChangeText: (v) => setState(() => fullName = v),
          maxLength: 120,
          error: fieldError(failure, 'full_name'),
        ),
        Field(
          label: 'Địa chỉ liên hệ',
          textInputAction: TextInputAction.next,
          value: address,
          onChangeText: (v) => setState(() => address = v),
          maxLength: 255,
          error: fieldError(failure, 'address'),
        ),
        Field(
          label: 'Công ty (tuỳ chọn)',
          textInputAction: TextInputAction.done,
          onSubmit: (_) => submit(),
          value: company,
          onChangeText: (v) => setState(() => company = v),
          maxLength: 255,
          error: fieldError(failure, 'f2_company'),
        ),
        if (failure != null) Notice(tone: 'error', text: errorMessage(failure)),
        Button(
          title: 'Gửi yêu cầu F2',
          loading: busy,
          disabled:
              managerId == null ||
              fullName.trim().isEmpty ||
              address.trim().isEmpty,
          onPress: submit,
        ),
      ],
    );
  }
}
