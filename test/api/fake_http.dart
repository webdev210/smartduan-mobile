import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:smartduan/api/errors.dart';

class Reply {
  const Reply(
    this.status, [
    this.body = const <String, Object?>{},
    this.headers = const {},
  ]);
  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
}

class FakeHttp implements HttpClientAdapter {
  FakeHttp(this.respond);
  FutureOr<Reply> Function(RequestOptions) respond;
  final seen = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final reply = await respond(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<ApiError> caught(Future<Object?> future) async {
  try {
    await future;
  } on ApiError catch (error) {
    return error;
  }
  throw StateError('Expected ApiError');
}
