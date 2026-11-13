import 'package:flutter_riverpod/flutter_riverpod.dart';

const maxCompareProjects = 3;

/// Public project codes, kept only for this app session.
final projectCompareProvider = NotifierProvider<ProjectCompare, List<String>>(
  ProjectCompare.new,
);

class ProjectCompare extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  bool add(String code) {
    if (state.contains(code)) return true;
    if (state.length >= maxCompareProjects) return false;
    state = List.unmodifiable([...state, code]);
    return true;
  }

  void remove(String code) =>
      state = List.unmodifiable(state.where((c) => c != code));
  bool toggle(String code) {
    if (!state.contains(code)) return add(code);
    remove(code);
    return true;
  }

  void clear() => state = const [];
}
