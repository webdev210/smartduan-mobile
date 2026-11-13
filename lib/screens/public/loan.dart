import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/public.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/loan_result_cards.dart';

final publicLoanResultProvider =
    NotifierProvider.autoDispose<PublicLoanController, AsyncValue<LoanResult>?>(
      PublicLoanController.new,
    );

class PublicLoanController extends Notifier<AsyncValue<LoanResult>?> {
  @override
  AsyncValue<LoanResult>? build() => null;
  Future<void> calculate(PublicLoanBody body) async {
    if (state?.isLoading == true) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(publicApiProvider).calculatePublicLoan(body),
    );
    if (ref.mounted) state = result;
  }
}

class LoanScreen extends ConsumerStatefulWidget {
  const LoanScreen({super.key});
  @override
  ConsumerState<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends ConsumerState<LoanScreen> {
  final resultKey = GlobalKey();
  String price = '', ratio = '70', term = '240', rate = '', grace = '';
  Object? validation;
  Object? submitted;
  Object get inputs => (price, ratio, term, rate, grace);
  void _calculate() {
    if (price.isEmpty) return;
    if (ref.read(publicLoanResultProvider)?.isLoading == true) return;
    final r = num.tryParse(ratio.trim().isEmpty ? '0' : ratio),
        t = int.tryParse(term.trim().isEmpty ? '0' : term),
        a = rate.isEmpty ? null : num.tryParse(rate.replaceFirst(',', '.')),
        g = grace.isEmpty ? null : int.tryParse(grace);
    if (r == null ||
        !r.isFinite ||
        t == null ||
        (rate.isNotEmpty && (a == null || !a.isFinite)) ||
        (grace.isNotEmpty && g == null)) {
      setState(
        () => validation = const ApiError(
          422,
          'validation',
          'Dữ liệu không hợp lệ',
        ),
      );
      return;
    }
    setState(() {
      validation = null;
      submitted = inputs;
    });
    FocusScope.of(context).unfocus();
    ref
        .read(publicLoanResultProvider.notifier)
        .calculate(
          PublicLoanBody(
            price: price.replaceAll(RegExp(r'\D'), ''),
            loanRatio: r,
            termMonths: t,
            annualRate: a,
            graceMonths: g,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(publicLoanResultProvider);
    ref.listen(publicLoanResultProvider, (_, next) {
      if (next?.hasValue == true && submitted == inputs) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = resultKey.currentContext;
          if (mounted && target != null) Scrollable.ensureVisible(target);
        });
      }
    });
    final error = validation ?? result?.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Tính lãi vay')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: kit.Button(
                title: 'Tính',
                loading: result?.isLoading == true,
                disabled: price.isEmpty,
                onPress: _calculate,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: kit.Screen(
          children: [
            const kit.Muted(
              'Ước tính tham khảo. Lãi suất bỏ trống = mức mặc định của sàn; chính sách vay thực tế theo từng dự án.',
            ),
            kit.Field(
              label: 'Giá căn (đồng)',
              textInputAction: TextInputAction.next,
              value: price,
              onChangeText: (s) => setState(() => price = s),
              keyboardType: TextInputType.number,
              error: fieldError(error, 'price'),
            ),
            kit.Field(
              label: 'Tỷ lệ vay (%)',
              textInputAction: TextInputAction.next,
              value: ratio,
              onChangeText: (s) => setState(() => ratio = s),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            kit.Field(
              label: 'Thời hạn (tháng)',
              textInputAction: TextInputAction.next,
              value: term,
              onChangeText: (s) => setState(() => term = s),
              keyboardType: TextInputType.number,
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
            kit.Field(
              label: 'Lãi suất (%/năm) — bỏ trống = mặc định',
              textInputAction: TextInputAction.next,
              value: rate,
              onChangeText: (s) => setState(() => rate = s),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            kit.Field(
              label: 'Số tháng ưu đãi',
              textInputAction: TextInputAction.done,
              onSubmit: (_) => _calculate(),
              value: grace,
              onChangeText: (s) => setState(() => grace = s),
              keyboardType: TextInputType.number,
            ),
            if (error != null)
              kit.Notice(tone: 'error', text: errorMessage(error)),
            if (result?.asData?.value case final r? when submitted == inputs)
              SizedBox(
                key: resultKey,
                child: LoanResultCards(r: r),
              ),
          ],
        ),
      ),
    );
  }
}
