import 'package:flutter/foundation.dart';

import '../models/picked_image.dart';
import '../models/property.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Holds the listings fetched from the backend and keeps them in sync as
/// the user posts, edits, saves and hides listings.
class PropertyStore extends ChangeNotifier {
  PropertyStore._internal();
  static final PropertyStore instance = PropertyStore._internal();

  List<Property> _properties = [];
  List<Property> _mine = [];
  bool isLoading = false;
  bool isLoadingMine = false;
  String? error;
  bool _hasLoadedOnce = false;

  /// Active listings visible to everyone.
  List<Property> get all => List.unmodifiable(_properties);
  List<Property> get saved => _properties.where((p) => p.isSaved).toList();

  /// The signed-in person's own listings, including ones marked as rented.
  List<Property> get mine => List.unmodifiable(_mine);
  bool get hasLoadedOnce => _hasLoadedOnce;

  Property? byId(int id) {
    for (final p in _properties) {
      if (p.id == id) return p;
    }
    for (final p in _mine) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Clears everything: called on logout so the next person starts clean.
  void reset() {
    _properties = [];
    _mine = [];
    isLoading = false;
    isLoadingMine = false;
    error = null;
    _hasLoadedOnce = false;
    notifyListeners();
  }

  Future<void> fetchAll() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.listProperties(limit: 200);
      _properties = (data['items'] as List<dynamic>? ?? const [])
          .map((e) => Property.fromJson(e as Map<String, dynamic>))
          .toList();
      _hasLoadedOnce = true;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMine() async {
    isLoadingMine = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.myProperties();
      _mine = (data['items'] as List<dynamic>? ?? const [])
          .map((e) => Property.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      // Keep the previous list on a transient failure.
    } finally {
      isLoadingMine = false;
      notifyListeners();
    }
  }

  /// Loads one listing in full (this is what carries the price insight and
  /// counts a view) and merges it into the cache. Returns null if it can't
  /// be loaded; the caller keeps showing the cached copy.
  Future<Property?> refreshOne(int id) async {
    try {
      final fresh = Property.fromJson(await ApiClient.instance.getProperty(id));
      _replace(fresh);
      notifyListeners();
      return fresh;
    } on ApiException {
      return null;
    }
  }

  void _replace(Property updated) {
    final i = _properties.indexWhere((e) => e.id == updated.id);
    if (i != -1) {
      if (updated.isRented) {
        _properties.removeAt(i);
      } else {
        _properties[i] = updated;
      }
    } else if (!updated.isRented) {
      _properties.insert(0, updated);
    }
    final j = _mine.indexWhere((e) => e.id == updated.id);
    if (j != -1) {
      _mine[j] = updated;
    }
  }

  /// Optimistically flips the bookmark locally, then confirms with the
  /// server; rolls back if the request fails. Returns an error message on
  /// failure, or null on success.
  Future<String?> toggleSave(int id) async {
    final target = byId(id);
    if (target == null) return null;

    final previous = target.isSaved;
    target.isSaved = !previous;
    notifyListeners();

    try {
      final result = await ApiClient.instance.toggleSave(id);
      target.isSaved = result['saved'] as bool? ?? !previous;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      target.isSaved = previous; // roll back
      notifyListeners();
      return e.message;
    }
  }

  /// Returns the created property, or throws [ApiException].
  Future<Property> addProperty(Map<String, dynamic> payload) async {
    final created = Property.fromJson(await ApiClient.instance.createProperty(payload));
    _properties.insert(0, created);
    _mine.insert(0, created);
    notifyListeners();
    return created;
  }

  /// Returns the updated property, or throws [ApiException].
  Future<Property> updateProperty(int id, Map<String, dynamic> payload) async {
    final updated = Property.fromJson(await ApiClient.instance.updateProperty(id, payload));
    _replace(updated);
    notifyListeners();
    return updated;
  }

  /// Marks a listing as rented out ("band") or active again. Rented
  /// listings disappear from search but stay in "E'lonlarim".
  Future<Property> setRented(int id, bool rented) {
    return updateProperty(id, {'status': rented ? Property.statusRented : Property.statusActive});
  }

  Future<void> deleteProperty(int id) async {
    await ApiClient.instance.deleteProperty(id);
    _properties.removeWhere((e) => e.id == id);
    _mine.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Moderation (admins only).
  Future<void> adminDeleteProperty(int id) async {
    await ApiClient.instance.adminDeleteProperty(id);
    _properties.removeWhere((e) => e.id == id);
    _mine.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<Property> uploadImages(int propertyId, List<PickedImage> images) async {
    final updated = Property.fromJson(await ApiClient.instance.uploadPropertyImages(propertyId, images));
    _replace(updated);
    notifyListeners();
    return updated;
  }

  Future<Property> deleteImage(int propertyId, int imageId) async {
    final updated = Property.fromJson(await ApiClient.instance.deletePropertyImage(propertyId, imageId));
    _replace(updated);
    notifyListeners();
    return updated;
  }
}
