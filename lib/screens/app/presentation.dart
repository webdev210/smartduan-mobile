import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/projects.dart';
import '../../api/units.dart' show fetchEnumsProvider;
import '../../auth/roles.dart';
import '../../auth/session.dart';
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
  String viewMode = 'grid';
  bool confirmingExit = false;
  Future<void> exit() async {
    if (confirmingExit) return;
    confirmingExit = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Kết thúc trình chiếu?'),
        content: const Text('Bạn sẽ quay lại màn hình làm việc nội bộ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục trình chiếu'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    confirmingExit = false;
    if (leave == true && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/du-an/${Uri.encodeComponent(widget.projectId)}');
      }
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kết thúc trình chiếu',
            onPressed: exit,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(data?.project?.name ?? 'Trình chiếu'),
        ),
        body: kit.Screen(
          onRefresh: () async {
            ref.invalidate(boardProvider);
            if (stackProvider != null) ref.invalidate(stackProvider);
            final selected = unitId == null
                ? null
                : fetchPresentationUnitProvider((
                    projectId: widget.projectId,
                    unitId: unitId!,
                  ));
            if (selected != null) ref.invalidate(selected);
            await Future.wait([
              ref.read(boardProvider.future),
              if (stackProvider != null) ref.read(stackProvider.future),
              if (selected != null) ref.read(selected.future),
            ]);
          },
          slivers: [
            const SliverToBoxAdapter(child: SizedBox.shrink()),
            if (stack?.value case final plan?)
              StackGrid(
                sliver: true,
                viewMode: viewMode,
                plan: plan,
                priceLabel: true,
                onOpen: (id) {
                  setState(() => unitId = id);
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
                  kit.Segmented(
                    value: viewMode,
                    onChange: (value) => setState(() => viewMode = value),
                    options: const [
                      (key: 'grid', label: 'Sơ đồ', count: null),
                      (key: 'list', label: 'Danh sách', count: null),
                    ],
                  ),
                ],
              ),
            ),
            if (stack?.error case ApiError(code: 'grid_too_large'))
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const kit.Notice(
                    text: 'Toà này quá nhiều căn để trình chiếu dạng lưới — chọn toà khác hoặc dùng link chia sẻ.',
                  ),
                  if (screens['shareLinks']!(ref.watch(sessionProvider).roles))
                    kit.Button(
                      title: 'Mở chia sẻ',
                      onPress: () => context.push(
                        '/chia-se/${Uri.encodeComponent(widget.projectId)}',
                      ),
                    ),
                ],
              )
            else if (stack != null)
              kit.AsyncView(
                value: stack,
                onRetry: () => ref.invalidate(stackProvider!),
                builder: (_) => const SizedBox.shrink(),
              ),
            kit.Sheet(
              visible: unitId != null,
              title: 'Thông tin căn',
              onClose: () => setState(() => unitId = null),
              child: unitId == null
                  ? const SizedBox.shrink()
                  : _PresentationUnit(
                      projectId: widget.projectId,
                      unitId: unitId!,
                      onClose: () => setState(() => unitId = null),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresentationUnit extends ConsumerWidget {
  const _PresentationUnit({
    required this.projectId,
    required this.unitId,
    required this.onClose,
  });
  final String projectId, unitId;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directions = ref.watch(fetchEnumsProvider).value?.directionLabels;
    final provider = fetchPresentationUnitProvider((
      projectId: projectId,
      unitId: unitId,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
