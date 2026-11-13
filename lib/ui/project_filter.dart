import '../api/models.dart';
import 'catalog.dart';
import 'regions.dart';
import 'search.dart';

export '../api/models.dart' show Browsable;

const projectStatus = {
  'upcoming': (label: 'Sắp mở bán', color: '#7c3da8'),
  'selling': (label: 'Đang bán', color: '#187544'),
  'sold_out': (label: 'Đã bán hết', color: '#52525b'),
  'paused': (label: 'Tạm dừng', color: '#52525b'),
};
const _statusOrder = ['selling', 'upcoming', 'sold_out', 'paused'];
const typeLabel = {
  'apartment': 'Căn hộ',
  'lowrise': 'Thấp tầng',
  'mixed': 'Cao tầng & thấp tầng',
  'resort': 'Nghỉ dưỡng',
  'land': 'Đất nền',
};
const _typeIncludes = {
  'apartment': ['apartment', 'mixed'],
  'lowrise': ['lowrise', 'land', 'mixed'],
};
bool _typeMatches(String? type, String picked) =>
    type != null && (_typeIncludes[picked] ?? [picked]).contains(type);
const priceBands = [
  (key: 'lt2', label: 'Dưới 2 tỷ', min: 0.0, max: 2e9),
  (key: '2to5', label: '2 – 5 tỷ', min: 2e9, max: 5e9),
  (key: '5to10', label: '5 – 10 tỷ', min: 5e9, max: 10e9),
  (key: 'gt10', label: 'Trên 10 tỷ', min: 10e9, max: double.infinity),
];
const sorts = [
  (key: 'default', label: 'Nổi bật'),
  (key: 'price_asc', label: 'Giá thấp → cao'),
  (key: 'price_desc', label: 'Giá cao → thấp'),
  (key: 'name', label: 'Tên A → Z'),
];

class ProjectFilter {
  const ProjectFilter({
    this.q = '',
    this.status,
    this.type,
    this.region,
    this.province,
    this.developer,
    this.price,
    this.sort = 'default',
  });
  final String q, sort;
  final String? status, type, region, province, developer, price;
}

const emptyProjectFilter = ProjectFilter();
typedef Option = ({String key, String label, int count});
typedef ActiveFilter = ({String key, String label});
typedef Suggestion = ({String kind, String label, int count});
String? developerOf(Browsable p) => p.developerName ?? p.developer?.name;
num? _priceOf(Browsable p) {
  final n = num.tryParse(p.priceFrom ?? '');
  return n != null && n.isFinite && n > 0 ? n : null;
}

final _regionKeys = <String, String?>{};
String? _regionKeyOf(Browsable p, Map<String, String> aliases) {
  final province = canonicalProvince(p.province, aliases);
  if (_regionKeys.containsKey(province)) return _regionKeys[province];
  final label = regionOf(province);
  final key = regions.where((r) => r.label == label).firstOrNull?.key;
  // ponytail: 2000 province spellings; use LRU if input grows beyond that.
  if (_regionKeys.length >= 2000) _regionKeys.clear();
  return _regionKeys[province] = key;
}

String _searchText(Browsable p, Map<String, String> aliases) => fold(
  [
    p.name,
    p.code,
    p.district,
    p.province,
    canonicalProvince(p.province, aliases),
    p.address,
    developerOf(p),
    typeLabel[p.projectType],
    projectStatus[p.status]?.label,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' '),
);
bool _keeps(
  Browsable p,
  ProjectFilter f,
  Map<String, String> aliases,
  List<String> words, [
  String? skip,
]) {
  if (words.isNotEmpty && !hasAll(_searchText(p, aliases), words)) return false;
  if (skip != 'status' &&
      f.status?.isNotEmpty == true &&
      p.status != f.status) {
    return false;
  }
  if (skip != 'type' &&
      f.type?.isNotEmpty == true &&
      !_typeMatches(p.projectType, f.type!)) {
    return false;
  }
  if (skip != 'region' &&
      f.region?.isNotEmpty == true &&
      _regionKeyOf(p, aliases) != f.region) {
    return false;
  }
  if (skip != 'province' &&
      f.province?.isNotEmpty == true &&
      canonicalProvince(p.province, aliases) !=
          canonicalProvince(f.province, aliases)) {
    return false;
  }
  if (skip != 'developer' &&
      f.developer?.isNotEmpty == true &&
      fold(developerOf(p)) != fold(f.developer)) {
    return false;
  }
  if (skip != 'price' && f.price?.isNotEmpty == true) {
    final band = priceBands.firstWhere((b) => b.key == f.price);
    final price = _priceOf(p);
    if (price == null || price < band.min || price >= band.max) return false;
  }
  return true;
}

int countProjectsWithoutStatus(
  List<Browsable> list,
  ProjectFilter filter,
  Map<String, String> aliases,
) {
  final words = tokens(filter.q);
  return list.where((p) => _keeps(p, filter, aliases, words, 'status')).length;
}

