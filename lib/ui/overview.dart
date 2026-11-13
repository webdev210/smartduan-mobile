const _specLabels = {
  'scale': 'Quy mô',
  'quy_mo': 'Quy mô',
  'area': 'Diện tích khu đất',
  'dien_tich': 'Diện tích',
  'units': 'Số căn',
  'so_can': 'Số căn',
  'blocks': 'Số toà',
  'floors': 'Số tầng',
  'legal': 'Pháp lý',
  'phap_ly': 'Pháp lý',
  'handover': 'Bàn giao',
  'ban_giao': 'Bàn giao',
  'density': 'Mật độ xây dựng',
  'owner': 'Đơn vị phát triển',
  'contractor': 'Nhà thầu',
  'management': 'Đơn vị vận hành',
  'description': 'Giới thiệu',
};
const _summaryKeys = [
  'summary',
  'description',
  'mo_ta',
  'gioi_thieu',
  'tong_quan',
  'intro',
];
const _amenityKeys = ['amenities', 'tien_ich', 'utilities'];
const _planKeys = ['floor_plans', 'floorplans', 'mat_bang'];
const _consumed = {
  ..._summaryKeys,
  ..._amenityKeys,
  ..._planKeys,
  'timeline',
  'progress',
  'tien_do',
  'usp',
  'source_url',
  'researched_at',
};
String specLabel(String key) {
  final label = key.replaceAll(RegExp('[_-]+'), ' ');
  return _specLabels[key] ??
      (label.isEmpty ? '' : '${label[0].toUpperCase()}${label.substring(1)}');
}

String? _str(Object? v) => switch (v) {
  String s when s.trim().isNotEmpty => s.trim(),
  num n => n == n.truncateToDouble() ? n.toInt().toString() : n.toString(),
  _ => null,
};
Object? _pick(Map<String, dynamic>? o, List<String> keys) {
  for (final key in keys) {
    if (o?[key] != null) return o![key];
  }
  return null;
}

List<String> _toList(Object? v) {
  if (v is List) {
    return [
      for (final item in v)
        if ((item is Map
                ? _str(item['name']) ??
                      _str(item['label']) ??
                      _str(item['title'])
                : _str(item))
            case final String s)
          s,
    ];
  }
  return (_str(v)?.split(RegExp(r'\r?\n')) ?? [])
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

typedef Spec = ({String key, String label, String value});
typedef Overview = ({
  String? summary,
  List<String> usp,
  List<Spec> specs,
  String? source,
});
Overview parseOverview(Map<String, dynamic>? data) {
  final source = _str(_pick(data, ['source_url']));
  return (
    summary: _str(_pick(data, _summaryKeys)),
    usp: _toList(data?['usp']).take(10).toList(),
    specs: [
      for (final MapEntry(:key, :value)
          in (data ?? <String, dynamic>{}).entries)
        if (!_consumed.contains(key))
          if (_str(value) case final String s)
            (key: key, label: specLabel(key), value: s),
    ],
    source: source != null && RegExp(r'^https?://').hasMatch(source)
        ? source
        : null,
  );
}

List<String> amenitiesOf(Map<String, dynamic>? data) =>
    _toList(_pick(data, _amenityKeys));
List<({String name, String? url})> floorPlansOf(Map<String, dynamic>? data) {
  final v = _pick(data, _planKeys);
  if (v is! List) return [];
  return [for (final item in v) ..._link(item)];
}

List<({String name, String? url})> _link(Object? item) {
  if (item is Map) {
    final name =
        _str(item['name']) ?? _str(item['title']) ?? _str(item['label']);
    final url = _str(item['url']) ?? _str(item['image']) ?? _str(item['href']);
    return name != null || url != null ? [(name: name ?? 'Xem', url: url)] : [];
  }
  final name = _str(item);
  return name == null ? [] : [(name: name, url: null)];
}
