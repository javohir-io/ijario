/// A human-readable error surfaced from the backend (or from a network
/// failure), meant to be shown directly in a toast or dialog.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
