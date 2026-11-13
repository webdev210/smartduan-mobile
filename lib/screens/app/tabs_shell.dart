import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../api/sales.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/bottom_bar.dart';

const appTabPaths = ['/', '/du-an', '/tim-can', '/thong-bao', '/menu'];

class TabsShell extends ConsumerStatefulWidget {
  const TabsShell({super.key, required this.child});
  final StatefulNavigationShell child;
  @override
  ConsumerState<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends ConsumerState<TabsShell> {
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (ref.read(sessionProvider).status == SessionStatus.signedIn) {
        ref.invalidate(fetchNotificationsProvider);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(sessionProvider).roles;
    final unread = ref.watch(fetchNotificationsProvider).value?.unread ?? 0;
    const tabs = [
      (label: 'Trang chủ', icon: Ionicons.homeOutline, iconOn: Ionicons.home),
      (
        label: 'Dự án',
        icon: Ionicons.businessOutline,
        iconOn: Ionicons.business,
      ),
      (label: 'Tìm căn', icon: Ionicons.searchOutline, iconOn: Ionicons.search),
      (
        label: 'Thông báo',
        icon: Ionicons.notificationsOutline,
        iconOn: Ionicons.notifications,
      ),
      (label: 'Menu', icon: Ionicons.menuOutline, iconOn: Ionicons.menu),
    ];
    return Scaffold(
      body: SafeArea(
        top: widget.child.currentIndex == 0 || widget.child.currentIndex == 4,
        bottom: false,
        child: ClipRect(child: widget.child),
      ),
      bottomNavigationBar: GuestBar(
        items: [
          for (var i = 0; i < tabs.length; i++)
            if ((i != 1 || screens['projects']!(roles)) &&
                (i != 2 || screens['salesFloor']!(roles)))
              BarItem(
                key: appTabPaths[i],
                label: tabs[i].label,
                icon: tabs[i].icon,
                iconOn: tabs[i].iconOn,
                active: widget.child.currentIndex == i,
                badge: i == 3 && unread > 0
                    ? unread > 99
                          ? '99+'
                          : '$unread'
                    : null,
                accessibilityLabel: i == 4
                    ? 'Menu — bảng điều khiển của bạn'
                    : null,
                onPress: () => widget.child.goBranch(
                  i,
                  initialLocation: i == widget.child.currentIndex,
                ),
              ),
        ],
      ),
    );
  }
}
