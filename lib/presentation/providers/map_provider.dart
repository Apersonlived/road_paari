import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapProvider with ChangeNotifier {
  RoadInfo? _currentRoute;
  bool _isLoading = false;

  RoadInfo? get currentRoute => _currentRoute;
  bool get isLoading => _isLoading;

  void setCurrentRoute(RoadInfo? route) {
    _currentRoute = route;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearRoute() {
    _currentRoute = null;
    notifyListeners();
  }
}