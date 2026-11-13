import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'profile.dart';
import 'saved_projects.dart';
import 'interests.dart';
import 'team.dart';
import 'become_sales.dart';
import 'consult.dart';
import 'process_pages.dart';
import 'process_page.dart';
import 'announcements.dart';
import 'announcement.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
appAccountScreens = {
  '/ho-so': (_, _) => const ProfileScreen(),
  '/da-luu': (_, _) => const SavedProjectsScreen(),
  '/quan-tam': (_, _) => const InterestsScreen(),
  '/doi-cua-toi': (_, _) => const TeamScreen(),
  '/len-sale': (_, _) => const BecomeSalesScreen(),
  '/tu-van': (_, s) => ConsultScreen(
    projectId: s.uri.queryParameters['projectId'],
    name: s.uri.queryParameters['name'],
  ),
  '/quy-trinh': (_, _) => const ProcessPagesScreen(),
  '/quy-trinh/:slug': (_, s) =>
      ProcessPageScreen(slug: s.pathParameters['slug']!),
  '/bang-tin': (_, _) => const AnnouncementsScreen(),
  '/bang-tin/:id': (_, s) => AnnouncementScreen(id: s.pathParameters['id']!),
};
