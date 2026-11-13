import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../api/models.dart';

export '../api/models.dart' show Filterable;

class BoardFilter {
  const BoardFilter({
    this.status,
    this.code = '',
    this.type,
    this.fund,
    this.direction,
    this.bedrooms,
  });
  final String? status, type, fund, direction;
  final String code;
  final int? bedrooms;
}

const emptyFilter = BoardFilter();
String _squash(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
List<StackCell> cellsOf(StackPlan plan) =>
    plan.floors.expand((f) => f.cells).toList();
String? typeOf(Filterable c, [StackPlan? plan]) =>
    c.unitType ??
    (plan?.layout == 'floors' && c.axis != null && c.axis!.isNotEmpty
        ? plan!.axisMeta[c.axis]?.unitType
        : null);
bool keeps(Filterable c, BoardFilter f, [StackPlan? plan]) {
  if (f.status != null && f.status!.isNotEmpty && c.status != f.status) {
    return false;
  }
  final q = _squash(f.code);
  if (q.isNotEmpty && !_squash(c.code).contains(q)) return false;
  if (f.type != null && f.type!.isNotEmpty && typeOf(c, plan) != f.type) {
    return false;
  }
  if (f.fund != null && f.fund!.isNotEmpty && c.fund != f.fund) return false;
  if (f.direction != null &&
      f.direction!.isNotEmpty &&
      c.direction != f.direction) {
    return false;
  }
  if (f.bedrooms != null && c.bedrooms != f.bedrooms) return false;
  return true;
}

Map<String, int> countByStatus(Iterable<Filterable> cells) {
  final counts = <String, int>{};
  for (final c in cells) {
    counts.update(c.status, (v) => v + 1, ifAbsent: () => 1);
  }
  return counts;
}

// Vietnamese alphabet: shaped vowels are letters; tone marks are secondary.
String _viKey(String s) {
  final decomposed = unorm.nfd(s.toLowerCase());
  final primary = StringBuffer();
  final secondary = StringBuffer();
  const letters = 'aăâbcdđeêfghijklmnoôơpqrstuưvwxyz';
  const tones = ['', '\u0300', '\u0309', '\u0303', '\u0301', '\u0323'];
  final groups = RegExp(r'.[\u0300-\u036f]*').allMatches(decomposed);
  for (final g in groups) {
    var letter = g[0]!;
    var tone = 0;
    for (var i = 1; i < tones.length; i++) {
      if (letter.contains(tones[i])) {
        tone = i;
        letter = letter.replaceAll(tones[i], '');
      }
    }
    letter = unorm.nfc(letter);
    final rank = letters.indexOf(letter);
    primary.writeCharCode(rank < 0 ? letter.codeUnitAt(0) : 0x100 + rank);
    secondary.write(tone);
  }
  return '$primary\u0000$secondary';
}

({
  List<String> types,
  List<String> funds,
  List<String> directions,
  List<int> bedrooms,
})
filterOptions(Iterable<Filterable> cells, [StackPlan? plan]) {
  List<String> distinct(String? Function(Filterable) pick) =>
      cells
          .map(pick)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => _viKey(a).compareTo(_viKey(b)));
  return (
    types: distinct((c) => typeOf(c, plan)),
    funds: distinct((c) => c.fund),
    directions: distinct((c) => c.direction),
    bedrooms: cells.map((c) => c.bedrooms).whereType<int>().toSet().toList()
      ..sort(),
  );
}
