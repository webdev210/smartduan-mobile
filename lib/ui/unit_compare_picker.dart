import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/errors.dart';
import '../api/unit_compare.dart';
import 'format.dart';
import 'kit.dart' as kit;
import 'search.dart';
import 'theme.dart' as c;

typedef _State = ({String q, bool busy, Object? error});
final _pickerProvider = NotifierProvider.autoDispose
    .family<_Picker, _State, Object>(_Picker.new);

class _Picker extends Notifier<_State> {
  _Picker(Object owner);
  @override
  _State build() => (q: '', busy: false, error: null);
  void search(String q) => state = (q: q, busy: state.busy, error: state.error);
  Future<void> toggle(String id, bool selected) async {
    if (state.busy) return;
    state = (q: state.q, busy: true, error: null);
    Object? error;
    try {
      final api = ref.read(unitCompareApiProvider);
      await (selected ? api.removeCompare(id) : api.addCompare(id));
    } catch (e) {
      error = e;
    } finally {
      if (ref.mounted) {
        ref.invalidate(unitCompareProvider);
        state = (q: state.q, busy: false, error: error);
      }
    }
  }
}

class UnitComparePicker extends ConsumerStatefulWidget {
  const UnitComparePicker({
    super.key,
    required this.projectId,
    required this.visible,
    required this.onClose,
  });
  final String projectId;
  final bool visible;
  final VoidCallback onClose;
  @override
  ConsumerState<UnitComparePicker> createState() => _UnitComparePickerState();
}

class _UnitComparePickerState extends ConsumerState<UnitComparePicker> {
  final owner = Object();
  @override
  Widget build(BuildContext context) {
    ref.watch(_pickerProvider(owner));
    return kit.Sheet(
      visible: widget.visible,
      onClose: widget.onClose,
      title: 'Chọn căn so sánh',
      footer: Consumer(
        builder: (context, ref, _) {
          final picked =
              ref.watch(unitCompareProvider).asData?.value ?? <String>[];
          return Row(
            spacing: 10,
            children: [
              Expanded(
                child: kit.Muted(
                  'Đã chọn ${picked.length}/4 căn',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              kit.Button(
                size: 'sm',
                title: 'So sánh (${picked.length})',
                disabled: picked.length < 2,
                onPress: () {
                  widget.onClose();
                  context.push('/so-sanh');
                },
              ),
            ],
          );
        },
      ),
      child: Consumer(
        builder: (context, ref, _) {
          final units = ref.watch(compareUnitsProvider(widget.projectId));
          final set = ref.watch(unitCompareProvider);
          final state = ref.watch(_pickerProvider(owner));
          final control = ref.read(_pickerProvider(owner).notifier);
          final picked = set.asData?.value ?? <String>[];
          final all = (units.asData?.value ?? <ComparePickerUnit>[]).where(
            (u) => u.status != 'hidden',
          );
          final words = fold(state.q).trim();
          final rows = [
            ...all.where((u) => picked.contains(u.id)),
            ...all.where(
              (u) =>
                  !picked.contains(u.id) &&
                  (words.isEmpty ||
                      fold(
                        '${u.publicCode ?? ''} ${u.code} ${u.unitType ?? ''}',
                      ).contains(words)),
            ),
          ].take(40);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              kit.SearchBar(
                value: state.q,
                onChangeText: control.search,
                placeholder: 'Mã căn, loại căn…',
                maxLength: 40,
                autoCapitalize: TextCapitalization.characters,
              ),
              if (state.error != null)
                kit.Notice(tone: 'error', text: errorMessage(state.error!)),
              if (units.isLoading || set.isLoading)
                const kit.Loading()
              else if (units.hasError || set.hasError)
                kit.ErrorBox(
                  error: units.error ?? set.error!,
                  onRetry: () {
                    if (units.hasError) {
                      ref.invalidate(compareUnitsProvider(widget.projectId));
                    } else {
                      ref.invalidate(unitCompareProvider);
                    }
                  },
                )
              else if (rows.isEmpty)
                const kit.Muted('Không có căn khớp.')
              else
                for (final u in rows)
                  Semantics(
                    label: 'Chọn căn ${u.publicCode ?? u.code}',
                    checked: picked.contains(u.id),
                    enabled: !state.busy,
                    onTap: state.busy
                        ? null
                        : () => control.toggle(u.id, picked.contains(u.id)),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: state.busy
                          ? null
                          : () => control.toggle(u.id, picked.contains(u.id)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: picked.contains(u.id) ? c.brandSoft : c.card,
                          border: Border.all(
                            color: picked.contains(u.id) ? c.brand : c.line,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          spacing: 12,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                  int.parse(
                                    (statusColor[u.status] ?? '#9ca3af')
                                        .replaceFirst('#', 'ff'),
                                    radix: 16,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 2,
                                children: [
                                  Text(
                                    u.publicCode ?? u.code,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  kit.Muted(
                                    [
                                          u.unitType,
                                          statusLabel[u.status],
                                          fmtPrice(u.priceMin ?? u.priceList),
                                        ]
                                        .whereType<String>()
                                        .where((s) => s.isNotEmpty)
                                        .join(' · '),
                                    numberOfLines: 1,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              picked.contains(u.id)
                                  ? Ionicons.checkbox
                                  : Ionicons.squareOutline,
                              color: picked.contains(u.id) ? c.brand : c.subtle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
