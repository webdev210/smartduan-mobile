import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'home.dart';
import 'explore.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)>
publicHomeScreens = {
  '/': (_, _) => const PublicHome(),
  '/kham-pha': (_, state) => PublicExplore(params: state.uri.queryParameters),
};
