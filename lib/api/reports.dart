import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'models.dart';
import 'projects.dart' show signedInClient, sessionQuery, sessionQueryFamily;

export 'models.dart';
export 'sales.dart' show sumViewsByProject;

typedef InventoryCounts = Map<String, num>;

class ReportsApi {
  const ReportsApi(this.client);
  final ApiClient client;
  Future<List<InventoryReportRow>> fetchInventoryReport() async => jsonList(
    jsonObject(await client.get('/reports/inventory'))['data'],
    InventoryReportRow.fromJson,
  );
  Future<Attention> fetchAttention() async =>
      Attention.fromJson(jsonObject(await client.get('/reports/attention')));
  Future<List<RecentChange>> fetchRecentActivity([int limit = 20]) async =>
      jsonList(
        jsonObject(
          await client.get('/reports/recent_activity', {'limit': limit}),
        )['data'],
        RecentChange.fromJson,
      );
  Future<BookingsWeekly> fetchBookingsWeekly([int weeks = 8]) async =>
      BookingsWeekly.fromJson(
        jsonObject(
          await client.get('/reports/bookings_weekly', {'weeks': weeks}),
        ),
      );
  Future<InventoryUpdates> fetchInventoryUpdates() async =>
      InventoryUpdates.fromJson(
        jsonObject(await client.get('/reports/inventory_updates')),
      );
  Future<ActiveSales> fetchActiveSales() async => ActiveSales.fromJson(
    jsonObject(await client.get('/reports/active_sales')),
  );
  Future<SurveyReport> fetchSurveyReport() async =>
      SurveyReport.fromJson(jsonObject(await client.get('/reports/survey')));
  Future<ListingsReport> fetchListingsReport() async => ListingsReport.fromJson(
    jsonObject(await client.get('/reports/listings')),
  );
  Future<List<ProjectViewRow>> fetchProjectViews() async => jsonList(
    jsonObject(await client.get('/reports/project_views'))['data'],
    ProjectViewRow.fromJson,
  );
}

final reportsApiProvider = Provider.autoDispose(
  (ref) => ReportsApi(signedInClient(ref)),
);
final fetchInventoryReportProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchInventoryReport(),
);
final fetchAttentionProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchAttention(),
);
final fetchRecentActivityProvider = sessionQueryFamily<List<RecentChange>, int>(
  (ref, value) => ref.watch(reportsApiProvider).fetchRecentActivity(value),
);
final fetchBookingsWeeklyProvider = sessionQueryFamily<BookingsWeekly, int>(
  (ref, value) => ref.watch(reportsApiProvider).fetchBookingsWeekly(value),
);
final fetchInventoryUpdatesProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchInventoryUpdates(),
);
final fetchActiveSalesProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchActiveSales(),
);
final fetchSurveyReportProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchSurveyReport(),
);
final fetchListingsReportProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchListingsReport(),
);
final fetchProjectViewsProvider = sessionQuery(
  (ref) => ref.watch(reportsApiProvider).fetchProjectViews(),
);
