import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../ui/catalog.dart';
import '../../ui/project_browser.dart';
import '../../ui/project_filter.dart';

class PublicExplore extends ConsumerWidget {
  const PublicExplore({super.key, this.params = const {}});
  final Map<String, String> params;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listAllPublicProjectsProvider);
    final places = ref.watch(fetchProvincesProvider);
    final developer =
        params['developer'] ??
        list.value
            ?.where((p) => p.developer?.id == params['developer_id'])
            .firstOrNull
            ?.developer
            ?.name;
    final type = typeLabel.containsKey(params['project_type'])
        ? params['project_type']
        : null;
    final opened = [
      'q',
      'province',
      'developer_id',
      'project_type',
    ].any((k) => params[k]?.isNotEmpty == true);
    return Scaffold(
      appBar: AppBar(
        title: Text(developer ?? params['province'] ?? 'Tất cả dự án'),
      ),
      body: ProjectBrowser(
        projects: list.value,
        loading: list.isLoading,
        error: list.error,
        onRetry: () => ref.invalidate(listAllPublicProjectsProvider),
        onRefresh: () => ref.refresh(listAllPublicProjectsProvider.future),
        onOpen: (p) =>
            context.push('/cong-khai/${Uri.encodeComponent(p.code)}'),
        aliases: provinceAliases(places.value ?? []),
        initial: ProjectFilter(
          q: params['q'] ?? '',
          province: params['province'],
          developer: developer,
          type: type,
        ),
        resetKey: [params['q'], params['province'], developer, type].join('|'),
        autoFocus: !opened,
        emptyText: 'Chưa có dự án công khai nào.',
      ),
    );
  }
}
