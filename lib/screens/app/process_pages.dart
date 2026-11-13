import 'package:ionicons/ionicons.dart';

import 'package:material_ui/material_ui.dart'
    hide Card, Chip, Divider, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/sales.dart';
import '../../ui/catalog.dart' show compareVietnamese;
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/search.dart';

class ProcessPagesScreen extends ConsumerStatefulWidget {
  const ProcessPagesScreen({super.key});
  @override
  ConsumerState<ProcessPagesScreen> createState() => _ProcessPagesState();
}

class _ProcessPagesState extends ConsumerState<ProcessPagesScreen> {
  String q = '';
  String? scope;
  @override
  Widget build(BuildContext context) {
    final list = ref.watch(fetchProcessPagesProvider);
    final all = list.value ?? <ProcessPage>[];
    final scopes = all.map((p) => p.projectName ?? 'Chung').toSet().toList()
      ..sort(
        (a, b) => a == b
            ? 0
            : a == 'Chung'
            ? -1
            : b == 'Chung'
            ? 1
            : compareVietnamese(a, b),
      );
    final rows = smartFilter(
      all
          .where((p) => scope == null || (p.projectName ?? 'Chung') == scope)
          .toList(),
      q,
      (p) => [p.title, p.summary, p.projectName],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Quy trình & đào tạo')),
      body: ListScreen<ProcessPage>(
        data: rows,
        keyOf: (p) => p.id,
        top: SearchBar(
          value: q,
          onChangeText: (v) => setState(() => q = v),
          placeholder: 'Tìm quy trình, tài liệu đào tạo…',
        ),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (list.hasError && rows.isNotEmpty)
              ErrorBox(
                error: list.error,
                onRetry: () => ref.invalidate(fetchProcessPagesProvider),
              ),
            if (scopes.length > 1)
              ChipRail(
                children: [
                  Chip(
                    label: 'Tất cả · ${all.length}',
                    active: scope == null,
                    onPress: () => setState(() => scope = null),
                  ),
                  for (final name in scopes)
                    Chip(
                      label: name,
                      active: scope == name,
                      onPress: () =>
                          setState(() => scope = scope == name ? null : name),
                    ),
                ],
              ),
          ],
        ),
        empty: AsyncView(
          value: list,
          onRetry: () => ref.invalidate(fetchProcessPagesProvider),
          builder: (_) => scope != null || q.trim().isNotEmpty
              ? Empty(
                  icon: Ionicons.searchOutline,
                  text: 'Không có trang nào khớp.',
                  action: (
                    label: 'Xoá tìm kiếm & bộ lọc',
                    onPress: () => setState(() {
                      q = '';
                      scope = null;
                    }),
                  ),
                )
              : const Empty(
                  icon: Ionicons.schoolOutline,
                  text: 'Chưa có trang quy trình.',
                ),
        ),
        renderItem: (p) => Column(
          children: [
            if (p.id != rows.first.id) const Divider(),
            ListItem(
              title: p.title,
              subtitle: [
                if (p.summary?.isNotEmpty == true) p.summary!,
                '${p.projectName != null ? '${p.projectName} · ' : ''}Cập nhật ${fmtDate(p.updatedAt)}',
              ].join('\n'),
              onPress: () =>
                  context.push('/quy-trinh/${Uri.encodeComponent(p.slug)}'),
            ),
          ],
        ),
        onRefresh: () => ref.refresh(fetchProcessPagesProvider.future),
      ),
    );
  }
}
