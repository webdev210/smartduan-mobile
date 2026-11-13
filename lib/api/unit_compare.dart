import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import 'client.dart';
import 'models.dart';

// ponytail: picker fields only; extend this model with the M3 inventory screens.
class ComparePickerUnit {
  const ComparePickerUnit({
    required this.id,
    required this.code,
    required this.status,
    this.publicCode,
    this.unitType,
    this.priceMin,
    this.priceList,
  });
  final String id, code, status;
  final String? publicCode, unitType, priceMin, priceList;
  factory ComparePickerUnit.fromJson(Map<String, dynamic> j) {
    final unit = Unit.fromJson(j);
    return ComparePickerUnit(
      id: unit.id,
      code: unit.code,
      status: unit.status,
      publicCode: unit.publicCode,
      unitType: unit.unitType,
      priceMin: unit.priceMin,
      priceList: unit.priceList,
    );
  }
}

class UnitCompareApi {
  UnitCompareApi(this.client);
  final ApiClient client;
  Future<List<ComparePickerUnit>> fetchAllUnits(String projectId) async {
    final all = <ComparePickerUnit>[];
    for (var page = 1; ; page++) {
      final res = Paged.fromJson(
        jsonObject(
          await client.get(
            '/projects/${Uri.encodeComponent(projectId)}/units',
            {'per_page': 200, 'page': page},
          ),
        ),
        ComparePickerUnit.fromJson,
      );
      all.addAll(res.data);
      if (all.length >= res.total || res.data.isEmpty) {
        return List.unmodifiable(all);
      }
    }
  }

  Future<List<String>> fetchCompare() async => jsonList(
    jsonObject(await client.get('/sales/me/compare'))['units'],
    (j) => BlockRef.fromJson(j).id,
  );
  Future<void> addCompare(String id) async {
    await client.post('/sales/me/compare', {'unit_id': id});
  }

  Future<void> removeCompare(String id) async {
    await client.del('/sales/me/compare/${Uri.encodeComponent(id)}');
  }
}

final unitCompareApiProvider = Provider(
  (ref) => UnitCompareApi(ref.watch(apiClientProvider)),
);
final compareUnitsProvider = FutureProvider.autoDispose
    .family<List<ComparePickerUnit>, String>((ref, projectId) async {
      ref.watch(sessionProvider);
      final result = await ref
          .watch(unitCompareApiProvider)
          .fetchAllUnits(projectId);
      if (ref.mounted) {
        final link = ref.keepAlive();
        final timer = Timer(const Duration(seconds: 60), link.close);
        ref.onDispose(timer.cancel);
      }
      return result;
    });
final unitCompareProvider = FutureProvider.autoDispose((ref) {
  ref.watch(sessionProvider);
  return ref.watch(unitCompareApiProvider).fetchCompare();
});
