import 'package:ionicons/ionicons.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/public.dart';
import 'kit.dart' as kit;
import 'project_card.dart';
import 'project_compare.dart';
import 'project_filter.dart';
import 'theme.dart' as c;

const _full = 'Tối đa 3 dự án';
typedef _PickerState = ({String q, bool full, int limit});
final _pickerProvider = NotifierProvider.autoDispose
    .family<_Picker, _PickerState, Object>(_Picker.new);

class _Picker extends Notifier<_PickerState> {
  _Picker(Object owner);
  @override
  _PickerState build() => (q: '', full: false, limit: 30);
  void search(String q) => state = (q: q, full: state.full, limit: 30);
  void full(bool value) =>
      state = (q: state.q, full: value, limit: state.limit);
  void more() =>
      state = (q: state.q, full: state.full, limit: state.limit + 30);
}

class CompareChip extends ConsumerStatefulWidget {
  const CompareChip({
    super.key,
    required this.code,
    required this.name,
    this.overlay = false,
  });
  final String code, name;
  final bool overlay;
  @override
  ConsumerState<CompareChip> createState() => _CompareChipState();
}

class _CompareChipState extends ConsumerState<CompareChip> {
  bool full = false, picker = false;
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void hold() {
    ref.read(projectCompareProvider.notifier).add(widget.code);
    setState(() => picker = true);
  }

