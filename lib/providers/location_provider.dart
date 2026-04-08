import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class LocationProvider with ChangeNotifier {
  GeoPoint? _currentLocation;
  GeoPoint? _startLocation;
  GeoPoint? _destinationLocation;

  GeoPoint? get currentLocation => _currentLocation;
  GeoPoint? get startLocation => _startLocation;
  GeoPoint? get destinationLocation => _destinationLocation;

  void setCurrentLocation(GeoPoint location) {
    _currentLocation = location;
    notifyListeners();
  }

  void setStartLocation(GeoPoint? location) {
    _startLocation = location;
    notifyListeners();
  }

  void setDestinationLocation(GeoPoint? location) {
    _destinationLocation = location;
    notifyListeners();
  }

  void clearLocations() {
    _startLocation = null;
    _destinationLocation = null;
    notifyListeners();
  }
}