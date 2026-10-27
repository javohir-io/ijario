import 'package:flutter/foundation.dart';

import '../models/viewing.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Viewing requests ("Ko'rish so'rovlari") the signed-in person made as a
/// renter or received as an owner.
class ViewingStore extends ChangeNotifier {
  ViewingStore._();
  static final ViewingStore instance = ViewingStore._();

  List<Viewing> _items = [];
  bool isLoading = false;

  List<Viewing> get all => List.unmodifiable(_items);

  /// Requests I made, soonest first.
  List<Viewing> get asRenter => _items.where((v) => !v.isOwnerSide).toList();

  /// Requests I received, soonest first.
  List<Viewing> get asOwner => _items.where((v) => v.isOwnerSide).toList();

  /// Requests waiting for my answer: shown as a badge on the profile tab.
  int get pendingForMe => _items.where((v) => v.isOwnerSide && v.isPending && !v.isClosed).length;

  /// My open request for this listing, if any.
  Viewing? openFor(int propertyId) {
    for (final v in _items) {
      if (!v.isOwnerSide && v.property.id == propertyId && (v.isPending || v.isConfirmed) && !v.isClosed) {
        return v;
      }
    }
    return null;
  }

  void reset() {
    _items = [];
    isLoading = false;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.myViewings();
      _items = data.map((e) => Viewing.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      // Keep what we had.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the created request, or throws [ApiException].
  Future<Viewing> create({required int propertyId, required DateTime when, String note = ''}) async {
    final json = await ApiClient.instance.createViewing(propertyId: propertyId, scheduledAt: when, note: note);
    final created = Viewing.fromJson(json);
    _items.add(created);
    _items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    notifyListeners();
    return created;
  }

  /// Returns an error message, or null on success.
  Future<String?> setStatus(int id, String status) async {
    try {
      final updated = Viewing.fromJson(await ApiClient.instance.setViewingStatus(id, status));
      final i = _items.indexWhere((v) => v.id == id);
      if (i != -1) _items[i] = updated;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
