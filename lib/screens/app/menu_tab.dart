import 'package:material_ui/material_ui.dart' hide Card, Divider, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../api/projects.dart';
import '../../api/sales.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../config.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/menu.dart';
import '../../ui/theme.dart' as c;

IconData menuIcon(String name) => switch (name) {
  'business-outline' => Ionicons.businessOutline,
  'search-outline' => Ionicons.searchOutline,
  'git-compare-outline' => Ionicons.gitCompareOutline,
  'calculator-outline' => Ionicons.calculatorOutline,
  'globe-outline' => Ionicons.globeOutline,
  'notifications-outline' => Ionicons.notificationsOutline,
  'heart-outline' => Ionicons.heartOutline,
  'chatbubbles-outline' => Ionicons.chatbubblesOutline,
  'newspaper-outline' => Ionicons.newspaperOutline,
  'school-outline' => Ionicons.schoolOutline,
  'people-outline' => Ionicons.peopleOutline,
  'bar-chart-outline' => Ionicons.barChartOutline,
  'phone-portrait-outline' => Ionicons.phonePortraitOutline,
  'person-add-outline' => Ionicons.personAddOutline,
  'person-circle-outline' => Ionicons.personCircleOutline,
  'rocket-outline' => Ionicons.rocketOutline,
  'document-lock-outline' => Ionicons.documentLockOutline,
  _ => Ionicons.gridOutline,
};

class MenuTab extends ConsumerStatefulWidget {
  const MenuTab({super.key});
  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  String q = '';
  bool signingOut = false;
  Future<void> signOut(bool everywhere) async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await ref.read(sessionProvider.notifier).signOut(everywhere: everywhere);
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider),
        roles = session.roles,
        me = session.me;
    final onFloor = screens['salesFloor']!(roles),
        hasProjects = screens['projects']!(roles);
    final notifications = ref.watch(fetchNotificationsProvider);
    final available = onFloor ? ref.watch(countAvailableProvider) : null;
    final projects = hasProjects ? ref.watch(fetchAllProjectsProvider) : null;
    final groups = menuGroups(roles);
    final found = q.trim().isEmpty ? null : searchMenu(groups, q);
    final name = (me?['full_name'] ?? me?['email'] ?? '') as String;
    final askRole = hasNoRole(roles) || screens['requestF2']!(roles);
    Widget entry(MenuItem item) => ListItem(
      icon: menuIcon(item.icon),
      title: item.label,
      subtitle: item.hint,
      onPress: () => context.push(item.href),
    );
    Widget stat(String value, String label, String route) => Expanded(
      child: Semantics(
        label: '$label: $value',
        button: true,
        child: InkWell(
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.brand,
                  ),
                ),
                Muted(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
    return SafeArea(
      bottom: false,
      child: Screen(
        onRefresh: () async {
          ref.invalidate(fetchNotificationsProvider);
          if (onFloor) ref.invalidate(countAvailableProvider);
          if (hasProjects) ref.invalidate(fetchAllProjectsProvider);
          await ref.read(fetchNotificationsProvider.future);
        },
        children: [
          Card(
            padding: EdgeInsets.zero,
            children: [
              Semantics(
                button: true,
                label: 'Hồ sơ của $name',
                child: InkWell(
                  onTap: () => context.push('/ho-so'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      spacing: 14,
                      children: [
                        Avatar(name: name, size: 52),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                rolesLabel(roles),
                                style: const TextStyle(
                                  color: c.brand,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (me?['full_name'] != null &&
                                  me?['email'] != null)
                                Muted(me!['email'] as String, numberOfLines: 1),
                            ],
                          ),
                        ),
                        const Icon(
                          Ionicons.chevronForward,
                          size: 18,
                          color: c.subtle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Row(
                children: [
                  stat(
                    '${notifications.value?.unread ?? '…'}',
                    'Thông báo mới',
                    '/thong-bao',
                  ),
                  if (onFloor)
                    stat(
                      available!.hasError ? '—' : '${available.value ?? '…'}',
                      'Căn còn hàng',
                      '/tim-can',
                    ),
                  if (hasProjects)
                    stat(
                      projects!.hasError
                          ? '—'
                          : '${projects.value?.length ?? '…'}',
                      'Dự án của tôi',
                      '/du-an',
                    ),
                ],
              ),
            ],
          ),
          if (askRole || me?['region'] == null || me?['region'] == '')
            Card(
              padding: EdgeInsets.zero,
              children: [
                if (askRole)
                  ListItem(
                    tone: 'brand',
                    icon: Ionicons.rocketOutline,
                    title: hasNoRole(roles)
                        ? 'Đăng ký làm sale'
                        : 'Xin xác nhận F2',
                    subtitle: me?['f2_requested_at'] != null
                        ? 'Đã gửi yêu cầu F2 ${fmtDate(me!['f2_requested_at'] as String)}${me['requested_sales_unit_name'] != null ? ' tới ${me['requested_sales_unit_name']}' : ''}, đang chờ duyệt.'
                        : hasNoRole(roles)
                        ? 'Trở thành sale tự do để xem danh mục dự án công khai.'
                        : 'Gửi yêu cầu lên F2 để xem rổ hàng đại lý được phân bổ.',
                    onPress: () => context.push('/len-sale'),
                  ),
                if (me?['region'] == null || me?['region'] == '')
                  ListItem(
                    icon: Ionicons.locationOutline,
                    title: 'Chọn miền & dự án quan tâm',
                    subtitle: 'Để nhận thông báo chính sách, tài liệu mới của dự án bạn theo.',
                    onPress: () => context.push('/quan-tam'),
                  ),
              ],
            ),
          SearchBar(
            value: q,
            onChangeText: (v) => setState(() => q = v),
            placeholder: 'Tìm tính năng…',
            maxLength: 40,
          ),
          if (found != null)
            if (found.isEmpty)
              Empty(
                icon: Ionicons.searchOutline,
                text: 'Không có tính năng nào khớp “${q.trim()}”.',
                action: (
                  label: 'Xem tất cả tính năng',
                  onPress: () => setState(() => q = ''),
                ),
              )
            else
              Card(
                padding: EdgeInsets.zero,
                children: [for (final item in found) entry(item)],
              )
          else
            for (final group in groups)
              Section(
                title: group.title,
                child: group.title == 'Tài khoản'
                    ? Card(
                        padding: EdgeInsets.zero,
                        children: [for (final item in group.items) entry(item)],
                      )
                    : Column(
                        children: [for (final item in group.items) entry(item)],
                      ),
              ),
          Button(
            kind: 'secondary',
            icon: Ionicons.logOutOutline,
            title: 'Đăng xuất',
            loading: signingOut,
            onPress: () => signOut(false),
          ),
          const Center(
            child: Muted(
              'Smart Dự Án · phiên bản $appVersion',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
