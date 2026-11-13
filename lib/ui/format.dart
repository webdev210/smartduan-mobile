const statusLabel = {
  "available": "Còn hàng",
  "reserved": "Đang giữ",
  "booked": "Đã booking",
  "sold": "Đã bán",
  "hidden": "Ẩn",
};
const statusColor = {
  "available": "#15803d",
  "reserved": "#b45309",
  "booked": "#1d4ed8",
  "sold": "#6b7280",
  "hidden": "#9ca3af",
};
const bookingStatusLabel = {
  "declared": "Đã khai báo",
  "synced": "Đã ghi nhận",
  "confirmed": "Đã xác nhận",
  "rejected": "Đã từ chối",
};
num _number(Object? v) => v is num
    ? v
    : v is String
    ? (v.trim().isEmpty ? 0 : num.tryParse(v.trim()) ?? double.nan)
    : double.nan;
String _numberText(num n) => n.isFinite && n == n.truncateToDouble()
    ? n.toInt().toString()
    : n.toString();
// Decimal rounding matches Intl's halfExpand rather than binary toStringAsFixed ties.
String _vi(num value, [int maxFraction = 3]) {
  final negative = value.isNegative;
  final parts = value.abs().toString().toLowerCase().split('e');
  final mantissa = parts[0].split('.');
  final digits = mantissa.join();
  final scale =
      (mantissa.length > 1 ? mantissa[1].length : 0) -
      (parts.length > 1 ? int.parse(parts[1]) : 0);
  var integer = BigInt.parse(digits);
  final shift = scale - maxFraction;
  if (shift > 0) {
    final divisor = BigInt.from(10).pow(shift);
    integer = (integer + divisor ~/ BigInt.two) ~/ divisor;
  } else {
    integer *= BigInt.from(10).pow(-shift);
  }
  final padded = integer.toString().padLeft(maxFraction + 1, '0');
  var whole = maxFraction == 0
      ? padded
      : padded.substring(0, padded.length - maxFraction);
  final fraction = maxFraction == 0
      ? ''
      : padded
            .substring(padded.length - maxFraction)
            .replaceFirst(RegExp(r'0+$'), '');
  whole = whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '${negative ? '-' : ''}$whole${fraction.isEmpty ? '' : ',$fraction'}';
}

String fmtPrice(Object? value) {
  if (value == null || value == '') return '—';
  final n = _number(value);
  if (!n.isFinite) return '—';
  if (n >= 1e9) return '${_vi(n / 1e9, 2)} tỷ';
  if (n >= 1e6) return '${_vi(n / 1e6, 1)} tr';
  return _vi(n);
}

String priceLabel(Object? value) {
  final n = _number(value);
  return n.isFinite && n > 0 ? 'Giá từ ${fmtPrice(n)}' : 'Liên hệ';
}

String fmtMoney(num? n) =>
    n == null || !n.isFinite ? '—' : '${_vi((n + 0.5).floor(), 0)} đ';
String fmtDate(String? s, [bool withTime = false]) {
  if (s == null || s.isEmpty) return '—';
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  // RN date/time display uses Asia/Ho_Chi_Minh, including on non-Vietnamese hosts.
  final local = d.isUtc ? d.add(const Duration(hours: 7)) : d;
  String p(int x) => x.toString().padLeft(2, '0');
  final date = '${p(local.day)}/${p(local.month)}/${local.year}';
  return withTime ? '${p(local.hour)}:${p(local.minute)} $date' : date;
}

String dash(Object? value) => value == null || value == ''
    ? '—'
    : value is num
    ? _numberText(value)
    : '$value';
String fmtArea(String? value) =>
    value == null || value.isEmpty ? '—' : '$value m²';
const _priceFields = [
  ('price_list', 'Giá niêm yết'),
  ('price_loan', 'Giá vay'),
  ('price_progress', 'Giá theo tiến độ'),
  ('price_early', 'Giá thanh toán sớm'),
];

/// Untyped unit fields until the screen milestone introduces response models.
List<Map<String, Object?>> unitPriceLines(Map<String, Object?> unit) {
  final extras = unit['extra_prices'] as List? ?? [];
  return [
    for (final (field, label) in _priceFields)
      if (extras.any((p) => p is Map && p['field'] == field))
        {
          'field': field,
          'label': label,
          'prices': [
            for (final p in extras)
              if (p is Map && p['field'] == field)
                {'label': p['label'], 'value': p['value']},
          ],
        }
      else if (field == 'price_list' ||
          (unit[field] != null && unit[field] != ''))
        {'field': field, 'label': label, 'value': unit[field]},
  ];
}

/// Retained here for the download-link cases in RN format.test.ts.
String absoluteUrl(String url, String apiUrl) {
  if (RegExp(r'^https?://').hasMatch(url)) return url;
  final origin = apiUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
  return '$origin${url.startsWith('/') ? url : '/$url'}';
}
