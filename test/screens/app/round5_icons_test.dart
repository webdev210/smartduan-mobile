import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/screens/app/announcements.dart';
import 'package:smartduan/screens/app/approve_accounts.dart';
import 'package:smartduan/screens/app/approve_devices.dart';
import 'package:smartduan/screens/app/notifications.dart';
import 'package:smartduan/screens/app/process_pages.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/share_links.dart';
import 'package:smartduan/screens/app/team.dart';
import 'package:smartduan/screens/app/top_units.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'task_h_fakes.dart';

void main() {
  for (final (name, screen, emptyIcon, searchIcon)
      in <(String, Widget, IconData, IconData?)>[
        (
          'top units',
          const TopUnitsScreen(projectId: 'p'),
          Ionicons.trophyOutline,
          null,
        ),
        (
          'share links',
          const ShareLinksScreen(projectId: 'p'),
          Ionicons.shareSocialOutline,
          null,
        ),
        (
          'process',
          const ProcessPagesScreen(),
          Ionicons.schoolOutline,
          Ionicons.searchOutline,
        ),
        (
          'announcements',
          const AnnouncementsScreen(),
          Ionicons.newspaperOutline,
          Ionicons.searchOutline,
        ),
        ('team', const TeamScreen(), Ionicons.peopleOutline, null),
        (
          'accounts',
          const ApproveAccountsScreen(),
          Ionicons.peopleOutline,
          null,
        ),
        (
          'devices',
          const ApproveDevicesScreen(),
          Ionicons.phonePortraitOutline,
          null,
        ),
        ('search', const SearchUnitsScreen(), Ionicons.searchOutline, null),
        (
          'notifications',
          const NotificationsScreen(),
          Ionicons.notificationsOffOutline,
          Ionicons.searchOutline,
        ),
      ]) {
    testWidgets('$name empty state uses its RN icon', (tester) async {
      final env = HEnv(roles: [name == 'team' ? 'manager' : 'superadmin']);
      env.http.respond = (_) => const Reply(200, {
        'data': <Object?>[],
        'groups': <Object?>[],
        'codes': <Object?>[],
        'total': 0,
        'page': 1,
        'per_page': 30,
        'unread': 0,
      });
      await env.mount(tester, screen);
      expect(
        find.descendant(
          of: find.byType(kit.Empty),
          matching: find.byIcon(emptyIcon),
        ),
        findsOneWidget,
      );
      if (searchIcon != null) {
        await tester.enterText(find.byType(TextField).first, 'khongkhop');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(kit.Empty),
            matching: find.byIcon(searchIcon),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(emptyIcon), findsNothing);
      }
    });
  }
}
