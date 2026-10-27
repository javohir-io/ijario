import 'package:flutter/foundation.dart';

import '../data/property_store.dart';
import '../data/viewing_store.dart';
import '../models/picked_image.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'chat_store.dart';
import 'session_storage.dart';

/// Holds the signed-in person for the lifetime of the app and keeps the
/// session on the device, so people stay signed in between launches.
///
/// Browsing is open to everyone: [isLoggedIn] is only required for saving,
/// chatting, booking viewings and posting listings.
class AuthStore extends ChangeNotifier {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  AppUser? currentUser;
  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  /// Shown once after the server rejected an expired session.
  bool sessionExpired = false;

  /// Reads the saved session. The cached user is used straight away (so the
  /// app opens instantly, even offline); the server confirms it in the
  /// background and signs the person out only if the token was rejected.
  Future<void> restore() async {
    ApiClient.instance.onUnauthorized = _handleUnauthorized;

    final token = await SessionStorage.readToken();
    if (token == null) return;

    ApiClient.instance.token = token;
    currentUser = await SessionStorage.readUser();
    notifyListeners();

    try {
      final data = await ApiClient.instance.me();
      currentUser = AppUser.fromJson(data);
      await SessionStorage.saveUser(currentUser!);
      notifyListeners();
    } on ApiException {
      // 401 is handled by onUnauthorized; other failures (offline, server
      // asleep) keep the cached session.
    }
  }

  void _handleUnauthorized() {
    if (!isLoggedIn) return;
    sessionExpired = true;
    logout();
  }

  Future<void> _startSession(Map<String, dynamic> data) async {
    final token = data['access_token'] as String;
    ApiClient.instance.token = token;
    currentUser = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    sessionExpired = false;
    await SessionStorage.saveSession(token, currentUser!);
    notifyListeners();
  }

  /// Returns null on success, or an error message to show the user.
  Future<String?> login({required String email, required String password}) async {
    try {
      await _startSession(await ApiClient.instance.login(email: email, password: password));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      await _startSession(await ApiClient.instance.register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      ));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Only the given fields are sent. Pass an empty string to clear phone or
  /// telegram. Returns null on success, or an error message.
  Future<String?> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? telegram,
    String? password,
  }) async {
    final fields = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (telegram != null) 'telegram': telegram,
      if (password != null && password.isNotEmpty) 'password': password,
    };
    try {
      final data = await ApiClient.instance.updateProfile(fields);
      currentUser = AppUser.fromJson(data);
      await SessionStorage.saveUser(currentUser!);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> uploadAvatar(PickedImage image) async {
    try {
      final data = await ApiClient.instance.uploadAvatar(image);
      currentUser = AppUser.fromJson(data);
      await SessionStorage.saveUser(currentUser!);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void logout() {
    currentUser = null;
    ApiClient.instance.token = null;
    SessionStorage.clearSession();
    ChatStore.instance.disconnect();
    PropertyStore.instance.reset();
    ViewingStore.instance.reset();
    notifyListeners();
  }
}
