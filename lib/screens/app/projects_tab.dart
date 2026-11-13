import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../api/projects.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/kit.dart' show Card, ListItem, Notice;
import '../../ui/project_browser.dart';
import '../../ui/project_filter.dart';

// The shared browser accepts PublicProject; keep the internal visibility and
// inventory fields when adapting, so private codes never become public actions.
class TabProject extends PublicProject {
  TabProject(Project p)
    : _project = p,
      super(
        id: p.id,
        name: p.name,
        code: p.code,
        status: p.status,
        projectType: p.projectType,
        province: p.province,
        district: p.district,
        address: p.address,
        priceFrom: p.priceFrom,
        coverUrl: p.coverUrl,
      );
  final Project _project;
  @override
  bool get isPublic => _project.isPublic;
  @override
  String? get developerName => _project.developerName;
  @override
  String? get inventoryUpdatedAt => _project.inventoryUpdatedAt;
}

class ProjectsTab extends ConsumerWidget {
  const ProjectsTab({super.key, this.q = '', this.at = ''});
  final String q, at;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(fetchAllProjectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dự án')),
      body: ProjectBrowser(
        projects: list.value?.map(TabProject.new).toList(),
        loading: list.isLoading,
        error: list.error,
        onRetry: () => ref.invalidate(fetchAllProjectsProvider),
        onRefresh: () => ref.refresh(fetchAllProjectsProvider.future),
        onOpen: (p) => context.push('/du-an/${Uri.encodeComponent(p.id)}'),
        initial: ProjectFilter(q: q),
        resetKey: '$q|$at',
        emptyText: 'Chưa có dự án nào được phân bổ cho bạn.',
        banner: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (isFreeSales(ref.watch(sessionProvider).roles))
              const Notice(
                text: 'Sale tự do chỉ thấy danh mục dự án công khai.',
              ),
            Card(
              padding: EdgeInsets.zero,
              child: ListItem(
                icon: Ionicons.globeOutline,
                title: 'Tất cả dự án trên sàn',
                subtitle: 'Danh mục công khai của sàn',
                onPress: () => context.push('/kham-pha'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
