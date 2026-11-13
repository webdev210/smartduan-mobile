import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../api/models.dart';
import '../config.dart';
import 'regions.dart';

final _normalizedProvinces = <String, String>{};
String _normalizedProvince(String? value) {
  final key = value ?? '';
  final cached = _normalizedProvinces[key];
  if (cached != null) return cached;
  final result = normalizeProvince(key);
  // ponytail: 2000 province spellings as in RN; use LRU beyond that ceiling.
  if (_normalizedProvinces.length >= 2000) _normalizedProvinces.clear();
  return _normalizedProvinces[key] = result;
}

final _collationKeys =
    <String, ({String primary, String tones, String casing})>{};
({String primary, String tones, String casing}) _collationKey(String value) {
  final cached = _collationKeys[value];
  if (cached != null) return cached;
  const alphabet = 'aăâbcdđeêfghijklmnoôơpqrstuưvwxyz';
  const tones = ['\u0300', '\u0309', '\u0303', '\u0301', '\u0323'];
  final primary = StringBuffer(),
      accents = StringBuffer(),
      casing = StringBuffer();
  for (final rune in unorm.nfc(value).runes) {
    final c = String.fromCharCode(rune);
    final decomposed = unorm.nfd(c.toLowerCase());
    final base = unorm.nfc(
      decomposed.replaceAll(RegExp('[\u0300\u0301\u0303\u0309\u0323]'), ''),
    );
    final at = alphabet.indexOf(base);
    primary.write(at < 0 ? base : String.fromCharCode(0x100 + at));
    accents.write(tones.indexWhere(decomposed.contains) + 1);
    casing.write(c == c.toLowerCase() ? '0' : '1');
  }
  final key = (
    primary: primary.toString(),
    tones: accents.toString(),
    casing: casing.toString(),
  );
  // ponytail: Vietnamese catalogue names, 5000 cached keys; use ICU if other locales are added.
  if (_collationKeys.length >= 5000) _collationKeys.clear();
  return _collationKeys[value] = key;
}

// Vietnamese letters first, then tone marks, then case (lowercase first).
int compareVietnamese(String a, String b) {
  final x = _collationKey(a), y = _collationKey(b);
  final primary = x.primary.compareTo(y.primary);
  if (primary != 0) return primary;
  final tones = x.tones.compareTo(y.tones);
  return tones != 0 ? tones : x.casing.compareTo(y.casing);
}

Map<String, String> provinceAliases(List<Province> places) => {
  for (final place in places)
    for (final old in place.oldNames)
      if (_normalizedProvince(old) != _normalizedProvince(place.name))
        _normalizedProvince(old): _normalizedProvince(place.name),
};
String canonicalProvince(String? value, Map<String, String> aliases) {
  var name = _normalizedProvince(value);
  final visited = <String>{};
  while (aliases.containsKey(name) && visited.add(name)) {
    name = aliases[name]!;
  }
  return name;
}

bool inProvince(String? value, String? province, Map<String, String> aliases) =>
    province == null ||
    province.isEmpty ||
    canonicalProvince(value, aliases) == canonicalProvince(province, aliases);
List<({String name, int count})> provinceCounts(
  List<Browsable> projects,
  Map<String, String> aliases,
) {
  final counts = <String, int>{};
  for (final p in projects) {
    final name = canonicalProvince(p.province, aliases);
    if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
  }
  return [
    for (final MapEntry(:key, :value) in counts.entries)
      (name: key, count: value),
  ]..sort(
    (a, b) => b.count != a.count
        ? b.count.compareTo(a.count)
        : compareVietnamese(a.name, b.name),
  );
}

Map<String, String>? footerCatalogParams(String href) {
  final [path, ...rest] = href.split('?');
  if (path != '/du-an') return null;
  final params = <String, String>{};
  for (final pair in (rest.firstOrNull ?? '').split('&')) {
    final at = pair.indexOf('=');
    if (at < 1) continue;
    try {
      final key = _decodeComponent(pair.substring(0, at));
      final value = _decodeComponent(
        pair.substring(at + 1).replaceAll('+', ' '),
      );
      if ((key == 'province' || key == 'project_type') && value.isNotEmpty) {
        params[key] = value;
      }
    } catch (_) {
      /* Skip malformed backend percent encoding. */
    }
  }
  return params.isEmpty ? null : params;
}

// JS decodeURIComponent accepts unescaped Unicode as well as UTF-8 escapes.
String _decodeComponent(String value) => Uri.decodeComponent(
  value.runes.map((r) {
    final c = String.fromCharCode(r);
    return r > 127 ? Uri.encodeComponent(c) : c;
  }).join(),
);

String? mediaUrl(String? url, [String base = webUrl]) {
  if (url == null || url.isEmpty) return null;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return url;
  if (url.startsWith('/') && !url.startsWith('//') && base.isNotEmpty) {
    return '${base.replaceFirst(RegExp(r'/+$'), '')}$url';
  }
  return null;
}

List<T> featuredProjects<T extends Browsable>(List<T> projects) => [
  ...projects.where((p) => p.status == 'selling'),
  ...projects.where((p) => p.status == 'upcoming'),
].take(6).toList();
List<T> heroProjects<T extends Browsable>(List<T> hot, List<T> projects) {
  bool covered(Browsable p) => p.coverUrl?.isNotEmpty == true;
  final covers = hot.where(covered).take(6).toList();
  if (covers.isNotEmpty) return covers;
  final selling = projects.where((p) => p.status == 'selling');
  final fallback =
      selling
          .where(
            (p) =>
                covered(p) &&
                p.name != p.name.toUpperCase() &&
                p.name.length <= 60,
          )
          .firstOrNull ??
      selling.where(covered).firstOrNull ??
      projects.where((p) => p.status == 'upcoming' && covered(p)).firstOrNull ??
      featuredProjects(projects).firstOrNull;
  return fallback == null ? [] : [fallback];
}
