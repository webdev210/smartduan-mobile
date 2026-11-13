import 'package:unorm_dart/unorm_dart.dart' as unorm;

final _folded = <String, String>{};
String fold(String? text) {
  final key = text ?? '';
  final cached = _folded[key];
  if (cached != null) return cached;
  final out = unorm
      .nfd(key)
      .replaceAll(RegExp('[\u0300-\u036f]'), '')
      .replaceAll(RegExp('đ', caseSensitive: false), 'd')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // ponytail: 5000 strings per cache; use LRU if larger catalogues need it.
  if (_folded.length >= 5000) _folded.clear();
  _folded[key] = out;
  return out;
}

List<String> tokens(String query) =>
    fold(query).split(' ').where((s) => s.isNotEmpty).toList();
bool hasAll(String haystack, List<String> words) =>
    words.every(haystack.contains);
int titleScore(String title, String query) {
  final t = fold(title), q = fold(query);
  if (q.isEmpty) return 0;
  if (t.startsWith(q)) return 3;
  final first = q.split(' ').first;
  if (t.split(' ').any((w) => w.startsWith(first))) return 2;
  return t.contains(first) ? 1 : 0;
}

List<T> smartFilter<T>(
  List<T> items,
  String query,
  List<String?> Function(T) fields,
) {
  final words = tokens(query);
  if (words.isEmpty) return items;
  final scored =
      [
            for (var at = 0; at < items.length; at++)
              (item: items[at], at: at, fields: fields(items[at])),
          ]
          .where(
            (x) => hasAll(
              fold(
                x.fields
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' '),
              ),
              words,
            ),
          )
          .map(
            (x) => (
              item: x.item,
              at: x.at,
              score: titleScore(x.fields.firstOrNull ?? '', query),
            ),
          )
          .toList()
        ..sort((a, b) {
          final score = b.score.compareTo(a.score);
          return score != 0 ? score : a.at.compareTo(b.at);
        });
  return scored.map((x) => x.item).toList();
}
