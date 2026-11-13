import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'models.dart';
import 'projects.dart' show signedInClient, sessionQuery, sessionQueryFamily;

export 'models.dart';

class SalesApi {
  const SalesApi(this.client);
  final ApiClient client;

  Future<Paged<SearchRow>> searchUnits(Map<String, dynamic> params) async =>
      Paged.fromJson(
        jsonObject(await client.get('/sales/units/search', params)),
        SearchRow.fromJson,
      );
  Future<List<SavedFilter>> fetchSavedFilters() async => jsonList(
    jsonObject(await client.get('/sales/units/search/saved'))['data'] ??
        const [],
    SavedFilter.fromJson,
  );
  Future<SavedFilter> saveFilter(
    String name,
    Map<String, String> params,
  ) async => SavedFilter.fromJson(
    jsonObject(
      await client.post('/sales/units/search/saved', {
        'name': name,
        'params': params,
      }),
    ),
  );
  Future<void> deleteSavedFilter(String id) async {
    await client.del('/sales/units/search/saved/$id');
  }

  Future<int> countAvailable() async =>
      (await searchUnits({'status': 'available', 'per_page': 1})).total;
  Future<CompareSet> fetchCompare() async =>
      CompareSet.fromJson(jsonObject(await client.get('/sales/me/compare')));
  Future<CompareSet> addCompare(String unitId) async => CompareSet.fromJson(
    jsonObject(await client.post('/sales/me/compare', {'unit_id': unitId})),
  );
  Future<void> removeCompare(String unitId) async {
    await client.del('/sales/me/compare/${Uri.encodeComponent(unitId)}');
  }

  Future<Listing> generateListing(
    String unitId,
    ListingChannel channel,
  ) async => Listing.fromJson(
    jsonObject(
      await client.post('/sales/listings/generate', {
        'unit_id': unitId,
        'channel': channel,
      }),
    ),
  );
  Future<LoanResult> calculateLoan(Map<String, dynamic> body) async =>
      LoanResult.fromJson(
        jsonObject(await client.post('/sales/loans/calculate', body)),
      );
  Future<Booking> declareBooking(Map<String, dynamic> body) async =>
      Booking.fromJson(
        jsonObject(await client.post('/sales/bookings/declare', body)),
      );
  Future<Paged<Booking>> fetchMyBookings([int page = 1]) async =>
      Paged.fromJson(
        jsonObject(await client.get('/sales/bookings/mine', {'page': page})),
        Booking.fromJson,
      );
  Future<Paged<AdminBooking>> fetchBookingsToReview([
    String status = 'declared,synced',
  ]) async => Paged.fromJson(
    jsonObject(await client.get('/bookings', {'status': status})),
    AdminBooking.fromJson,
  );
  Future<AdminBooking> decideBooking(
    String id,
    String status, [
    String? reason,
  ]) async => AdminBooking.fromJson(
    jsonObject(
      await client.patch('/bookings/$id', {
        'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    ),
  );
  Future<Team> fetchTeam() async =>
      Team.fromJson(jsonObject(await client.get('/sales/team')));
  Future<RolesResult> becomeSales(Map<String, dynamic> body) async =>
      RolesResult.fromJson(
        jsonObject(await client.post('/sales/become-sales', body)),
      );
  Future<List<ManagerOption>> fetchManagers() async => jsonList(
    jsonObject(await client.get('/sales/managers'))['data'] ?? const [],
    ManagerOption.fromJson,
  );
  Future<F2Request> requestF2(Map<String, dynamic> body) async =>
      F2Request.fromJson(
        jsonObject(await client.post('/sales/request-f2', body)),
      );
  Future<Notifications> fetchNotifications() async => Notifications.fromJson(
    jsonObject(await client.get('/sales/notifications')),
  );
  Future<NotificationsRead> markNotificationsRead([List<String>? ids]) async =>
      NotificationsRead.fromJson(
        jsonObject(
          await client.post('/sales/notifications/read', {'ids': ?ids}),
        ),
      );
  Future<Paged<AnnouncementSummary>> fetchAnnouncements([int page = 1]) async =>
      Paged.fromJson(
        jsonObject(await client.get('/sales/announcements', {'page': page})),
        AnnouncementSummary.fromJson,
      );
  Future<AnnouncementDetail> fetchAnnouncement(String id) async =>
      AnnouncementDetail.fromJson(
        jsonObject(
          jsonObject(await client.get('/sales/announcements/$id'))['data'],
        ),
      );

  /// One attempt only: lead_delivery_unknown may already have delivered the lead.
  Future<ConsultResult> submitConsult(Map<String, dynamic> body) async {
    if (body['consent'] != true) throw ArgumentError('consent must be true');
    return ConsultResult.fromJson(
      jsonObject(await client.post('/sales/consult', body)),
    );
  }

  Future<List<ProcessPage>> fetchProcessPages() async => jsonList(
    jsonObject(await client.get('/process-pages'))['data'] ?? const [],
    ProcessPage.fromJson,
  );
  Future<ProcessPage> fetchProcessPage(String slug) async =>
      ProcessPage.fromJson(
        jsonObject(await client.get('/process-pages/$slug')),
      );
  Future<ProcessAccessResult> requestProcessAccess(String slug) async =>
      ProcessAccessResult.fromJson(
        jsonObject(await client.post('/process-pages/$slug/request')),
      );
  Future<void> logActivity(Map<String, dynamic> body) async {
    try {
      await client.post('/activity', body);
    } catch (_) {
      /* Best-effort beacon. */
    }
  }

  Future<List<Branch>> fetchBranches() async => jsonList(
    jsonObject(await client.get('/branches'))['data'] ?? const [],
    Branch.fromJson,
  );
}

String loanTermsLabel(LoanResult r) {
  if (r.termsSource == 'default') return 'Mặc định của sàn';
  if (r.termsSource == 'manual') return 'Tự nhập — không theo CSBH';
  final scope = r.fund != null && r.fund!.isNotEmpty
      ? 'quỹ ${r.fund}'
      : 'chung';
  const labels = {
    'floating_rate': 'lãi thả nổi',
    'supported_rate': 'lãi ưu đãi',
    'grace_months': 'tháng ưu đãi',
  };
  return 'Theo CSBH $scope${r.termsSource == 'mixed' ? ', có điều chỉnh: ${r.overrides.map((k) => labels[k] ?? '').join(', ')}' : ''}';
}

/// Pure helper from reports.ts, retained for the RN sales-tools test cases.
List<({String project, int views, int ctaClicks, int leads})> sumViewsByProject(
  List<ProjectViewRow> rows,
) {
  final by =
      <String, ({String project, int views, int ctaClicks, int leads})>{};
  for (final r in rows) {
    final old =
        by[r.projectId] ??
        (project: r.project, views: 0, ctaClicks: 0, leads: 0);
    by[r.projectId] = (
      project: old.project,
      views: old.views + r.views,
      ctaClicks: old.ctaClicks + r.ctaClicks,
      leads: old.leads + r.leads,
    );
  }
  return by.values.toList()..sort((a, b) => b.views.compareTo(a.views));
}

final salesApiProvider = Provider.autoDispose(
  (ref) => SalesApi(signedInClient(ref)),
);
final searchUnitsProvider = sessionQueryFamily<Paged<SearchRow>, ApiParams>(
  (ref, p) => ref.watch(salesApiProvider).searchUnits(p.values),
);
final fetchSavedFiltersProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchSavedFilters(),
);
final countAvailableProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).countAvailable(),
);
final fetchCompareProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchCompare(),
);
final fetchMyBookingsProvider = sessionQueryFamily<Paged<Booking>, int>(
  (ref, page) => ref.watch(salesApiProvider).fetchMyBookings(page),
);
final fetchBookingsToReviewProvider =
    sessionQueryFamily<Paged<AdminBooking>, String>(
      (ref, status) =>
          ref.watch(salesApiProvider).fetchBookingsToReview(status),
    );
final fetchTeamProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchTeam(),
);
final fetchManagersProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchManagers(),
);
final fetchNotificationsProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchNotifications(),
);
final fetchAnnouncementsProvider =
    sessionQueryFamily<Paged<AnnouncementSummary>, int>(
      (ref, page) => ref.watch(salesApiProvider).fetchAnnouncements(page),
    );
final fetchAnnouncementProvider =
    sessionQueryFamily<AnnouncementDetail, String>(
      (ref, id) => ref.watch(salesApiProvider).fetchAnnouncement(id),
    );
final fetchProcessPagesProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchProcessPages(),
);
final fetchProcessPageProvider = sessionQueryFamily<ProcessPage, String>(
  (ref, slug) => ref.watch(salesApiProvider).fetchProcessPage(slug),
);
final fetchBranchesProvider = sessionQuery(
  (ref) => ref.watch(salesApiProvider).fetchBranches(),
);
// Callbacks, never FutureProviders: writes cannot run or retry while building UI.
final saveFilterProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).saveFilter,
);
final deleteSavedFilterProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).deleteSavedFilter,
);
final addCompareProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).addCompare,
);
final removeCompareProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).removeCompare,
);
final generateListingProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).generateListing,
);
final calculateLoanProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).calculateLoan,
);
final declareBookingProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).declareBooking,
);
final decideBookingProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).decideBooking,
);
final becomeSalesProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).becomeSales,
);
final requestF2Provider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).requestF2,
);
final markNotificationsReadProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).markNotificationsRead,
);
final submitConsultProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).submitConsult,
);
final requestProcessAccessProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).requestProcessAccess,
);
final logActivityProvider = Provider.autoDispose(
  (ref) => ref.watch(salesApiProvider).logActivity,
);
