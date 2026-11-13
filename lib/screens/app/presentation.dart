import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/errors.dart';
import '../../api/projects.dart';
import '../../api/units.dart' show fetchEnumsProvider;
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/stack_grid.dart';

// The shared query helper has no retry option; RN explicitly disables retries
// for this potentially large grid. Keep its session-reset implementation.
final presentationStackProvider = AsyncNotifierProvider.autoDispose
    .family<
      SessionQuery<StackPlan>,
      StackPlan,
      ({String projectId, String blockId})
    >(
      (a) => SessionQuery(
        (ref) => ref
            .watch(projectsApiProvider)
            .fetchPresentationStack(a.projectId, a.blockId),
      ),
      retry: (_, _) => null,
    );

class PresentationScreen extends ConsumerStatefulWidget {
  const PresentationScreen({super.key, required this.projectId});
  final String projectId;
  @override
  ConsumerState<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends ConsumerState<PresentationScreen> {
  String? picked, unitId;
  final _detailKey = GlobalKey();
  void _revealDetail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final detail = _detailKey.currentContext;
      if (!mounted || detail == null) return;
      Scrollable.ensureVisible(
        detail,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = fetchPresentationBoardProvider(widget.projectId);
    final board = ref.watch(boardProvider);
    final data = board.asData?.value;
    final blockId = picked ?? data?.blockId ?? data?.blocks.firstOrNull?.id;
    final stackProvider = blockId == null
        ? null
        : presentationStackProvider((
            projectId: widget.projectId,
            blockId: blockId,
          ));
    final stack = stackProvider == null ? null : ref.watch(stackProvider);
    return Scaffold(
      appBar: AppBar(title: Text(data?.project?.name ?? 'Trình chiếu')),
      body: kit.Screen(
        onRefresh: () async {
          if (stackProvider != null) {
            ref.invalidate(stackProvider);
            await ref.read(stackProvider.future);
          }
        },
        slivers: [
          if (stack?.value case final plan?)
            StackGrid(
              sliver: true,
              plan: plan,
              priceLabel: true,
              onOpen: (id) {
                setState(() => unitId = id);
                _revealDetail();
              },
            ),
        ],
        children: [
          kit.AsyncView(
            value: board,
            onRetry: () => ref.invalidate(boardProvider),
            builder: (b) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                if ([
                  b.project?.developerName,
                  b.project?.district,
                  b.project?.province,
                ].any((s) => s?.isNotEmpty == true))
                  kit.Muted(
                    [
                          b.project?.developerName,
                          b.project?.district,
                          b.project?.province,
                        ]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                kit.ChipRail(
                  children: [
                    for (final block in b.blocks)
                      kit.Chip(
                        label: block.name,
                        active: block.id == blockId,
                        onPress: () => setState(() {
                          if (block.id != blockId) unitId = null;
                          picked = block.id;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (unitId case final id?)
            _PresentationUnit(
              key: _detailKey,
              projectId: widget.projectId,
              unitId: id,
              onLoaded: _revealDetail,
              onClose: () => setState(() => unitId = null),
            ),
          if (stack?.error case ApiError(code: 'grid_too_large'))
            const kit.Notice(
              text: 'Toà này quá nhiều căn để trình chiếu dạng lưới — chọn toà khác hoặc dùng link chia sẻ.',
            )
          else if (stack != null)
            kit.AsyncView(
              value: stack,
              onRetry: () => ref.invalidate(stackProvider!),
              builder: (_) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _PresentationUnit extends ConsumerWidget {
  const _PresentationUnit({
    super.key,
    required this.projectId,
    required this.unitId,
    required this.onClose,
    required this.onLoaded,
  });
  final String projectId, unitId;
  final VoidCallback onClose;
  final VoidCallback onLoaded;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directions = ref.watch(fetchEnumsProvider).value?.directionLabels;
    final provider = fetchPresentationUnitProvider((
      projectId: projectId,
      unitId: unitId,
    ));
    ref.listen(provider, (previous, next) {
      if (next.hasValue && previous?.isLoading == true) onLoaded();
    });
    return kit.Card(
      children: [
        kit.AsyncView(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (u) {
            final type = [
              u.unitType,
              if (u.bedrooms != null) '${u.bedrooms}PN',
            ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kit.H2('Căn ${u.publicCode ?? u.code}'),
                kit.Row(
                  label: 'Trạng thái',
                  value: statusLabel[u.status] ?? '—',
                ),
                kit.Row(label: 'Loại', value: type.isEmpty ? '—' : type),
                kit.Row(
                  label: 'Diện tích',
                  value: fmtArea(u.areaNet ?? u.areaGross),
                ),
                kit.Row(
                  label: 'Hướng',
                  value: directions?[u.direction] ?? u.direction ?? '—',
                ),
                kit.Row(label: 'Giá', value: u.priceMinLabel ?? 'Liên hệ'),
              ],
            );
          },
        ),
        kit.Button(kind: 'link', title: 'Đóng', onPress: onClose),
      ],
    );
  }
}
