import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/errors.dart';
import '../../api/projects.dart';
import '../../api/sales.dart';
import '../../auth/session.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/loan_result_cards.dart';
import '../../ui/search.dart';

final loanResultProvider = NotifierProvider.autoDispose
    .family<LoanController, AsyncValue<LoanResult>?, Object>(
      LoanController.new,
    );

class LoanController extends Notifier<AsyncValue<LoanResult>?> {
  LoanController(Object owner);
  @override
  AsyncValue<LoanResult>? build() {
    ref.watch(sessionProvider);
    return null;
  }

  Future<void> calculate(Map<String, dynamic> body) async {
    if (state?.isLoading == true) return;
    final session = ref.read(sessionProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(calculateLoanProvider)(body),
    );
    if (ref.mounted && identical(session, ref.read(sessionProvider))) {
      state = result;
    }
  }
}

class LoanScreen extends ConsumerStatefulWidget {
  const LoanScreen({super.key, this.unitId, this.code});
  final String? unitId, code;
  @override
  ConsumerState<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends ConsumerState<LoanScreen> {
  final owner = Object();
  String? projectId;
  String projectQuery = '';
  String price = '', ratio = '70', term = '240', rate = '', grace = '';
  Object? validation;
  Object? submitted;
  bool overrides = false;
  final resultKey = GlobalKey();
  Object get inputs =>
      (widget.unitId, projectId, price, ratio, term, rate, grace);
  void calculate() {
    if (widget.unitId == null && (projectId == null || price.isEmpty)) return;
    if (ref.read(loanResultProvider(owner))?.isLoading == true) return;
    final r = num.tryParse(ratio.isEmpty ? '0' : ratio),
        t = num.tryParse(term.isEmpty ? '0' : term);
    final a = rate.isEmpty ? null : num.tryParse(rate.replaceAll(',', '.'));
    final g = grace.isEmpty ? null : num.tryParse(grace);
    if (r == null ||
        !r.isFinite ||
        t == null ||
        !t.isFinite ||
        (rate.isNotEmpty && (a == null || !a.isFinite)) ||
        (grace.isNotEmpty && (g == null || !g.isFinite))) {
      setState(
        () => validation = ApiError(
          422,
          'validation',
          'Dữ liệu không hợp lệ',
          details: {
            if (r == null || !r.isFinite)
              'loan_ratio': ['Nhập tỷ lệ vay bằng số.'],
            if (t == null || !t.isFinite)
              'term_months': ['Nhập thời hạn bằng số tháng.'],
            if (rate.isNotEmpty && (a == null || !a.isFinite))
              'floating_rate': ['Nhập lãi suất bằng số.'],
            if (grace.isNotEmpty && (g == null || !g.isFinite))
              'grace_months': ['Nhập số tháng ưu đãi bằng số.'],
          },
        ),
      );
      return;
    }
    setState(() {
      validation = null;
      submitted = inputs;
    });
    FocusScope.of(context).unfocus();
    ref.read(loanResultProvider(owner).notifier).calculate({
      if (widget.unitId != null)
        'unit_id': widget.unitId
      else ...{
        'project_id': projectId,
        'price': price.replaceAll(RegExp(r'\D'), ''),
      },
      'loan_ratio': r,
      'term_months': t,
      'floating_rate': ?a,
      'grace_months': ?g,
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(loanResultProvider(owner));
    ref.listen(loanResultProvider(owner), (_, next) {
      if (next?.hasValue == true && submitted == inputs) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = resultKey.currentContext;
          if (mounted && target != null) Scrollable.ensureVisible(target);
        });
      }
    });
    final error = validation ?? result?.error;
    final projects = widget.unitId == null
        ? ref.watch(fetchAllProjectsProvider)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Tính lãi vay')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: kit.Button(
            title: 'Tính',
            loading: result?.isLoading == true,
            disabled:
                widget.unitId == null && (projectId == null || price.isEmpty),
            onPress: calculate,
          ),
        ),
      ),
      body: kit.Screen(
        children: [
          if (widget.unitId != null)
            kit.Muted(
              'Căn ${widget.code ?? widget.unitId} — giá vay lấy từ căn (giá vay nếu có, không thì giá niêm yết).',
            )
          else ...[
            const kit.Muted('Chọn dự án'),
            kit.AsyncView(
              value: projects!,
              onRetry: () => ref.invalidate(fetchAllProjectsProvider),
              builder: (items) {
                if (items.isEmpty) {
                  return const kit.Empty(text: 'Chưa có dự án.');
                }
                final matches = smartFilter(
                  items,
                  items.length > 12 ? projectQuery : '',
                  (p) => [p.name],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    if (items.length > 12)
                      kit.SearchBar(
                        value: projectQuery,
                        onChangeText: (s) => setState(() => projectQuery = s),
                        placeholder: 'Tìm dự án…',
                      ),
                    kit.Chips(
                      children: [
                        for (final p in items.where(
                          (p) => p.id == projectId || matches.contains(p),
                        ))
                          kit.Chip(
                            label: p.name,
                            active: projectId == p.id,
                            onPress: () => setState(() => projectId = p.id),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            kit.Field(
              label: 'Giá căn (đồng)',
              textInputAction: TextInputAction.next,
              value: price,
              onChangeText: (s) => setState(() => price = s),
              keyboardType: TextInputType.number,
              error: fieldError(error, 'price'),
            ),
          ],
          kit.Field(
            label: 'Tỷ lệ vay (%)',
            textInputAction: TextInputAction.next,
            value: ratio,
            onChangeText: (s) => setState(() => ratio = s),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: fieldError(error, 'loan_ratio'),
          ),
          kit.Field(
            label: 'Thời hạn (tháng)',
            textInputAction: TextInputAction.next,
            value: term,
            onChangeText: (s) => setState(() => term = s),
            keyboardType: TextInputType.number,
            error: fieldError(error, 'term_months'),
          ),
          kit.Chips(
            children: [
              for (final years in [10, 15, 20, 25, 30])
                kit.Chip(
                  label: '$years năm',
                  active: term == '${years * 12}',
                  onPress: () => setState(() => term = '${years * 12}'),
                ),
            ],
          ),
          kit.Button(
            kind: 'link',
            title: overrides
                ? 'Ẩn điều chỉnh lãi suất'
                : 'Điều chỉnh lãi suất / ưu đãi',
            onPress: () => setState(() => overrides = !overrides),
          ),
          if (overrides ||
              fieldError(error, 'floating_rate') != null ||
              fieldError(error, 'grace_months') != null) ...[
            kit.Field(
              label: 'Lãi thả nổi (%/năm) — bỏ trống = theo CSBH',
              textInputAction: TextInputAction.next,
              value: rate,
              onChangeText: (s) => setState(() => rate = s),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              error: fieldError(error, 'floating_rate'),
            ),
            kit.Field(
              label: 'Số tháng ưu đãi — bỏ trống = theo CSBH',
              textInputAction: TextInputAction.done,
              onSubmit: (_) => calculate(),
              value: grace,
              onChangeText: (s) => setState(() => grace = s),
              keyboardType: TextInputType.number,
              error: fieldError(error, 'grace_months'),
            ),
          ],
          if (error != null)
            kit.Notice(tone: 'error', text: errorMessage(error)),
          if (result?.asData?.value case final r? when submitted == inputs)
            LoanResultCards(
              key: resultKey,
              r: r,
              child: kit.Muted(loanTermsLabel(r)),
            ),
        ],
      ),
    );
  }
}