  void toggle() {
    final rejected = !ref
        .read(projectCompareProvider.notifier)
        .toggle(widget.code);
    timer?.cancel();
    setState(() => full = rejected);
    if (rejected) {
      if (widget.overlay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(_full),
            duration: Duration(milliseconds: 2500),
          ),
        );
      }
      timer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => full = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(projectCompareProvider).contains(widget.code);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (full && !widget.overlay)
              const Text(
                _full,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.warn,
                ),
              ),
            Semantics(
              button: true,
              selected: on,
              label: 'So sánh ${widget.name}',
              hint: 'Giữ để chọn thêm dự án so sánh',
              onLongPress: hold,
              onTap: toggle,
              excludeSemantics: true,
              child: RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer
                      >(
                        () => LongPressGestureRecognizer(
                          duration: const Duration(milliseconds: 350),
                        ),
                        (instance) => instance.onLongPress = hold,
                      ),
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: toggle,
                  child: widget.overlay
                      ? SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: Material(
                              color: on
                                  ? c.brand
                                  : Colors.white.withValues(alpha: .94),
                              elevation: 1,
                              shadowColor: c.text,
                              shape: const CircleBorder(),
                              child: SizedBox.square(
                                dimension: 44,
                                child: Icon(
                                  Ionicons.gitCompareOutline,
                                  size: 22,
                                  color: on ? Colors.white : c.text,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: on ? c.brand : c.brandSoft,
                            border: Border.all(
                              color: on ? c.brand : c.dangerBorder,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 5,
                            children: [
                              Icon(
                                on
                                    ? Ionicons.checkmarkCircle
                                    : Ionicons.gitCompareOutline,
                                size: 15,
                                color: on ? Colors.white : c.brand,
                              ),
                              Flexible(
                                child: Text(
                                  on ? 'Đang so sánh' : 'So sánh',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: on ? Colors.white : c.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        ComparePicker(
          visible: picker,
          onClose: () => setState(() => picker = false),
        ),
      ],
    );
  }
}

class ComparePicker extends ConsumerStatefulWidget {
  const ComparePicker({
    super.key,
    required this.visible,
    required this.onClose,
  });
  final bool visible;
  final VoidCallback onClose;
  @override
  ConsumerState<ComparePicker> createState() => _ComparePickerState();
}

class _ComparePickerState extends ConsumerState<ComparePicker> {
  final owner = Object();
  void close() {
    ref.read(_pickerProvider(owner).notifier).full(false);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_pickerProvider(owner));
    // The consumer lives inside the sheet route so query/search changes update it.
    return kit.Sheet(
      visible: widget.visible,
      onClose: close,
      title: 'So sánh dự án',
      scrollBody: false,
      footer: Consumer(
        builder: (context, ref, _) {
          final picked = ref.watch(projectCompareProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              kit.Muted(
                'Đã chọn ${picked.length}/$maxCompareProjects',
                style: const TextStyle(fontSize: 14),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  kit.Button(
                    kind: 'secondary',
                    size: 'sm',
                    title: 'Xoá',
                    disabled: picked.isEmpty,
                    onPress: () =>
                        ref.read(projectCompareProvider.notifier).clear(),
                  ),
                  kit.Button(
                    size: 'sm',
                    title: 'So sánh (${picked.length})',
                    disabled: picked.length < 2,
                    onPress: () {
                      close();
                      context.push('/so-sanh-du-an');
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
      child: Consumer(
        builder: (context, ref, _) {
          final picked = ref.watch(projectCompareProvider);
          final state = ref.watch(_pickerProvider(owner));
          final catalog = widget.visible
              ? ref.watch(listAllPublicProjectsProvider)
              : const AsyncValue<List<PublicProject>>.loading();
          final all = catalog.asData?.value ?? <PublicProject>[];
          final matches = [
            for (final code in picked)
              ...all.where((p) => p.code == code).take(1),
            ...filterProjects(
              all,
              ProjectFilter(q: state.q),
              const {},
            ).where((p) => !picked.contains(p.code)),
          ];
          final rows = matches.take(state.limit).toList();
          return ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount:
                1 + (!catalog.isLoading && !catalog.hasError ? rows.length : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    kit.SearchBar(
                      value: state.q,
                      onChangeText: ref
                          .read(_pickerProvider(owner).notifier)
                          .search,
                      placeholder: 'Tên dự án, khu vực, chủ đầu tư…',
                      maxLength: 60,
                    ),
                    if (catalog.hasValue)
                      kit.Muted(
                        'Hiển thị ${rows.length}/${matches.length} dự án',
                      ),
                    if (matches.length > state.limit)
                      kit.Button(
                        title: 'Tải thêm',
                        kind: 'secondary',
                        onPress: ref.read(_pickerProvider(owner).notifier).more,
                      ),
                    if (state.full)
                      const kit.Notice(
                        tone: 'warn',
                        text: '$_full. Bỏ bớt một dự án để chọn thêm.',
                      ),
                    if (catalog.isLoading)
                      const kit.Loading()
                    else if (catalog.hasError)
                      kit.ErrorBox(
                        error: catalog.error!,
                        onRetry: () =>
                            ref.invalidate(listAllPublicProjectsProvider),
                      )
                    else if (rows.isEmpty)
                      const kit.Muted('Không có dự án khớp.'),
                  ],
                );
              }
              final p = rows[index - 1];
              return Semantics(
                checked: picked.contains(p.code),
                label: 'Chọn ${p.name}',
                onTap: () => ref
                    .read(_pickerProvider(owner).notifier)
                    .full(
                      !ref.read(projectCompareProvider.notifier).toggle(p.code),
                    ),
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => ref
                      .read(_pickerProvider(owner).notifier)
                      .full(
                        !ref
                            .read(projectCompareProvider.notifier)
                            .toggle(p.code),
                      ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: picked.contains(p.code) ? c.brandSoft : c.card,
                      border: Border.all(
                        color: picked.contains(p.code) ? c.brand : c.line,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ProjectMedia(
                              compact: true,
                              name: p.name,
                              uri: p.coverUrl,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              kit.Muted(
                                [p.province, developerOf(p)]
                                        .whereType<String>()
                                        .where((s) => s.isNotEmpty)
                                        .join(' · ')
                                        .isEmpty
                                    ? '—'
                                    : [p.province, developerOf(p)]
                                          .whereType<String>()
                                          .where((s) => s.isNotEmpty)
                                          .join(' · '),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          picked.contains(p.code)
                              ? Ionicons.checkbox
                              : Ionicons.squareOutline,
                          color: picked.contains(p.code) ? c.brand : c.subtle,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CompareDock extends ConsumerStatefulWidget {
  const CompareDock({super.key, this.bottom});
  final double? bottom;
  @override
  ConsumerState<CompareDock> createState() => _CompareDockState();
}

class _CompareDockState extends ConsumerState<CompareDock> {
  bool picker = false;
  @override
  Widget build(BuildContext context) {
    final picked = ref.watch(projectCompareProvider);
    if (picked.isEmpty) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 16,
          right: 16,
          bottom:
              widget.bottom ??
              math.max(MediaQuery.paddingOf(context).bottom, 12),
          child: kit.Card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            style: BoxDecoration(
              border: Border.all(color: c.gold),
              borderRadius: BorderRadius.circular(18),
              boxShadow: c.floatShadow,
            ),
            child: Row(
              spacing: 12,
              children: [
                IconButton(
                  tooltip: 'Bỏ hết dự án đang so sánh',
                  onPressed: () =>
                      ref.read(projectCompareProvider.notifier).clear(),
                  icon: const Icon(Ionicons.close, size: 20, color: c.muted),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Chọn thêm dự án so sánh',
                    excludeSemantics: true,
                    onTap: () => setState(() => picker = true),
                    child: InkWell(
                      onTap: () => setState(() => picker = true),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'So sánh ${picked.length}/$maxCompareProjects dự án',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          kit.Muted(
                            picked.length < 2
                                ? 'Chọn thêm ít nhất 1 dự án'
                                : 'Chạm để thêm / bỏ',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: kit.Button(
                    size: 'sm',
                    title: 'So sánh',
                    disabled: picked.length < 2,
                    onPress: () => context.push('/so-sanh-du-an'),
                  ),
                ),
              ],
            ),
          ),
        ),
        ComparePicker(
          visible: picker,
          onClose: () => setState(() => picker = false),
        ),
      ],
    );
  }
}
