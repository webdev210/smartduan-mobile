import '../api/models.dart';

List<Unit>? applyUnitPatch(List<Unit>? units, UnitPatch patch) {
  if (units == null) return null;
  var changed = false;
  final next = units.map((unit) {
    if (unit.id != patch.unitId || patch.version < unit.version) return unit;
    changed = true;
    return Unit.fromJson({
      ...unit.toJson(),
      'status': patch.status,
      'version': patch.version,
      'reserved_until': patch.reservedUntil,
      if (patch.hasFund) 'fund': patch.fund,
    });
  }).toList();
  return changed ? next : units;
}

StackPlan? applyPatchToStack(StackPlan? plan, UnitPatch patch) {
  if (plan == null) return null;
  var changed = false;
  final floors = plan.floors.map((floor) {
    var floorChanged = false;
    final cells = <StackCell>[];
    for (final cell in floor.cells) {
      if (cell.id != patch.unitId || patch.version < cell.version) {
        cells.add(cell);
        continue;
      }
      changed = floorChanged = true;
      if (patch.status != 'hidden') {
        cells.add(
          StackCell.fromJson({
            ...cell.toJson(),
            'status': patch.status,
            'version': patch.version,
            if (patch.hasFund) 'fund': patch.fund,
          }),
        );
      }
    }
    return floorChanged
        ? StackFloor(floor: floor.floor, name: floor.name, cells: cells)
        : floor;
  }).toList();
  return changed
      ? StackPlan(
          block: plan.block,
          layout: plan.layout,
          axes: plan.axes,
          axisMeta: plan.axisMeta,
          floors: floors,
        )
      : plan;
}
