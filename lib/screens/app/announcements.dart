import 'package:ionicons/ionicons.dart';

import 'package:material_ui/material_ui.dart' hide Card, SearchBar, Divider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/projects.dart' show SessionQuery;
import '../../api/sales.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/search.dart';

// Keep pagination in a session-bound query so account changes clear every page.
final accountAnnouncementsProvider =
    AsyncNotifierProvider.autoDispose<
      AccountAnnouncements,
      List<Paged<AnnouncementSummary>>
    >(AccountAnnouncements.new);

class AccountAnnouncements
    extends SessionQuery<List<Paged<AnnouncementSummary>>> {
  AccountAnnouncements()
    : super(
        (ref) async => [await ref.watch(salesApiProvider).fetchAnnouncements()],
      );

  Future<void> loadMore() async {
    final previous = state;
    final pages = previous.value;
    if (previous.isLoading || pages == null || pages.isEmpty) return;
    final last = pages.last;
    if (last.page * last.perPage >= last.total) return;
    final session = ref.read(sessionProvider);
    final api = ref.read(salesApiProvider);
    state = const AsyncLoading();
    try {
      final next = await api.fetchAnnouncements(last.page + 1);
      if (ref.mounted && identical(session, ref.read(sessionProvider))) {
        state = AsyncData([...pages, next]);
      }
    } catch (error, stack) {
      if (ref.mounted && identical(session, ref.read(sessionProvider))) {
        state = AsyncError(error, stack);
      }
    }
  }
}

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends ConsumerState<AnnouncementsScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = ref.watch(accountAnnouncementsProvider);
    final pages = list.value ?? <Paged<AnnouncementSummary>>[];
    final all = pages.expand((p) => p.data).toList();
    final last = pages.lastOrNull;
    final more = last != null && last.page * last.perPage < last.total;
    final rows = smartFilter(all, q, (a) => [a.title]);
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng tin')),
      body: ListScreen<AnnouncementSummary>(
        data: rows,
        keyOf: (a) => a.id,
        top: SearchBar(
          value: q,
          onChangeText: (v) => setState(() => q = v),
          placeholder: 'Tìm trong bảng tin…',
        ),
        header: q.trim().isNotEmpty && more
            ? Muted(
                'Đang tìm trong ${all.length} tin đã tải — bấm “Tải thêm” để tìm tiếp.',
              )
            : null,
        empty: AsyncView(
          value: list,
          onRetry: () => ref.invalidate(accountAnnouncementsProvider),
          builder: (_) => q.trim().isNotEmpty
              ? Empty(
                  icon: Ionicons.searchOutline,
                  text: 'Không có tin nào khớp “${q.trim()}”.',
                  action: (
                    label: 'Xoá từ khoá',
                    onPress: () => setState(() => q = ''),
                  ),
                )
              : const Empty(
                  icon: Ionicons.newspaperOutline,
                  text: 'Chưa có tin.',
                ),
        ),
        renderItem: (a) => Card(
          onPress: () => context.push('/bang-tin/${Uri.encodeComponent(a.id)}'),
          children: [
            Body(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Muted(fmtDate(a.publishedAt, true)),
          ],
        ),
        footer: list.hasError && all.isNotEmpty
            ? ErrorBox(
                error: list.error!,
                onRetry: () =>
                    ref.read(accountAnnouncementsProvider.notifier).loadMore(),
              )
            : more
            ? Button(
                kind: 'secondary',
                title: 'Tải thêm',
                loading: list.isLoading,
                onPress: () =>
                    ref.read(accountAnnouncementsProvider.notifier).loadMore(),
              )
            : null,
        onRefresh: () => ref.refresh(accountAnnouncementsProvider.future),
      ),
    );
  }
}
