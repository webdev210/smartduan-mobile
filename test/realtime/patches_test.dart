import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/realtime/patches.dart';

void main() {
  const units = [
    Unit(id: 'u1', code: 'u1', version: 3, status: 'available', fund: 'chung'),
    Unit(id: 'u2', code: 'u2', version: 1, status: 'available', fund: 'chung'),
  ];
  UnitPatch patch(
    String id,
    String status,
    int version, {
    String? fund,
    bool hasFund = false,
  }) => UnitPatch(
    unitId: id,
    status: status,
    version: version,
    fund: fund,
    hasFund: hasFund,
  );
  test('RN changes matching unit and preserves other identities', () {
    final out = applyUnitPatch(
      units,
      UnitPatch(
        unitId: 'u1',
        status: 'reserved',
        version: 4,
        reservedUntil: '2026-11-05T00:00:00Z',
      ),
    )!;
    expect(out[0].status, 'reserved');
    expect(out[0].version, 4);
    expect(out[0].reservedUntil, '2026-11-05T00:00:00Z');
    expect(out[0].fund, 'chung');
    expect(out[1], same(units[1]));
  });
  test(
    'RN ignores older versions',
    () => expect(applyUnitPatch(units, patch('u1', 'sold', 2)), same(units)),
  );
  test('RN fund overrides; unknown unit and absent list unchanged', () {
    expect(
      applyUnitPatch(units, patch('u2', 'available', 2, fund: 'cheo'))![1].fund,
      'cheo',
    );
    expect(applyUnitPatch(units, patch('x', 'sold', 9)), same(units));
    expect(applyUnitPatch(null, patch('x', 'sold', 9)), isNull);
  });
  const plan = StackPlan(
    block: BlockRef(id: 'b', name: 'A', code: 'A'),
    layout: 'floors',
    axes: ['01'],
    floors: [
      StackFloor(
        floor: 1,
        cells: [
          StackCell(
            id: 'u1',
            code: 'u1',
            axis: '01',
            version: 1,
            status: 'available',
          ),
        ],
      ),
      StackFloor(
        floor: 2,
        cells: [
          StackCell(
            id: 'u2',
            code: 'u2',
            axis: '01',
            version: 1,
            status: 'available',
          ),
        ],
      ),
    ],
  );
  test('RN changes cell status and preserves untouched floor', () {
    final out = applyPatchToStack(plan, patch('u2', 'sold', 2))!;
    expect(out.floors[1].cells.single.status, 'sold');
    expect(out.floors.first, same(plan.floors.first));
  });
  test(
    'RN hidden cell disappears',
    () => expect(
      applyPatchToStack(plan, patch('u1', 'hidden', 2))!.floors.first.cells,
      isEmpty,
    ),
  );
  test('equal versions accepted, explicit null fund, stale stack ignored', () {
    expect(
      applyUnitPatch(units, patch('u1', 'sold', 3, hasFund: true))!.first.fund,
      isNull,
    );
    expect(applyPatchToStack(plan, patch('u1', 'sold', 0)), same(plan));
    expect(applyPatchToStack(null, patch('u1', 'sold', 2)), isNull);
  });
}
