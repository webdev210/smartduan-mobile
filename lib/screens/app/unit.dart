import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/errors.dart';
import '../../api/content.dart' show fetchPolicyScopesProvider;
import '../../api/sales.dart';
import '../../api/units.dart';
import '../../api/unit_compare.dart' show unitCompareProvider;
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/unit_compare_picker.dart';
import 'project_history.dart' show historyFields, historyValue;

final unitCompareAddProvider = NotifierProvider.autoDispose
    .family<UnitCompareAdd, AsyncValue<bool>, String>(UnitCompareAdd.new);

class UnitCompareAdd extends Notifier<AsyncValue<bool>> {
  UnitCompareAdd(this.id);
  final String id;
  @override
  AsyncValue<bool> build() {
    ref.watch(sessionProvider);
    return const AsyncData(false);
  }

  Future<void> add() async {
    if (state.isLoading) return;
    final session = ref.read(sessionProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(addCompareProvider)(id);
      return true;
    });
    if (ref.mounted && identical(session, ref.read(sessionProvider))) {
      state = result;
      if (result.hasValue) {
        ref.invalidate(fetchCompareProvider);
        ref.invalidate(unitCompareProvider);
      }
    }
  }
}

class UnitScreen extends ConsumerStatefulWidget {
  const UnitScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends ConsumerState<UnitScreen> {
  bool picker = false;
  bool allHistory = false;
  bool allImages = false;
  bool policies = false;
  SessionState? loggedSession;
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final enums = ref.watch(fetchEnumsProvider).value;
    final detail = ref.watch(fetchUnitDetailProvider(widget.id));
    final u = detail.value;
    final images = u == null
        ? null
        : ref.watch(fetchUnitImagesProvider(widget.id));
    final history = u == null
        ? null
        : ref.watch(fetchUnitHistoryProvider(widget.id));
    final compare = ref.watch(unitCompareAddProvider(widget.id));
    if (u != null && !identical(loggedSession, session)) {
      loggedSession = session;
      unawaited(
        Future<void>.microtask(() {
          if (mounted && identical(session, ref.read(sessionProvider))) {
            return ref.read(logActivityProvider)({
              'kind': 'unit',
              'project_id': u.projectId,
              'target': u.code,
            });
          }
        }),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(u?.publicCode ?? u?.code ?? 'Chi tiết căn')),
      bottomNavigationBar: u == null
          ? null
          : SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        kit.Sheet(
                          visible: policies,
                          title: 'Chính sách dự án',
                          onClose: () => setState(() => policies = false),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final provider = fetchPolicyScopesProvider(
                                u.projectId,
                              );
                              return kit.AsyncView(
                                value: ref.watch(provider),
                                onRetry: () => ref.invalidate(provider),
                                builder: (list) => Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 16,
                                  children: [
                                    if (list.isEmpty)
                                      const kit.Muted(
                                        'Chưa có chính sách dự án.',
                                      ),
                                    for (final p in list) ...[
                                      kit.H2(p.title),
                                      kit.Muted(
                                        '${p.fund == null || p.fund!.isEmpty ? 'CSBH chung' : enums?.fundLabels[p.fund] ?? p.fund} · Hiệu lực ${fmtDate(p.effectiveFrom)}',
                                      ),
                                      if (p.summary?.isNotEmpty == true)
                                        kit.Body(p.summary!),
                                      if (p.fileUrl case final url?
                                          when url.isNotEmpty)
                                        kit.Button(
                                          title: 'Xem chính sách',
                                          kind: 'link',
                                          onPress: () =>
                                              openInApp(context, url, p.title),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        kit.ButtonGroup(
                          spacing: 8,
                          children: [
                            kit.Button(
                              title: 'Tính lãi vay căn này',
                              onPress: () => context.push(
                                Uri(
                                  path: '/lai-vay',
                                  queryParameters: {
                                    'unitId': u.id,
                                    'code': u.publicCode ?? u.code,
                                  },
                                ).toString(),
                              ),
                            ),
                            if (screens['compare']!(session.roles))
                              kit.Button(
                                kind: 'secondary',
                                icon: compare.asData?.value == true
                                    ? Ionicons.checkmarkCircle
                                    : Ionicons.gitCompareOutline,
                                title: compare.asData?.value == true
                                    ? 'Đã thêm · chọn thêm căn'
                                    : 'Thêm vào so sánh',
                                loading: compare.isLoading,
                                onPress: () async {
                                  if (compare.asData?.value == true) {
                                    setState(() => picker = true);
                                  } else {
                                    await ref
                                        .read(
                                          unitCompareAddProvider(widget.id)
                                              .notifier,
                                        )
                                        .add();
                                    if (mounted &&
                                        ref
                                                .read(
                                                  unitCompareAddProvider(
                                                    widget.id,
                                                  ),
                                                )
                                                .asData
                                                ?.value ==
                                            true) {
                                      setState(() => picker = true);
                                    }
                                  }
                                },
                                onLongPress: () {
                                  if (compare.asData?.value != true &&
                                      !compare.isLoading) {
                                    ref
                                        .read(
                                          unitCompareAddProvider(widget.id)
                                              .notifier,
                                        )
                                        .add();
                                  }
                                  setState(() => picker = true);
                                },
                              ),
                          ],
                        ),
                        if (screens['compare']!(session.roles)) ...[
                          if (compare.hasError)
                            kit.Notice(
                              tone: 'error',
                              text: errorMessage(compare.error),
                            ),
                          UnitComparePicker(
                            projectId: u.projectId,
                            visible: picker,
                            onClose: () {
                              setState(() => picker = false);
                              ref.invalidate(fetchCompareProvider);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: u == null
          ? kit.Screen(
              children: [
                kit.AsyncView(
                  value: detail,
                  onRetry: () =>
                      ref.invalidate(fetchUnitDetailProvider(widget.id)),
                  builder: (_) => const SizedBox.shrink(),
                ),
              ],
            )
          : kit.ListScreen<UnitImage>(
              data: allImages
                  ? images?.value?.data ?? const []
                  : images?.value?.data.take(1).toList() ?? const [],
              keyOf: (image) => image.id,
              renderItem: (img) => AppNetworkImage(
                img.url,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 220,
                  child: Icon(Ionicons.imageOutline),
                ),
              ),
              onRefresh: () =>
                  ref.refresh(fetchUnitDetailProvider(widget.id).future),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (detail.isLoading) const kit.Loading(),
                  if (detail.hasError)
                    kit.ErrorBox(
                      error: detail.error,
                      onRetry: () =>
                          ref.invalidate(fetchUnitDetailProvider(widget.id)),
                    ),
                  if (images?.hasError == true &&
                      images?.value?.data.isNotEmpty == true)
                    kit.ErrorBox(
                      error: images!.error,
                      onRetry: () =>
                          ref.invalidate(fetchUnitImagesProvider(widget.id)),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      kit.H1(u.publicCode ?? u.code),
                      Text(
                        statusLabel[u.status] ?? u.status,
                        style: TextStyle(
                          color: Color(
                            int.parse(
                              (statusColor[u.status] ?? '#9ca3af').replaceFirst(
                                '#',
                                'ff',
                              ),
                              radix: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (u.title.isNotEmpty) kit.Muted(u.title),
                  kit.Muted(
                    [
                      if (u.bedrooms != null) '${u.bedrooms}PN',
                      '${u.areaNet != null ? 'Thông thuỷ' : 'Tim tường'} ${fmtArea(u.areaNet ?? u.areaGross)}',
                      enums?.directionLabels[u.direction] ??
                          u.direction ??
                          'Chưa có hướng',
                    ].join(' · '),
                  ),
                  kit.Body(
                    fmtPrice(u.priceMin ?? u.priceList),
                    selectable: true,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  kit.Muted(
                    u.priceMinLabel ??
                        (u.priceMin != null && u.priceMin != ''
                            ? 'Giá tốt nhất'
                            : 'Giá niêm yết'),
                  ),
                  if (images?.value?.priceSheet?.url ?? u.priceSheetUrl
                      case final url? when url.isNotEmpty)
                    kit.Button(
                      kind: 'link',
                      title: 'Phiếu giá',
                      onPress: () => openInApp(context, url, 'Phiếu tính giá'),
                    ),
                  kit.Button(
                    kind: 'link',
                    title: 'Chính sách dự án',
                    onPress: () => setState(() => policies = true),
                  ),
                ],
              ),
              empty: images == null
                  ? null
                  : kit.AsyncView(
                      value: images,
                      onRetry: () =>
                          ref.invalidate(fetchUnitImagesProvider(widget.id)),
                      builder: (_) => const kit.Muted('Chưa có hình ảnh.'),
                    ),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      const kit.H2('Thông tin'),
                      kit.Row(label: 'Toà', value: u.block?.name ?? '—'),
                      kit.Row(
                        label: 'Tầng / trục',
                        value: '${u.floor ?? '—'} / ${u.axis ?? '—'}',
                      ),
                      kit.Row(label: 'Loại căn', value: u.unitType ?? '—'),
                      kit.Row(
                        label: 'DT tim tường',
                        value: fmtArea(u.areaGross),
                      ),
                      if (u.areaLand != null && u.areaLand != '')
                        kit.Row(label: 'DT đất', value: fmtArea(u.areaLand)),
                      kit.Row(label: 'View', value: u.view ?? '—'),
                      kit.Row(
                        label: 'Bàn giao',
                        value: u.handoverStandard ?? '—',
                      ),
                      if (u.heldBy != null && u.heldBy != '')
                        kit.Row(label: 'Đại lý giữ', value: u.heldBy!),
                      if (u.status == 'reserved' && u.reservedUntil != null)
                        kit.Row(
                          label: 'Giữ đến',
                          value: fmtDate(u.reservedUntil, true),
                        ),
                      if (u.keySellingPoint != null && u.keySellingPoint != '')
                        kit.Body(u.keySellingPoint!),
                    ],
                  ),
                  if ((images?.value?.data.length ?? 0) > 1)
                    kit.Button(
                      kind: 'link',
                      title: allImages
                          ? 'Thu gọn hình ảnh'
                          : 'Xem tất cả ${images!.value!.data.length} hình ảnh',
                      onPress: () => setState(() => allImages = !allImages),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      const kit.H2('Giá'),
                      kit.Row(
                        label: u.priceMinLabel ?? 'Giá tốt nhất',
                        value: fmtPrice(u.priceMin),
                      ),
                      for (final line in unitPriceLines(u.toJson()))
                        if (line case {
                          'label': final String label,
                          'prices': final List<Object?> prices,
                        }) ...[
                          if (prices.any(
                            (p) => !sameMainPrice(
                              u,
                              '${(p as Map<String, Object?>)['label']}',
                              p['value'],
                            ),
                          ))
                            kit.Muted(label),
                          for (final p in prices)
                            if (!sameMainPrice(
                              u,
                              '${(p as Map<String, Object?>)['label']}',
                              p['value'],
                            ))
                              kit.Row(
                                label: '${p['label']}',
                                value: fmtPrice(p['value']),
                              ),
                        ] else if (!sameMainPrice(
                          u,
                          line['label'] as String,
                          line['value'],
                        ))
                          kit.Row(
                            label: line['label'] as String,
                            value: fmtPrice(line['value']),
                          ),
                      kit.Row(
                        label: 'Đơn giá',
                        value: u.pricePerSqm != null && u.pricePerSqm != ''
                            ? '${fmtPrice(u.pricePerSqm)}/m²'
                            : '—',
                      ),
                      if (u.priceNote != null && u.priceNote != '')
                        kit.Muted(u.priceNote!),
                      if (u.priceSheetNote != null && u.priceSheetNote != '')
                        kit.Muted(u.priceSheetNote!),
                      kit.Muted(
                        'Cập nhật ${fmtDate(u.updatedAt, true)} · Xác nhận ${fmtDate(u.verifiedAt, true)}',
                      ),
                    ],
                  ),
                  if (u.related.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        const kit.H2('Có thể bạn quan tâm'),
                        for (final r in u.related)
                          kit.Row(
                            label:
                                '${r.code}${r.unitType == null ? '' : ' · ${r.unitType}'}',
                            value: fmtPrice(r.priceMin),
                          ),
                      ],
                    ),
                  if (history != null)
                    kit.AsyncView(
                      value: history,
                      onRetry: () =>
                          ref.invalidate(fetchUnitHistoryProvider(widget.id)),
                      builder: (data) => data.data.isEmpty
                          ? const kit.Muted('Chưa có lịch sử thay đổi.')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 8,
                              children: [
                                const kit.H2('Lịch sử thay đổi'),
                                kit.Muted(
                                  'Hiển thị ${allHistory
                                      ? data.data.length
                                      : data.data.length > 15
                                      ? 15
                                      : data.data.length}/${data.total > data.data.length ? data.total : data.data.length} thay đổi gần nhất',
                                ),
                                for (final h
                                    in allHistory
                                        ? data.data
                                        : data.data.take(15))
                                  kit.Muted(
                                    '${fmtDate(h.changedAt, true)} · ${historyFields[h.field] ?? h.field}: ${historyValue(h.field, h.oldValue, enums?.fundLabels ?? const {})} → ${historyValue(h.field, h.newValue, enums?.fundLabels ?? const {})}',
                                  ),
                                if (data.data.length > 15)
                                  kit.Button(
                                    title: allHistory
                                        ? 'Thu gọn'
                                        : 'Xem thêm (${data.data.length - 15})',
                                    kind: 'link',
                                    onPress: () => setState(
                                      () => allHistory = !allHistory,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}

bool sameMainPrice(UnitDetail u, String label, Object? value) =>
    label == (u.priceMinLabel ?? 'Giá tốt nhất') &&
    value != null &&
    u.priceMin != null &&
    ('$value' == u.priceMin ||
        (num.tryParse('$value') != null &&
            num.tryParse('$value') == num.tryParse(u.priceMin!)));
