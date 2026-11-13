import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'project_detail.dart';
import 'post.dart';
import 'developer.dart';
import 'loan.dart';
import 'privacy_policy.dart';
import 'viewer.dart';
import 'tour_360.dart';
import 'project_compare.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
publicDetailScreens = {
  '/so-sanh-du-an': (_, _) => const ProjectCompareScreen(),
  '/cong-khai/:code': (_, s) =>
      ProjectDetailScreen(code: s.pathParameters['code']!),
  '/bai-viet/:slug': (_, s) => PostScreen(slug: s.pathParameters['slug']!),
  '/chu-dau-tu/:slug': (_, s) =>
      DeveloperScreen(slug: s.pathParameters['slug']!),
  '/tinh-lai-vay': (_, _) => const LoanScreen(),
  '/chinh-sach-bao-mat': (_, _) => const PrivacyPolicyScreen(),
  '/xem': (_, s) => ViewerScreen(
    url: s.uri.queryParameters['url'],
    title: s.uri.queryParameters['title'] ?? 'Xem',
    file: s.uri.queryParameters['file'] == '1',
  ),
  '/tour-360': (_, s) => Tour360Screen(
    url: s.uri.queryParameters['url'],
    name: s.uri.queryParameters['name'] ?? 'Dự án',
  ),
};
