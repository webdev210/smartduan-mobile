class ApiError implements Exception {
  const ApiError(
    this.status,
    this.code,
    this.message, {
    this.details,
    this.retryAfter,
    this.body,
  });
  final int status;
  final String code;
  final String message;
  final Map<String, List<String>>? details;
  final num? retryAfter;
  final Object? body;

  // Error bodies and backend text can contain credentials; never stringify them.
  @override
  String toString() => 'ApiError(status: $status)';
}

String errorMessage(Object? error) {
  if (error is ApiError) return error.message;
  return 'Có lỗi xảy ra, thử lại sau';
}

String? fieldError(Object? error, String field) {
  if (error is! ApiError) return null;
  return error.details?[field]?.join(', ');
}
