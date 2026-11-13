import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'basket.dart';
import 'presentation.dart';
import 'share_links.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
appShareScreens = {
  '/ro-hang': (_, state) => BasketScreen(
    projectId: state.uri.queryParameters['project'],
    url: state.uri.queryParameters['url'],
  ),
  '/trinh-chieu/:projectId': (_, state) =>
      PresentationScreen(projectId: state.pathParameters['projectId']!),
  '/chia-se/:projectId': (_, state) => ShareLinksScreen(
    projectId: state.pathParameters['projectId']!,
    name: state.uri.queryParameters['name'],
    blockId: state.uri.queryParameters['blockId'],
  ),
};
