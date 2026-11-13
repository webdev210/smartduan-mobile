import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/content.dart';

Policy pol(String id, String from, [String? to]) => Policy.fromJson({
  'id': id,
  'project_id': 'p',
  'title': id,
  'effective_from': from,
  'effective_to': to,
});

void main() {
  final now = DateTime.parse('2026-11-09T16:30:00Z');
  test('upcoming excludes current, expired and today, sorts by start', () {
    expect(
      upcomingPolicies(
        [pol('cur', '2026-11-01')],
        [
          pol('cur', '2026-11-01'),
          pol('old', '2026-01-01', '2026-10-31'),
          pol('dec', '2026-12-01'),
          pol('nov', '2026-11-20'),
          pol('today', '2026-11-09'),
        ],
        now,
      ).map((p) => p.id),
      ['nov', 'dec'],
    );
  });
  test('upcoming rejects end before start', () {
    expect(
      upcomingPolicies([], [pol('bad', '2026-12-10', '2026-12-01')], now),
      isEmpty,
    );
  });
  test('Vietnam midnight is used independently of host timezone', () {
    expect(
      upcomingPolicies([], [
        pol('today', '2026-11-10'),
      ], DateTime.parse('2026-11-09T17:00:00Z')),
      isEmpty,
    );
  });
  test('policy UUID versus HTTP link', () {
    expect(isDocumentId('9794c344-71bc-42c4-94a9-d7525d88c608'), isTrue);
    expect(isDocumentId('https://x.vn/a.pdf'), isFalse);
  });
}
