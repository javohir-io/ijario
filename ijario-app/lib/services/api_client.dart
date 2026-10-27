import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/picked_image.dart';
import 'api_exception.dart';

/// Thin wrapper around the Ijario backend's REST API.
///
/// Holds the current JWT (set by [AuthStore] after login/register) and
/// attaches it as a Bearer token to every request. All methods return
/// decoded JSON (Map or List) on success, or throw an [ApiException] with a
/// message that is safe to show directly to the user.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;

  /// Called when the server says our token is no longer valid, so the app
  /// can sign the person out instead of failing every request.
  void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanQuery = <String, dynamic>{...?query}
      ..removeWhere((key, value) => value == null || value == '');
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: cleanQuery.isEmpty
          ? null
          : cleanQuery.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, String> get _authHeaders => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// The chat WebSocket URL, derived from [ApiConfig.baseUrl] (http -> ws,
  /// https -> wss) with the current JWT attached as a query param, since
  /// browsers can't set custom headers on a WebSocket handshake.
  Uri get chatWebSocketUri {
    final httpUri = Uri.parse(ApiConfig.baseUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: wsScheme, path: '/messages/ws', queryParameters: {
      if (token != null) 'token': token!,
    });
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  String _extractErrorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          // FastAPI prefixes validator errors with "Value error, ".
          return first['msg'].toString().replaceFirst('Value error, ', '');
        }
      }
      return detail.toString();
    }
    return "So'rov bajarilmadi (kod: $statusCode)";
  }

  dynamic _handle(http.Response response) {
    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (response.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }
    throw ApiException(
      _extractErrorMessage(decoded, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action, {Duration timeout = const Duration(seconds: 25)}) async {
    try {
      return await action().timeout(timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException("Server javob bermadi. Internetni tekshirib, qayta urinib ko'ring.");
    } on http.ClientException {
      throw ApiException("Serverga ulanib bo'lmadi. Internetni tekshiring.");
    } catch (_) {
      throw ApiException("Kutilmagan xatolik yuz berdi. Qayta urinib ko'ring.");
    }
  }

  // ---------- Health check ----------

  /// Fire-and-forget request to wake up a sleeping backend (free hosting
  /// tiers spin the container down when idle and can take up to ~50s to
  /// wake). Called as early as possible so the first real request doesn't
  /// eat that delay.
  Future<void> ping() async {
    try {
      await http.get(_uri('/')).timeout(const Duration(seconds: 60));
    } catch (_) {
      // Best-effort warm-up only.
    }
  }

  // ---------- Auth ----------

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) {
    return _guard(() async {
      final response = await http.post(
        _uri('/auth/register'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) {
    return _guard(() async {
      final response = await http.post(
        _uri('/auth/login'),
        body: {'username': email, 'password': password},
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> me() {
    return _guard(() async {
      final response = await http.get(_uri('/auth/me'), headers: _authHeaders);
      return _handle(response) as Map<String, dynamic>;
    });
  }

  // ---------- Users ----------

  /// Only the keys present in [fields] are sent; send an empty string to
  /// clear `phone` or `telegram`.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> fields) {
    return _guard(() async {
      final response = await http.put(
        _uri('/users/me'),
        headers: _jsonHeaders,
        body: jsonEncode(fields),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<List<dynamic>> mySaved() {
    return _guard(() async {
      final response = await http.get(_uri('/users/me/saved'), headers: _authHeaders);
      return _handle(response) as List<dynamic>;
    });
  }

  Future<Map<String, dynamic>> uploadAvatar(PickedImage image) {
    return _guard(
      () async {
        final request = http.MultipartRequest('POST', _uri('/users/me/avatar'));
        request.headers.addAll(_authHeaders);
        request.files.add(http.MultipartFile.fromBytes('file', image.bytes, filename: image.filename));
        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        return _handle(response) as Map<String, dynamic>;
      },
      timeout: const Duration(seconds: 40),
    );
  }

  // ---------- Properties ----------

  Future<Map<String, dynamic>> listProperties({int skip = 0, int limit = 200}) {
    return _guard(() async {
      final response = await http.get(
        _uri('/properties', {'skip': skip, 'limit': limit}),
        headers: _authHeaders,
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> myProperties() {
    return _guard(() async {
      final response = await http.get(_uri('/properties/mine'), headers: _authHeaders);
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> getProperty(int id) {
    return _guard(() async {
      final response = await http.get(_uri('/properties/$id'), headers: _authHeaders);
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> createProperty(Map<String, dynamic> payload) {
    return _guard(() async {
      final response = await http.post(
        _uri('/properties'),
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> updateProperty(int id, Map<String, dynamic> payload) {
    return _guard(() async {
      final response = await http.put(
        _uri('/properties/$id'),
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<void> deleteProperty(int id) {
    return _guard(() async {
      final response = await http.delete(_uri('/properties/$id'), headers: _authHeaders);
      _handle(response);
    });
  }

  /// Moderation: an admin can remove any listing.
  Future<void> adminDeleteProperty(int id) {
    return _guard(() async {
      final response = await http.delete(_uri('/admin/properties/$id'), headers: _authHeaders);
      _handle(response);
    });
  }

  Future<Map<String, dynamic>> toggleSave(int id) {
    return _guard(() async {
      final response = await http.post(_uri('/properties/$id/save'), headers: _authHeaders);
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<void> reportProperty(int id, {required String reason, String details = ''}) {
    return _guard(() async {
      final response = await http.post(
        _uri('/properties/$id/report'),
        headers: _jsonHeaders,
        body: jsonEncode({'reason': reason, 'details': details}),
      );
      _handle(response);
    });
  }

  Future<Map<String, dynamic>> uploadPropertyImages(int propertyId, List<PickedImage> images) {
    return _guard(
      () async {
        final request = http.MultipartRequest('POST', _uri('/properties/$propertyId/images'));
        request.headers.addAll(_authHeaders);
        for (final image in images) {
          request.files.add(http.MultipartFile.fromBytes('files', image.bytes, filename: image.filename));
        }
        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        return _handle(response) as Map<String, dynamic>;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<Map<String, dynamic>> deletePropertyImage(int propertyId, int imageId) {
    return _guard(() async {
      final response = await http.delete(_uri('/properties/$propertyId/images/$imageId'), headers: _authHeaders);
      return _handle(response) as Map<String, dynamic>;
    });
  }

  // ---------- Viewings ----------

  Future<List<dynamic>> myViewings() {
    return _guard(() async {
      final response = await http.get(_uri('/viewings/mine'), headers: _authHeaders);
      return _handle(response) as List<dynamic>;
    });
  }

  Future<Map<String, dynamic>> createViewing({
    required int propertyId,
    required DateTime scheduledAt,
    String note = '',
  }) {
    return _guard(() async {
      final response = await http.post(
        _uri('/viewings'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'property_id': propertyId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'note': note,
        }),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> setViewingStatus(int id, String status) {
    return _guard(() async {
      final response = await http.patch(
        _uri('/viewings/$id'),
        headers: _jsonHeaders,
        body: jsonEncode({'status': status}),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  // ---------- Messages ----------

  Future<List<dynamic>> listConversations() {
    return _guard(() async {
      final response = await http.get(_uri('/messages/conversations'), headers: _authHeaders);
      return _handle(response) as List<dynamic>;
    });
  }

  Future<List<dynamic>> getConversationWith(int userId) {
    return _guard(() async {
      final response = await http.get(_uri('/messages/with/$userId'), headers: _authHeaders);
      return _handle(response) as List<dynamic>;
    });
  }

  Future<Map<String, dynamic>> sendMessage({
    required int receiverId,
    required String content,
    int? propertyId,
  }) {
    return _guard(() async {
      final response = await http.post(
        _uri('/messages'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'receiver_id': receiverId,
          'content': content,
          if (propertyId != null) 'property_id': propertyId,
        }),
      );
      return _handle(response) as Map<String, dynamic>;
    });
  }

  // ---------- Admin ----------

  Future<Map<String, dynamic>> adminStats() {
    return _guard(() async {
      final response = await http.get(_uri('/admin/stats'), headers: _authHeaders);
      return _handle(response) as Map<String, dynamic>;
    });
  }
}
