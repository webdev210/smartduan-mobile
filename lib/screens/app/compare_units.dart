import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/sales.dart';
import '../../api/units.dart' show fetchEnumsProvider;
import '../../api/unit_compare.dart' show unitCompareProvider;
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;

class CompareUnitsScreen extends ConsumerStatefulWidget {
  const CompareUnitsScreen({super.key});
  @override
  ConsumerState<CompareUnitsScreen> createState() => _CompareUnitsScreenState();
}

class _CompareUnitsScreenState extends ConsumerState<CompareUnitsScreen> {
  bool busy = false;
  Object? error;
  Future<void> remove(String id) async {
    if (busy) return;
    final session = ref.read(sessionProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(removeCompareProvider)(id);
      if (mounted && identical(session, ref.read(sessionProvider))) {
        ref.invalidate(fetchCompareProvider);
        ref.invalidate(unitCompareProvider);
      }
    } catch (e) {
      if (mounted && identical(session, ref.read(sessionProvider))) {
        setState(() => error = e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(fetchCompareProvider);
    final directions = ref.watch(fetchEnumsProvider).value?.directionLabels;
    ref.listen(sessionProvider, (_, _) {
      if (mounted) setState(() => error = null);
    });
    return Scaffold(
      appBar: AppBar(title: const Text('So sánh căn')),
      body: kit.Screen(
        onRefresh: () => ref.refresh(fetchCompareProvider.future),
        children: [
          if (error != null) kit.ErrorBox(error: error),
          kit.AsyncView(
            value: query,
            onRetry: () => ref.invalidate(fetchCompareProvider),
            builder: (set) {
              if (set.units.isEmpty) {
                return const kit.Empty(
                  text:
                      'Chưa có căn nào. Mở chi tiết căn → “Thêm vào so sánh”.',
                );
              }
              final rows = <(String, String Function(CompareUnit))>[
                ('Dự án', (u) => u.project?.name ?? '—'),
                ('Trạng thái', (u) => statusLabel[u.status] ?? u.status),
                ('Loại', (u) => dash(u.unitType)),
                ('PN', (u) => dash(u.bedrooms)),
                ('Thông thuỷ', (u) => fmtArea(u.areaNet)),
                ('Tim tường', (u) => fmtArea(u.areaGross)),
                ('Hướng', (u) => directions?[u.direction] ?? dash(u.direction)),
                ('Giá tốt nhất', (u) => fmtPrice(u.priceMin)),
                (
                  'Đơn giá',
                  (u) => u.pricePerSqm == null || u.pricePerSqm == ''
                      ? '—'
                      : '${fmtPrice(u.pricePerSqm)}/m²',
                ),
                ('CSBH', (u) => u.policy?.name ?? '—'),
              ];
              Widget cell(Widget child, [double width = 140]) => SizedBox(
                width: width,
                child: Padding(padding: const EdgeInsets.all(6), child: child),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (set.removed.isNotEmpty)
                    kit.Notice(
                      tone: 'warn',
                      text:
                          '${set.removed.length} căn đã bị gỡ khỏi danh sách (không còn xem được).',
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 96),
                            for (final u in set.units)
                              cell(
                                Column(
                                  children: [
                                    TextButton(
                                      onPressed: () => context.push(
                                        '/can/${Uri.encodeComponent(u.id)}',
                                      ),
                                      child: Text(u.publicCode ?? u.code),
                                    ),
                                    kit.Button(
                                      title: 'Bỏ',
                                      kind: 'link',
                                      disabled: busy,
                                      onPress: () => remove(u.id),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        for (final (label, value) in rows)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cell(kit.Muted(label), 96),
                              for (final u in set.units)
                                cell(kit.Body(value(u))),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const kit.Muted('Vuốt ngang để xem thêm căn.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
