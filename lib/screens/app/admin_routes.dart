import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'approve_accounts.dart';
import 'approve_devices.dart';
import 'reports.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
appAdminScreens = {
  '/bao-cao': (_, _) => const ReportsScreen(),
  '/duyet-tai-khoan': (_, _) => const ApproveAccountsScreen(),
  '/duyet-thiet-bi': (_, state) => ApproveDevicesScreen(
    userId: state.uri.queryParameters['userId'],
    name: state.uri.queryParameters['name'],
  ),
};
