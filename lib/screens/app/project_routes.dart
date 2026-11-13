import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'project.dart';
import 'unit.dart';
import 'compare_units.dart';
import 'loan.dart';
import 'top_units.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
appProjectScreens = {
  '/du-an/:id': (_, state) => ProjectScreen(id: state.pathParameters['id']!),
  '/can/:id': (_, state) => UnitScreen(id: state.pathParameters['id']!),
  '/so-sanh': (_, _) => const CompareUnitsScreen(),
  '/lai-vay': (_, state) => LoanScreen(
    unitId: state.uri.queryParameters['unitId'],
    code: state.uri.queryParameters['code'],
  ),
  '/top-can/:projectId': (_, state) => TopUnitsScreen(
    projectId: state.pathParameters['projectId']!,
    name: state.uri.queryParameters['name'],
  ),
};
