import 'package:flutter/material.dart';
import '../../data/models/poi_model.dart';
import '../../data/repositories/poi_repository.dart';

class POIProvider extends ChangeNotifier {
  final POIRepository _repository;

  POIProvider({required POIRepository repository}) : _repository = repository;

  // State
  List<POI> _pois = [];
  List<POI> _nearbyPois = [];
  List<POI> _searchResults = [];
  List<POICategory> _categories = [];
  POI? _selectedPoi;

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isLoadingNearby = false;
  String? _error;

  int? _selectedCategoryId;

  // Getters for poi info
  List<POI> get pois => _pois;
  List<POI> get nearbyPois => _nearbyPois;
  List<POI> get searchResults => _searchResults;
  List<POICategory> get categories => _categories;
  POI? get selectedPoi => _selectedPoi;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isLoadingNearby => _isLoadingNearby;
  String? get error => _error;
  int? get selectedCategoryId => _selectedCategoryId;

  // Load POIs
  Future<void> loadPOIs({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (refresh) _pois = [];
    notifyListeners();

    try {
      _pois = await _repository.getAllPOIs(categoryId: _selectedCategoryId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load Categories
  Future<void> loadCategories() async {
    try {
      _categories = await _repository.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  // Filter by Category
  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
    loadPOIs(refresh: true);
  }

  void clearCategoryFilter() {
    _selectedCategoryId = null;
    notifyListeners();
    loadPOIs(refresh: true);
  }

  // Search
  Future<void> searchPOIs(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _repository.searchPOIs(query);
    } catch (e) {
      _error = e.toString();
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  // Nearby POIs
  Future<void> loadNearbyPOIs({
    required double lat,
    required double lng,
    double radius = 1000,
    int? categoryId,
  }) async {
    _isLoadingNearby = true;
    _error = null;
    notifyListeners();

    try {
      _nearbyPois = await _repository.getNearbyPOIs(
        lat: lat,
        lng: lng,
        radius: radius,
        categoryId: categoryId,
      );
    } catch (e) {
      _error = e.toString();
      _nearbyPois = [];
    } finally {
      _isLoadingNearby = false;
      notifyListeners();
    }
  }

  // Select POI
  void selectPOI(POI poi) {
    _selectedPoi = poi;
    notifyListeners();
  }

  void clearSelectedPOI() {
    _selectedPoi = null;
    notifyListeners();
  }

  // Admin: Create
  Future<bool> createPOI({
    required String name,
    String? description,
    int? categoryId,
    required double latitude,
    required double longitude,
    String? imageUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newPoi = await _repository.createPOI(
        name: name,
        description: description,
        categoryId: categoryId,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
      );
      _pois = [newPoi, ..._pois];
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin: Update
  Future<bool> updatePOI({
    required int poiId,
    String? name,
    String? description,
    int? categoryId,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.updatePOI(
        poiId: poiId,
        name: name,
        description: description,
        categoryId: categoryId,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
      );
      _pois = _pois.map((p) => p.id == poiId ? updated : p).toList();
      if (_selectedPoi?.id == poiId) _selectedPoi = updated;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin: Upload Image (to be called after create/update)
  Future<bool> uploadPOIImage(int poiId, String filePath) async {
    try {
      final updated = await _repository.uploadPOIImage(poiId, filePath);
      _pois = _pois.map((p) => p.id == poiId ? updated : p).toList();
      if (_selectedPoi?.id == poiId) _selectedPoi = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Admin: Delete
  Future<bool> deletePOI(int poiId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deletePOI(poiId);
      _pois = _pois.where((p) => p.id != poiId).toList();
      if (_selectedPoi?.id == poiId) _selectedPoi = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
