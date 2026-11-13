import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'client.dart';
import 'errors.dart';
import 'models.dart';
import 'projects.dart'
    show perPageMax, signedInClient, sessionQuery, sessionQueryFamily;

export 'models.dart';

class UnitsApi {
  const UnitsApi(
    this.client, {
    this.downloadAdapter,
    this.temporaryDirectory = getTemporaryDirectory,
  });
  final ApiClient client;
  final HttpClientAdapter? downloadAdapter;
  final Future<Directory> Function() temporaryDirectory;

  Future<List<Unit>> fetchAllUnits(
    String projectId, [
    Map<String, dynamic> params = const {},
  ]) async {
    final all = <Unit>[];
    for (var page = 1; ; page++) {
      final result = Paged.fromJson(
        jsonObject(
          await client.get('/projects/$projectId/units', {
            ...params,
            'per_page': perPageMax,
            'page': page,
          }),
        ),
        Unit.fromJson,
      );
      all.addAll(result.data);
      if (all.length >= result.total || result.data.isEmpty) return all;
    }
  }

  Future<StackPlan> fetchStackPlan(String blockId) async => StackPlan.fromJson(
    jsonObject(await client.get('/blocks/$blockId/stack-plan')),
  );
  Future<List<Floor>> fetchFloors(String blockId) async => jsonList(
    jsonObject(await client.get('/blocks/$blockId/floors'))['data'] ?? const [],
    Floor.fromJson,
  );
  Future<UnitDetail> fetchUnitDetail(String unitId) async =>
      UnitDetail.fromJson(
        jsonObject(await client.get('/units/$unitId/detail')),
      );
  Future<UnitImages> fetchUnitImages(String unitId) async =>
      UnitImages.fromJson(
        jsonObject(await client.get('/units/$unitId/images')),
      );
  Future<Paged<HistoryRow>> fetchUnitHistory(String unitId) async =>
      Paged.fromJson(
        jsonObject(
          await client.get('/units/$unitId/history', {'per_page': 50}),
        ),
        HistoryRow.fromJson,
      );
  Future<Enums> fetchEnums() async =>
      Enums.fromJson(jsonObject(await client.get('/inventory/enums')));
  Future<Paged<HistoryRow>> fetchProjectHistory(
    String projectId, [
    int page = 1,
  ]) async => Paged.fromJson(
    jsonObject(
      await client.get('/projects/$projectId/units/history', {
        'per_page': 100,
        'page': page,
      }),
    ),
    HistoryRow.fromJson,
  );

  /// Dio's JSON client has no streaming API. Use its token store for this API
  /// path, prohibit redirects, and never attach the Bearer to document URLs.
  Future<String> downloadUnitsXlsx(String projectId, String code) async {
    final directory = await temporaryDirectory();
    final safeCode = code.replaceAll(RegExp(r'[^\w-]'), '_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}bang-hang-$safeCode.xlsx',
    );
    final partial = File('${file.path}.part');
    final token = await client.tokens.get();
    final dio = Dio(
      BaseOptions(
        baseUrl: apiUrl,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ),
    );
    if (downloadAdapter != null) dio.httpClientAdapter = downloadAdapter!;
    try {
      await dio.download(
        '/projects/$projectId/units/export.xlsx',
        partial.path,
      );
      await partial.rename(file.path);
      return file.path;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // End only the session that sent this request, never a replacement login.
      if (status == 401 && await client.tokens.get() == token) {
        await client.endSessionLocally('expired');
      }
      throw ApiError(
        status,
        status == 403
            ? 'forbidden'
            : status == 401
            ? 'unauthorized'
            : 'download_failed',
        status == 403
            ? 'Bạn không có quyền thực hiện thao tác này'
            : status == 401
            ? 'Phiên đã hết hạn, vui lòng đăng nhập lại'
            : 'Không tải được bảng hàng, thử lại sau',
      );
    } finally {
      dio.close(force: true);
      if (await partial.exists()) await partial.delete();
    }
  }
}

final unitsApiProvider = Provider.autoDispose(
  (ref) => UnitsApi(signedInClient(ref)),
);
final fetchAllUnitsProvider =
    sessionQueryFamily<List<Unit>, ({String projectId, ApiParams params})>(
      (ref, a) => ref
          .watch(unitsApiProvider)
          .fetchAllUnits(a.projectId, a.params.values),
    );
final fetchStackPlanProvider = sessionQueryFamily<StackPlan, String>(
  (ref, id) => ref.watch(unitsApiProvider).fetchStackPlan(id),
);
final fetchFloorsProvider = sessionQueryFamily<List<Floor>, String>(
  (ref, id) => ref.watch(unitsApiProvider).fetchFloors(id),
);
final fetchUnitDetailProvider = sessionQueryFamily<UnitDetail, String>(
  (ref, id) => ref.watch(unitsApiProvider).fetchUnitDetail(id),
);
final fetchUnitImagesProvider = sessionQueryFamily<UnitImages, String>(
  (ref, id) => ref.watch(unitsApiProvider).fetchUnitImages(id),
);
final fetchUnitHistoryProvider = sessionQueryFamily<Paged<HistoryRow>, String>(
  (ref, id) => ref.watch(unitsApiProvider).fetchUnitHistory(id),
);
final fetchEnumsProvider = sessionQuery(
  (ref) => ref.watch(unitsApiProvider).fetchEnums(),
);
final fetchProjectHistoryProvider =
    sessionQueryFamily<Paged<HistoryRow>, ({String projectId, int page})>(
      (ref, a) =>
          ref.watch(unitsApiProvider).fetchProjectHistory(a.projectId, a.page),
    );
final downloadUnitsXlsxProvider = Provider.autoDispose(
  (ref) => ref.watch(unitsApiProvider).downloadUnitsXlsx,
);
