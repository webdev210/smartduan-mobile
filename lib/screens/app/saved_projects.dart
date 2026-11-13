import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../ui/favorite_button.dart';
import '../../ui/kit.dart' show Notice;
import '../../ui/project_browser.dart';

class SavedProjectsScreen extends ConsumerWidget {
  const SavedProjectsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ProjectBrowser's cards already contain FavoriteButton; share its saved state.
    final saved = ref.watch(savedProjectsProvider);
    final projects = [
      for (final code in saved.value ?? <String>[])
        ref.watch(fetchPublicProjectProvider(code)),
    ];
    final gone = projects.where((p) => p.hasError).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Dự án yêu thích')),
      body: ProjectBrowser(
        projects: saved.value == null
            ? null
            : [
                for (final p in projects)
                  if (p.value != null) p.value!,
              ],
        loading: saved.isLoading || projects.any((p) => p.isLoading),
        error: saved.error,
        onRetry: () => ref.invalidate(savedProjectsProvider),
        onRefresh: () => ref.refresh(savedProjectsProvider.future),
        onOpen: (p) =>
            context.push('/cong-khai/${Uri.encodeComponent(p.code)}'),
        emptyText: 'Chưa có dự án yêu thích. Bấm trái tim trên thẻ hoặc trang dự án để thêm.',
        banner: gone > 0
            ? Notice(text: '$gone dự án đã ngừng công khai.')
            : null,
      ),
    );
  }
}
