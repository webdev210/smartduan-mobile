import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'home.dart';
import 'projects_tab.dart';
import 'search_units.dart';
import 'notifications.dart';
import 'menu_tab.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)> appTabScreens =
    {
      '/': (_, _) => const HomeScreen(),
      '/du-an': (_, state) => ProjectsTab(
        q: state.uri.queryParameters['q'] ?? '',
        at: state.uri.queryParameters['at'] ?? '',
      ),
      '/tim-can': (_, _) => const SearchUnitsScreen(),
      '/thong-bao': (_, _) => const NotificationsScreen(),
      '/menu': (_, _) => const MenuTab(),
    };
