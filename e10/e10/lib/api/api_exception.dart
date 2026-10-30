class ApiException implements Exception {
  ApiException(this.message, {this.status, this.errors});

  final String message;
  final int? status;

  /// Raw field -> [messages] validation errors from a Laravel 422 response
  /// (`{"errors": {"field": ["message"]}}`), when available.
  final Map<String, List<String>>? errors;

  Null get statusCode => null;

  @override
  String toString() => message;
}
