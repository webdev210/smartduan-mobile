import 'package:flutter/widgets.dart' hide Row;

import '../api/models.dart';
import 'format.dart';
import 'kit.dart';

class LoanResultCards extends StatelessWidget {
  const LoanResultCards({super.key, required this.r, this.child});
  final LoanResult r;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Card(
        children: [
          const H2('Kết quả'),
          Row(label: 'Giá', value: fmtMoney(r.price)),
          Row(
            label: 'Khoản vay',
            value:
                '${fmtMoney(r.loanAmount)} (${(r.loanRatio * 100).round()}%)',
          ),
          Row(
            label: 'Trả hàng tháng (kỳ đầu)',
            value: fmtMoney(r.monthlyPayment),
          ),
          Row(label: 'Tổng lãi', value: fmtMoney(r.totals.interest)),
          Row(label: 'Tổng trả', value: fmtMoney(r.totals.total)),
          Row(
            label: 'Ưu đãi',
            value:
                '${r.graceMonths} tháng · ${(r.supportedRate * 100).toStringAsFixed(2)}%',
          ),
          Row(
            label: 'Thả nổi',
            value: '${(r.floatingRate * 100).toStringAsFixed(2)}%',
          ),
          ?child,
        ],
      ),
      Card(
        children: [
          const H2('Lịch trả 12 kỳ đầu'),
          for (final s in r.schedule.take(12))
            Row(
              label: 'Kỳ ${s.period}',
              value: '${fmtMoney(s.total)} (gốc ${fmtMoney(s.principal)})',
            ),
        ],
      ),
    ],
  );
}
