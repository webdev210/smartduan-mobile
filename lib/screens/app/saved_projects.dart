import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../api/errors.dart';
import '../../api/projects.dart' show fetchAllProjectsProvider;
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/favorite_button.dart';
import '../../ui/kit.dart' show Notice, Button;
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
    final working = screens['salesFloor']!(ref.watch(sessionProvider).roles)
        ? ref.watch(fetchAllProjectsProvider)
        : null;
    final allowed = {for (final p in working?.value ?? []) p.id};
    bool unavailable(Object? error) =>
        error is ApiError && (error.status == 403 || error.status == 404);
    final gone = projects.where((p) => unavailable(p.error)).length;
    final failed = projects
        .where((p) => p.hasError && !unavailable(p.error))
        .length;
    void retry() {
      for (final code in saved.value ?? <String>[]) {
        if (ref.read(fetchPublicProjectProvider(code)).hasError) {
          ref.invalidate(fetchPublicProjectProvider(code));
        }
      }
      ref.invalidate(savedProjectsProvider);
    }

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
        onRetry: retry,
        onRefresh: () async {
          retry();
          await ref.read(savedProjectsProvider.future);
        },
        onOpen: (p) =>
            context.push('/cong-khai/${Uri.encodeComponent(p.code)}'),
        actionBuilder: (p) => allowed.contains(p.id)
            ? Button(
                title: 'Bảng hàng',
                kind: 'secondary',
                onPress: () =>
                    context.push('/bang-hang/${Uri.encodeComponent(p.id)}'),
              )
            : null,
        emptyText: 'Chưa có dự án yêu thích. Bấm trái tim trên thẻ hoặc trang dự án để thêm.',
        banner: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (working?.hasError == true) ...[
              const Notice(text: 'Chưa kiểm tra được quyền mở bảng hàng.'),
              Button(
                title: 'Kiểm tra lại bảng hàng',
                kind: 'link',
                onPress: () => ref.invalidate(fetchAllProjectsProvider),
              ),
            ],
            if (gone > 0) Notice(text: '$gone dự án hiện không còn công khai.'),
            if (failed > 0) ...[
              Notice(
                tone: 'warn',
                text:
                    'Chưa tải được $failed dự án. Kiểm tra kết nối rồi thử lại.',
              ),
              Button(
                title: 'Thử lại dự án lỗi',
                kind: 'secondary',
                onPress: retry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
