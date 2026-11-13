import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart' as config;
import '../ui/format.dart' as format;
import 'client.dart';
import 'models.dart';
import 'projects.dart' show signedInClient, sessionQueryFamily;

export 'models.dart';

class ContentApi {
  const ContentApi(this.client);
  final ApiClient client;
  String _base(String id) => '/content/projects/$id';

  Future<Policy?> fetchCurrentPolicy(String projectId, [String? fund]) async {
    final data = jsonObject(
      await client.get('${_base(projectId)}/policies/current', {
        if (fund != null && fund.isNotEmpty) 'fund': fund,
      }),
    )['data'];
    return data == null ? null : Policy.fromJson(jsonObject(data));
  }

  Future<List<Policy>> fetchPolicyScopes(String id) async => jsonList(
    jsonObject(
          await client.get('${_base(id)}/policies/current-scopes'),
        )['data'] ??
        const [],
    Policy.fromJson,
  );
  Future<List<Policy>> fetchPolicyHistory(String id) async => jsonList(
    jsonObject(await client.get('${_base(id)}/policies/history'))['data'] ??
        const [],
    Policy.fromJson,
  );
  Future<List<Doc>> fetchDocuments(String id) async => jsonList(
    jsonObject(await client.get('${_base(id)}/documents'))['data'] ?? const [],
    Doc.fromJson,
  );
  Future<List<MediaItem>> fetchMedia(String id, [String? mediaType]) async =>
      jsonList(
        jsonObject(
              await client.get('${_base(id)}/media', {
                'media_type': ?mediaType,
              }),
            )['data'] ??
            const [],
        MediaItem.fromJson,
      );
  Future<List<ProgressItem>> fetchProgress(String id) async => jsonList(
    jsonObject(await client.get('${_base(id)}/progress'))['data'] ?? const [],
    ProgressItem.fromJson,
  );
  Future<List<Faq>> fetchFaqs(String id) async => jsonList(
    jsonObject(await client.get('${_base(id)}/faqs'))['data'] ?? const [],
    Faq.fromJson,
  );
  Future<String> documentDownloadUrl(String docId) async {
    final data = jsonObject(
      await client.post('/content/documents/$docId/download-link'),
    );
    return absoluteUrl(data['download_url'] as String);
  }
}

List<Policy> upcomingPolicies(
  List<Policy> current,
  List<Policy> history, [
  DateTime? now,
]) {
  final today = (now ?? DateTime.now())
      .toUtc()
      .add(const Duration(hours: 7))
      .toIso8601String()
      .substring(0, 10);
  String day(String value) =>
      value.length > 10 ? value.substring(0, 10) : value;
  return history
      .where(
        (p) =>
            !current.any((c) => c.id == p.id) &&
            day(p.effectiveFrom).compareTo(today) > 0 &&
            (p.effectiveTo == null ||
                p.effectiveTo!.isEmpty ||
                day(p.effectiveTo!).compareTo(day(p.effectiveFrom)) >= 0),
      )
      .toList()
    ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
}

bool isDocumentId(String s) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(s);
String absoluteUrl(String url, [String apiUrl = config.apiUrl]) =>
    format.absoluteUrl(url, apiUrl);

final contentApiProvider = Provider.autoDispose(
  (ref) => ContentApi(signedInClient(ref)),
);
final fetchCurrentPolicyProvider =
    sessionQueryFamily<Policy?, ({String projectId, String? fund})>(
      (ref, a) =>
          ref.watch(contentApiProvider).fetchCurrentPolicy(a.projectId, a.fund),
    );
final fetchPolicyScopesProvider = sessionQueryFamily<List<Policy>, String>(
  (ref, id) => ref.watch(contentApiProvider).fetchPolicyScopes(id),
);
final fetchPolicyHistoryProvider = sessionQueryFamily<List<Policy>, String>(
  (ref, id) => ref.watch(contentApiProvider).fetchPolicyHistory(id),
);
final fetchDocumentsProvider = sessionQueryFamily<List<Doc>, String>(
  (ref, id) => ref.watch(contentApiProvider).fetchDocuments(id),
);
final fetchMediaProvider =
    sessionQueryFamily<
      List<MediaItem>,
      ({String projectId, String? mediaType})
    >(
      (ref, a) =>
          ref.watch(contentApiProvider).fetchMedia(a.projectId, a.mediaType),
    );
final fetchProgressProvider = sessionQueryFamily<List<ProgressItem>, String>(
  (ref, id) => ref.watch(contentApiProvider).fetchProgress(id),
);
final fetchFaqsProvider = sessionQueryFamily<List<Faq>, String>(
  (ref, id) => ref.watch(contentApiProvider).fetchFaqs(id),
);
final documentDownloadUrlProvider = Provider.autoDispose(
  (ref) => ref.watch(contentApiProvider).documentDownloadUrl,
);
