import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/board_filter.dart';

StackCell cell(Map<String, dynamic> o) => StackCell.fromJson({
  'axis': '01',
  'id': o['code'] ?? 'x',
  'code': 'A-01',
  'status': 'available',
  'version': 1,
  ...o,
});
final boardPlan = StackPlan(
  block: const BlockRef(id: 'b', name: 'A', code: 'A'),
  layout: 'floors',
  axes: ['01', '02'],
  axisMeta: {
    '01': const AxisMeta(unitType: '2PN', bedrooms: 2),
    '02': null,
  },
  floors: [
    StackFloor(
      floor: 2,
      cells: [
        cell({
          'code': 'A-02.01',
          'status': 'sold',
          'fund': 'doc_quyen',
          'direction': 'ĐN',
          'bedrooms': 2,
        }),
      ],
    ),
    StackFloor(
      floor: 1,
      cells: [
        cell({
          'code': 'A-01.01',
          'fund': 'chung',
          'direction': 'TB',
          'bedrooms': 2,
        }),
        cell({
          'code': 'A-01.02',
          'axis': '02',
          'unit_type': 'Studio',
          'bedrooms': 1,
        }),
      ],
    ),
  ],
);

void main() {
  final all = cellsOf(boardPlan);
  List<String> codes(BoardFilter f) =>
      all.where((c) => keeps(c, f, boardPlan)).map((c) => c.code).toList();
  test('no filters keeps all', () => expect(codes(emptyFilter), hasLength(3)));
  test(
    'code ignores case, dots and dashes',
    () => expect(codes(const BoardFilter(code: 'a0201')), ['A-02.01']),
  );
  test(
    'unit type falls back to floor axis metadata',
    () => expect(codes(const BoardFilter(type: '2PN')), ['A-02.01', 'A-01.01']),
  );
  test(
    'status fund direction bedrooms combine',
    () => expect(
      codes(
        const BoardFilter(
          status: 'available',
          fund: 'chung',
          direction: 'TB',
          bedrooms: 2,
        ),
      ),
      ['A-01.01'],
    ),
  );
  test(
    'counts by status',
    () => expect(countByStatus(all), {'sold': 1, 'available': 2}),
  );
  test('options are distinct, sorted, restricted to current block', () {
    final opts = filterOptions(all, boardPlan);
    expect(opts.types, ['2PN', 'Studio']);
    expect(opts.funds, ['chung', 'doc_quyen']);
    expect(opts.directions, ['ĐN', 'TB']);
    expect(opts.bedrooms, [1, 2]);
  });
  test('flat units use the same filters, row layout has no axis fallback', () {
    final u = Unit.fromJson({'id': 'u', 'code': 'A.01', 'status': 'available'});
    expect(keeps(u, const BoardFilter(code: 'a01')), isTrue);
    expect(
      typeOf(
        all.first,
        StackPlan(
          block: boardPlan.block,
          layout: 'rows',
          axisMeta: boardPlan.axisMeta,
        ),
      ),
      isNull,
    );
  });
}
