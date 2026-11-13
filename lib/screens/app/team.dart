import 'package:ionicons/ionicons.dart';

import 'package:material_ui/material_ui.dart' hide Card, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/sales.dart';
import '../../auth/session.dart';
import '../../auth/roles.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/search.dart';
import '../../ui/theme.dart' as c;

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamState();
}

class _TeamState extends ConsumerState<TeamScreen> {
  String q = '', only = 'all';
  void reset() => setState(() {
    q = '';
    only = 'all';
  });
  @override
  Widget build(BuildContext context) {
    if (!isManager(ref.watch(sessionProvider).roles)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đội của tôi')),
        body: const Screen(
          children: [Notice(text: 'Bạn không có quyền truy cập.')],
        ),
      );
    }
    final team = ref.watch(fetchTeamProvider);
    final all = team.value?.data ?? <TeamMember>[];
    final locked = all.where((m) => m.status == 'locked').length;
    final rows = smartFilter(
      all
          .where(
            (m) =>
                only == 'all' || (m.status == 'locked') == (only == 'locked'),
          )
          .toList(),
      q,
      (m) => [m.fullName, m.salesCode, m.roles.map(roleName).join(' ')],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Đội của tôi')),
      body: ListScreen<TeamMember>(
        data: rows,
        keyOf: (m) => m.id,
        top: SearchBar(
          value: q,
          onChangeText: (v) => setState(() => q = v),
          placeholder: 'Tìm theo tên, mã sales, vai trò…',
        ),
        header: team.value == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  if (team.hasError && rows.isNotEmpty)
                    ErrorBox(
                      error: team.error,
                      onRetry: () => ref.invalidate(fetchTeamProvider),
                    ),
                  H2(team.value!.salesUnit?.name ?? ''),
                  if (all.isNotEmpty)
                    Segmented(
                      value: only,
                      onChange: (v) => setState(() => only = v),
                      options: [
                        (key: 'all', label: 'Tất cả', count: all.length),
                        (
                          key: 'active',
                          label: 'Hoạt động',
                          count: all.length - locked,
                        ),
                        (key: 'locked', label: 'Đã khoá', count: locked),
                      ],
                    ),
                ],
              ),
        empty: AsyncView(
          value: team,
          onRetry: () => ref.invalidate(fetchTeamProvider),
          builder: (_) => all.isEmpty
              ? const Empty(
                  icon: Ionicons.peopleOutline,
                  text: 'Đại lý chưa có thành viên.',
                )
              : Empty(
                  icon: Ionicons.searchOutline,
                  text: 'Không có thành viên nào khớp.',
                  action: (label: 'Xoá tìm kiếm & bộ lọc', onPress: reset),
                ),
        ),
        renderItem: (m) => Card(
          child: Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(name: m.fullName, size: 44),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      m.fullName ?? '—',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (m.salesCode?.isNotEmpty == true || m.roles.isNotEmpty)
                      Muted(
                        [m.salesCode, m.roles.map(roleName).join(', ')]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                    Muted(
                      'Đăng nhập gần nhất: ${fmtDate(m.lastLoginAt, true).replaceAll(' ', '\u00a0')}',
                    ),
                    Pill(
                      label: m.status == 'locked' ? 'Đã khoá' : 'Hoạt động',
                      color: m.status == 'locked' ? c.muted : c.success,
                      soft: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        onRefresh: () => ref.refresh(fetchTeamProvider.future),
      ),
    );
  }
}
