import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'board.dart';
import 'project_history.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
appBoardScreens = {
  '/bang-hang/:projectId': (_, state) => BoardScreen(
    projectId: state.pathParameters['projectId']!,
    name: state.uri.queryParameters['name'],
    blockId: state.uri.queryParameters['blockId'],
  ),
  '/bien-dong/:projectId': (_, state) => ProjectHistoryScreen(
    projectId: state.pathParameters['projectId']!,
    name: state.uri.queryParameters['name'],
  ),
};