List<T> filterProjects<T extends Browsable>(
  List<T> list,
  ProjectFilter f,
  Map<String, String> aliases,
) {
  final words = tokens(f.q);
  final rows = list.where((p) => _keeps(p, f, aliases, words)).toList();
  final ranked = [
    for (var at = 0; at < rows.length; at++) (p: rows[at], at: at),
  ];
  ranked.sort((a, b) {
    int order;
    if (f.sort == 'name') {
      order = compareVietnamese(a.p.name, b.p.name);
    } else if (f.sort == 'price_asc' || f.sort == 'price_desc') {
      final x = _priceOf(a.p), y = _priceOf(b.p);
      order = x == null
          ? (y == null ? 0 : 1)
          : y == null
          ? -1
          : x.compareTo(y) * (f.sort == 'price_asc' ? 1 : -1);
    } else {
      order = words.isEmpty
          ? 0
          : titleScore(b.p.name, f.q).compareTo(titleScore(a.p.name, f.q));
    }
    return order != 0 ? order : a.at.compareTo(b.at);
  });
  return ranked.map((x) => x.p).toList();
}

Map<String, List<Option>> facets(
  List<Browsable> list,
  ProjectFilter f,
  Map<String, String> aliases,
) {
  final words = tokens(f.q);
  Map<String, int> tally(
    String facet,
    List<String?> Function(Browsable) keyOf,
  ) {
    final counts = <String, int>{};
    for (final p in list) {
      if (!_keeps(p, f, aliases, words, facet)) continue;
      for (final key in keyOf(p)) {
        if (key != null && key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Option> fixed(
    String facet,
    List<String?> Function(Browsable) keyOf,
    Iterable<String> order,
    String Function(String) labelOf,
    String? picked,
  ) {
    final counts = tally(facet, keyOf);
    return [
      for (final key in order)
        if (counts.containsKey(key) || key == picked)
          (key: key, label: labelOf(key), count: counts[key] ?? 0),
    ];
  }

  List<Option> open(
    String facet,
    String? Function(Browsable) keyOf,
    String? picked,
  ) {
    final counts = tally(facet, (p) => [keyOf(p)]);
    if (picked != null && picked.isNotEmpty) {
      counts.putIfAbsent(picked, () => 0);
    }
    return [
      for (final MapEntry(:key, :value) in counts.entries)
        (key: key, label: key, count: value),
    ]..sort((a, b) => compareVietnamese(a.label, b.label));
  }

  String? bandOf(Browsable p) {
    final price = _priceOf(p);
    return price == null
        ? null
        : priceBands
              .where((b) => price >= b.min && price < b.max)
              .firstOrNull
              ?.key;
  }

  return {
    'status': fixed(
      'status',
      (p) => [p.status],
      _statusOrder,
      (k) => projectStatus[k]!.label,
      f.status,
    ),
    'type': fixed(
      'type',
      (p) =>
          typeLabel.keys.where((k) => _typeMatches(p.projectType, k)).toList(),
      typeLabel.keys,
      (k) => typeLabel[k]!,
      f.type,
    ),
    'region': fixed(
      'region',
      (p) => [_regionKeyOf(p, aliases)],
      regions.map((r) => r.key),
      (k) => regions.firstWhere((r) => r.key == k).label,
      f.region,
    ),
    'province': open(
      'province',
      (p) => canonicalProvince(p.province, aliases),
      f.province == null ? null : canonicalProvince(f.province, aliases),
    ),
    'developer': open('developer', developerOf, f.developer),
    'price': fixed(
      'price',
      (p) => [bandOf(p)],
      priceBands.map((b) => b.key),
      (k) => priceBands.firstWhere((b) => b.key == k).label,
      f.price,
    ),
  };
}

List<ActiveFilter> activeFilters(ProjectFilter f) => [
  if (f.status?.isNotEmpty == true)
    (key: 'status', label: projectStatus[f.status]?.label ?? f.status!),
  if (f.type?.isNotEmpty == true)
    (key: 'type', label: typeLabel[f.type] ?? f.type!),
  if (f.region?.isNotEmpty == true)
    (key: 'region', label: regions.firstWhere((r) => r.key == f.region).label),
  if (f.province?.isNotEmpty == true) (key: 'province', label: f.province!),
  if (f.developer?.isNotEmpty == true) (key: 'developer', label: f.developer!),
  if (f.price?.isNotEmpty == true)
    (key: 'price', label: priceBands.firstWhere((b) => b.key == f.price).label),
];
List<Suggestion> suggest(
  List<Browsable> list,
  String q,
  ProjectFilter f,
  Map<String, String> aliases,
) {
  final needle = fold(q);
  if (needle.length < 2) return [];
  List<Suggestion> count(
    String kind,
    String? Function(Browsable) keyOf,
    String? picked,
  ) {
    final counts = <String, int>{};
    for (final p in list) {
      final key = keyOf(p);
      if (key != null &&
          key.isNotEmpty &&
          fold(key).contains(needle) &&
          fold(key) != fold(picked)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return [
      for (final MapEntry(:key, :value) in counts.entries)
        (kind: kind, label: key, count: value),
    ]..sort(
      (a, b) => a.count != b.count
          ? b.count.compareTo(a.count)
          : compareVietnamese(a.label, b.label),
    );
  }

  return [
    ...count(
      'province',
      (p) => canonicalProvince(p.province, aliases),
      f.province == null ? null : canonicalProvince(f.province, aliases),
    ).take(2),
    ...count('developer', developerOf, f.developer).take(2),
  ];
}
