import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/errors.dart';
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
              data: images?.value?.data ?? const [],
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
                  if (detail.isLoading) const LinearProgressIndicator(),
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
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(child: kit.H1(u.publicCode ?? u.code)),
                      kit.Pill(
                        label: statusLabel[u.status] ?? u.status,
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
                    ],
                  ),
                  if (u.title.isNotEmpty) kit.Muted(u.title),
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
                  kit.Card(
                    children: [
                      const kit.H2('Thông tin'),
                      kit.Row(label: 'Toà', value: u.block?.name ?? '—'),
                      kit.Row(
                        label: 'Tầng / trục',
                        value: '${u.floor ?? '—'} / ${u.axis ?? '—'}',
                      ),
                      kit.Row(label: 'Loại căn', value: u.unitType ?? '—'),
                      kit.Row(label: 'Phòng ngủ', value: u.bedrooms ?? '—'),
                      kit.Row(
                        label: 'DT tim tường',
                        value: fmtArea(u.areaGross),
                      ),
                      kit.Row(
                        label: 'DT thông thuỷ',
                        value: fmtArea(u.areaNet),
                      ),
                      if (u.areaLand != null && u.areaLand != '')
                        kit.Row(label: 'DT đất', value: fmtArea(u.areaLand)),
                      kit.Row(
                        label: 'Hướng',
                        value:
                            enums?.directionLabels[u.direction] ??
                            u.direction ??
                            '—',
                      ),
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
                  kit.Card(
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
                      if (images?.value?.priceSheet case final sheet?)
                        kit.Button(
                          kind: 'link',
                          title: 'Xem phiếu tính giá',
                          onPress: () =>
                              openInApp(context, sheet.url, 'Phiếu tính giá'),
                        )
                      else if (u.priceSheetUrl != null && u.priceSheetUrl != '')
                        kit.Button(
                          kind: 'link',
                          title: 'Mở phiếu tính giá',
                          onPress: () => openInApp(
                            context,
                            u.priceSheetUrl!,
                            'Phiếu tính giá',
                          ),
                        ),
                      kit.Muted(
                        'Cập nhật ${fmtDate(u.updatedAt, true)} · Xác nhận ${fmtDate(u.verifiedAt, true)}',
                      ),
                    ],
                  ),
                  kit.Button(
                    kind: 'secondary',
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
                  if (screens['compare']!(session.roles)) ...[
                    kit.Button(
                      kind: 'secondary',
                      icon: compare.asData?.value == true
                          ? Ionicons.checkmarkCircle
                          : Ionicons.gitCompareOutline,
                      title: compare.asData?.value == true
                          ? 'Đã thêm · chọn thêm căn'
                          : 'Thêm vào so sánh',
                      loading: compare.isLoading,
                      onPress: () {
                        if (compare.asData?.value == true) {
                          setState(() => picker = true);
                        } else {
                          ref
                              .read(unitCompareAddProvider(widget.id).notifier)
                              .add();
                        }
                      },
                      onLongPress: () {
                        if (compare.asData?.value != true &&
                            !compare.isLoading) {
                          ref
                              .read(unitCompareAddProvider(widget.id).notifier)
                              .add();
                        }
                        setState(() => picker = true);
                      },
                    ),
                    const kit.Muted(
                      'Giữ nút để chọn thêm căn cùng dự án',
                      textAlign: TextAlign.center,
                    ),
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
                  if (u.related.isNotEmpty)
                    kit.Card(
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
                          : kit.Card(
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
