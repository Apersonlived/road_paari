import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/routing_models.dart';
import '../../../providers/map_provider.dart';
import '../../../providers/location_provider.dart';
import '../../widgets/common/bottom_nav_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ── Controllers & Focus ───────────────────────────────────────────────────
  late MapController mapController;
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _startFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  // ── Overlay & LayerLink ───────────────────────────────────────────────────
  final LayerLink _startLayerLink = LayerLink();
  final LayerLink _destLayerLink = LayerLink();
  OverlayEntry? _startOverlay;
  OverlayEntry? _destOverlay;

  // ── Search State ──────────────────────────────────────────────────────────
  Timer? _searchDebounce;
  bool _isSearchingStart = false;
  bool _isSearchingDest = false;

  // ── UI State ──────────────────────────────────────────────────────────────
  int _selectedIndex = 0;
  bool _isSearchExpanded = true;
  CompleteJourney? _currentJourney;
  bool _showRouteDetails = false;

  // ── Map Config ────────────────────────────────────────────────────────────
  final GeoPoint _kathmanduCenter = GeoPoint(
    latitude: 27.7172,
    longitude: 85.3240,
  );
  final BoundingBox _kathmanduBounds = BoundingBox(
    east: 85.45,
    north: 27.80,
    south: 27.65,
    west: 85.20,
  );

  // ── Init & Dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _kathmanduCenter,
      areaLimit: _kathmanduBounds,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _setKathmanduView());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _removeAllOverlays();
    mapController.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    _startFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  Future<void> _setKathmanduView() async {
    try {
      await mapController.setZoom(zoomLevel: 13);
      await mapController.moveTo(_kathmanduCenter);
    } catch (e) {
      debugPrint('Error setting Kathmandu view: $e');
    }
  }

  Future<List<_PlaceSuggestion>> _searchPlaces(String query) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://nominatim.openstreetmap.org',
          headers: {
            'User-Agent': 'RoadPaari/1.0 (roadpaari@gmail.com)',
            'Accept-Language': 'en',
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'countrycodes': 'np',
        },
      );

      debugPrint('Nominatim raw response: ${response.data}');
      return (response.data as List)
          .map((r) => _PlaceSuggestion.fromJson(r))
          .toList();
    } catch (e) {
      debugPrint('Nominatim error: $e');
      return [];
    }
  }

  // ── Overlay Management ────────────────────────────────────────────────────
  void _showStartOverlay(List<_PlaceSuggestion> suggestions) {
    _removeStartOverlay();
    if (suggestions.isEmpty) return;
    _startOverlay = _buildOverlayEntry(
      layerLink: _startLayerLink,
      suggestions: suggestions,
      onSelect: _selectStartSuggestion,
    );
    Overlay.of(context).insert(_startOverlay!);
  }

  void _showDestOverlay(List<_PlaceSuggestion> suggestions) {
    _removeDestOverlay();
    if (suggestions.isEmpty) return;
    _destOverlay = _buildOverlayEntry(
      layerLink: _destLayerLink,
      suggestions: suggestions,
      onSelect: _selectDestSuggestion,
    );
    Overlay.of(context).insert(_destOverlay!);
  }

  OverlayEntry _buildOverlayEntry({
    required LayerLink layerLink,
    required List<_PlaceSuggestion> suggestions,
    required Function(_PlaceSuggestion) onSelect,
  }) {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.white,
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    final s = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      title: Text(
                        s.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        onSelect(s);
                        _removeAllOverlays();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeStartOverlay() {
    _startOverlay?.remove();
    _startOverlay = null;
  }

  void _removeDestOverlay() {
    _destOverlay?.remove();
    _destOverlay = null;
  }

  void _removeAllOverlays() {
    _removeStartOverlay();
    _removeDestOverlay();
  }

  // ── Search ────────────────────────────────────────────────────────────────
  void _onStartChanged(String value) {
    debugPrint('Search triggered: "$value" length=${value.length}');
    _searchDebounce?.cancel();
    if (value.length < 3) {
      _removeStartOverlay();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isSearchingStart = true);
      try {
        final results = await _searchPlaces(value);
        debugPrint('Start results: ${results.length}');
        if (mounted) _showStartOverlay(results);
      } finally {
        if (mounted) setState(() => _isSearchingStart = false);
      }
    });
  }

  void _onDestChanged(String value) {
    _searchDebounce?.cancel();
    if (value.length < 3) {
      _removeDestOverlay();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isSearchingDest = true);
      try {
        final results = await _searchPlaces(value);
        debugPrint('Dest results: ${results.length}');
        if (mounted) _showDestOverlay(results);
      } finally {
        if (mounted) setState(() => _isSearchingDest = false);
      }
    });
  }

  // ── Select Suggestions ────────────────────────────────────────────────────
  Future<void> _selectStartSuggestion(_PlaceSuggestion suggestion) async {
    _removeAllOverlays();
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    locationProvider.setStartLocation(suggestion.point);
    _startLocationController.text = suggestion.displayName;
    _startFocus.unfocus();
    await mapController.addMarker(
      suggestion.point,
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.location_on, color: Colors.green, size: 48),
      ),
    );
    await mapController.moveTo(suggestion.point);
    if (locationProvider.destinationLocation != null) await _calculateRoute();
  }

  Future<void> _selectDestSuggestion(_PlaceSuggestion suggestion) async {
    _removeAllOverlays();
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    locationProvider.setDestinationLocation(suggestion.point);
    _destinationController.text = suggestion.displayName;
    _destFocus.unfocus();
    await mapController.addMarker(
      suggestion.point,
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.flag, color: Colors.red, size: 48),
      ),
    );
    await mapController.moveTo(suggestion.point);
    if (locationProvider.startLocation != null) await _calculateRoute();
  }

  // ── Route Calculation ─────────────────────────────────────────────────────
  Future<void> _calculateRoute() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    if (locationProvider.startLocation == null ||
        locationProvider.destinationLocation == null) {
      _showSnackBar('Please set both start and destination');
      return;
    }

    try {
      setState(() => _showRouteDetails = false);
      await mapController.clearAllRoads();

      final journey = await mapProvider.planJourney(
        startLat: locationProvider.startLocation!.latitude,
        startLng: locationProvider.startLocation!.longitude,
        endLat: locationProvider.destinationLocation!.latitude,
        endLng: locationProvider.destinationLocation!.longitude,
      );

      if (journey == null) {
        _showSnackBar('No routes found between the selected stops.');
        return;
      }

      setState(() {
        _currentJourney = journey;
        _showRouteDetails = true;
        _isSearchExpanded = false;
      });

      await _drawJourneyOnMap(journey);
    } catch (e) {
      _showSnackBar('Error calculating route: $e');
    }
  }

  // ── Draw Journey ──────────────────────────────────────────────────────────
Future<void> _drawJourneyOnMap(CompleteJourney journey) async {
  // Only draw walking segments and stop markers on initial journey load.
  // Bus route geometry is drawn only when user taps a specific route tile.

  if (journey.walkingToStart?.isNotEmpty ?? false) {
    final walkPoints = journey.walkingToStart!
        .expand((w) => w.coordinates)
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (walkPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        walkPoints,
        RoadOption(roadWidth: 4, roadColor: Colors.orange, zoomInto: false),
      );
    }
  }

  if (journey.walkingFromEnd?.isNotEmpty ?? false) {
    final walkPoints = journey.walkingFromEnd!
        .expand((w) => w.coordinates)
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (walkPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        walkPoints,
        RoadOption(roadWidth: 4, roadColor: Colors.orange, zoomInto: false),
      );
    }
  }

  if (journey.closestStartStop != null) {
    await mapController.addMarker(
      GeoPoint(
        latitude: journey.closestStartStop!.latitude,
        longitude: journey.closestStartStop!.longitude,
      ),
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.directions_bus, color: Colors.green, size: 40),
      ),
    );
  }

  if (journey.closestEndStop != null) {
    await mapController.addMarker(
      GeoPoint(
        latitude: journey.closestEndStop!.latitude,
        longitude: journey.closestEndStop!.longitude,
      ),
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.directions_bus, color: Colors.red, size: 40),
      ),
    );
  }

  // Zoom to board stop
  if (journey.closestStartStop != null) {
    await mapController.moveTo(GeoPoint(
      latitude: journey.closestStartStop!.latitude,
      longitude: journey.closestStartStop!.longitude,
    ));
  }
}

// ── Called when user taps a route tile ───────────────────────────────────
Future<void> _loadAndDrawRoute(BusRoute route) async {
  final mapProvider = Provider.of<MapProvider>(context, listen: false);

  if (_currentJourney == null) return;

  final details = await mapProvider.loadRouteDetails(
    routeId: route.routeId,
    startStopId: _currentJourney!.closestStartStop?.stopId,
    endStopId: _currentJourney!.closestEndStop?.stopId,
  );

  debugPrint('Flat coordinates count: ${details?.flatCoordinates.length}');

  if (details == null) {
    _showSnackBar('Could not load route geometry');
    return;
  }

  // Clear all existing roads and markers
  await mapController.clearAllRoads();

  // Remove all previously added markers
  final pointsToRemove = <GeoPoint>[];
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);

  if (locationProvider.startLocation != null) {
    pointsToRemove.add(locationProvider.startLocation!);
  }
  if (locationProvider.destinationLocation != null) {
    pointsToRemove.add(locationProvider.destinationLocation!);
  }
  if (_currentJourney!.closestStartStop != null) {
    pointsToRemove.add(GeoPoint(
      latitude: _currentJourney!.closestStartStop!.latitude,
      longitude: _currentJourney!.closestStartStop!.longitude,
    ));
  }
  if (_currentJourney!.closestEndStop != null) {
    pointsToRemove.add(GeoPoint(
      latitude: _currentJourney!.closestEndStop!.latitude,
      longitude: _currentJourney!.closestEndStop!.longitude,
    ));
  }
  for (final point in pointsToRemove) {
    try { await mapController.removeMarker(point); } catch (_) {}
  }

  // ── 1. Walking to first stop (orange) ────────────────────────────────────
  if (_currentJourney!.walkingToStart?.isNotEmpty ?? false) {
    final walkPoints = _currentJourney!.walkingToStart!
        .expand((w) => w.coordinates)
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (walkPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        walkPoints,
        RoadOption(roadWidth: 4, roadColor: Colors.orange, zoomInto: false),
      );
    }
  }

  // ── 2. Bus route geometry (thick, primary color) ──────────────────────────
  final busPoints = details.flatCoordinates
      .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
      .toList();

  if (busPoints.isNotEmpty) {
    await mapController.drawRoadManually(
      busPoints,
      RoadOption(
        roadWidth: 8,
        roadColor: AppColors.primary,
        zoomInto: true,
      ),
    );
  } else {
    _showSnackBar('No geometry available for this route');
  }

  // ── 3. Walking from last stop (orange) ────────────────────────────────────
  if (_currentJourney!.walkingFromEnd?.isNotEmpty ?? false) {
    final walkPoints = _currentJourney!.walkingFromEnd!
        .expand((w) => w.coordinates)
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (walkPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        walkPoints,
        RoadOption(roadWidth: 4, roadColor: Colors.orange, zoomInto: false),
      );
    }
  }

  // ── 4. Re-add start/destination markers ───────────────────────────────────
  if (locationProvider.startLocation != null) {
    await mapController.addMarker(
      locationProvider.startLocation!,
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.location_on, color: Colors.green, size: 48),
      ),
    );
  }
  if (locationProvider.destinationLocation != null) {
    await mapController.addMarker(
      locationProvider.destinationLocation!,
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.flag, color: Colors.red, size: 48),
      ),
    );
  }

  // ── 5. Board and alight stop markers ─────────────────────────────────────
  if (_currentJourney!.closestStartStop != null) {
    await mapController.addMarker(
      GeoPoint(
        latitude: _currentJourney!.closestStartStop!.latitude,
        longitude: _currentJourney!.closestStartStop!.longitude,
      ),
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.directions_bus, color: Colors.green, size: 40),
      ),
    );
  }
  if (_currentJourney!.closestEndStop != null) {
    await mapController.addMarker(
      GeoPoint(
        latitude: _currentJourney!.closestEndStop!.latitude,
        longitude: _currentJourney!.closestEndStop!.longitude,
      ),
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.directions_bus, color: Colors.red, size: 40),
      ),
    );
  }
}

// ── inside _MapScreenState class ─────────────────────────────────────────

Future<void> _loadAndDrawTransferRoute(TransferRoute transfer) async {
  final mapProvider = Provider.of<MapProvider>(context, listen: false);
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);

  if (_currentJourney == null) return;

  // Load both route geometries
  final firstDetails = await mapProvider.loadRouteDetails(
    routeId: transfer.firstRouteId,
    startStopId: _currentJourney!.closestStartStop?.stopId,
    endStopId: transfer.transferStopId,
  );

  final secondDetails = await mapProvider.loadRouteDetails(
    routeId: transfer.secondRouteId,
    startStopId: transfer.transferStopId,
    endStopId: _currentJourney!.closestEndStop?.stopId,
  );

  if (firstDetails == null && secondDetails == null) {
    _showSnackBar('Could not load transfer route geometry');
    return;
  }

  // Clear everything
  await mapController.clearAllRoads();
  final pointsToRemove = <GeoPoint>[];
  if (locationProvider.startLocation != null) pointsToRemove.add(locationProvider.startLocation!);
  if (locationProvider.destinationLocation != null) pointsToRemove.add(locationProvider.destinationLocation!);
  if (_currentJourney!.closestStartStop != null) {
    pointsToRemove.add(GeoPoint(
      latitude: _currentJourney!.closestStartStop!.latitude,
      longitude: _currentJourney!.closestStartStop!.longitude,
    ));
  }
  if (_currentJourney!.closestEndStop != null) {
    pointsToRemove.add(GeoPoint(
      latitude: _currentJourney!.closestEndStop!.latitude,
      longitude: _currentJourney!.closestEndStop!.longitude,
    ));
  }
  for (final point in pointsToRemove) {
    try { await mapController.removeMarker(point); } catch (_) {}
  }

  // ── 1. Walking to first stop ──────────────────────────────────────────
  if (_currentJourney!.walkingToStart?.isNotEmpty ?? false) {
    final walkPoints = _currentJourney!.walkingToStart!
        .expand((w) => w.coordinates)
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (walkPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        walkPoints,
        RoadOption(roadWidth: 4, roadColor: Colors.orange, zoomInto: false),
      );
    }
  }

  // ── 2. First bus leg (primary color) ─────────────────────────────────
  if (firstDetails != null) {
    final busPoints = firstDetails.flatCoordinates
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (busPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        busPoints,
        RoadOption(roadWidth: 8, roadColor: AppColors.primary, zoomInto: true),
      );
    }
  }

  // ── 3. Transfer walk marker ───────────────────────────────────────────
  // Look up transfer stop coordinates from nearestStops or use a fixed lookup
  final transferStopPoint = _findStopPoint(transfer.transferStopId);
  if (transferStopPoint != null) {
    await mapController.addMarker(
      transferStopPoint,
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.sync_alt, color: Colors.orange, size: 40),
      ),
    );
  }

  // ── 4. Second bus leg (slightly different shade) ──────────────────────
  if (secondDetails != null) {
    final busPoints = secondDetails.flatCoordinates
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (busPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        busPoints,
        RoadOption(roadWidth: 8, roadColor: Colors.teal, zoomInto: false),
      );
    }
  }

  // ── 5. Walking from last stop ─────────────────────────────────────────
  if (_currentJourney!.walkingFromEnd?.isNotEmpty ?? false) {
    final walkPoints = _currentJourney!.walkingFromEnd!
        .expand((w) => w.coordinates)
        .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
        .toList();
    if (walkPoints.isNotEmpty) {
      await mapController.drawRoadManually(
        walkPoints,
        RoadOption(roadWidth: 4, roadColor: Colors.orange, zoomInto: false),
      );
    }
  }

  // ── 6. Re-add all markers ─────────────────────────────────────────────
  if (locationProvider.startLocation != null) {
    await mapController.addMarker(locationProvider.startLocation!,
      markerIcon: MarkerIcon(icon: const Icon(Icons.location_on, color: Colors.green, size: 48)));
  }
  if (locationProvider.destinationLocation != null) {
    await mapController.addMarker(locationProvider.destinationLocation!,
      markerIcon: MarkerIcon(icon: const Icon(Icons.flag, color: Colors.red, size: 48)));
  }
  if (_currentJourney!.closestStartStop != null) {
    await mapController.addMarker(
      GeoPoint(latitude: _currentJourney!.closestStartStop!.latitude,
               longitude: _currentJourney!.closestStartStop!.longitude),
      markerIcon: MarkerIcon(icon: const Icon(Icons.directions_bus, color: Colors.green, size: 40)),
    );
  }
  if (_currentJourney!.closestEndStop != null) {
    await mapController.addMarker(
      GeoPoint(latitude: _currentJourney!.closestEndStop!.latitude,
               longitude: _currentJourney!.closestEndStop!.longitude),
      markerIcon: MarkerIcon(icon: const Icon(Icons.directions_bus, color: Colors.red, size: 40)),
    );
  }
}

// Helper to find a stop's GeoPoint from journey data
GeoPoint? _findStopPoint(int stopId) {
  final allStops = [
    ...(_currentJourney?.nearestStartStops ?? []),
    ...(_currentJourney?.nearestEndStops ?? []),
  ];
  try {
    final stop = allStops.firstWhere((s) => s.stopId == stopId);
    return GeoPoint(latitude: stop.latitude, longitude: stop.longitude);
  } catch (_) {
    return null;
  }
}

Widget _buildTransferRouteTile(TransferRoute transfer) {
  return InkWell(                          // ← make it tappable
    onTap: () => _loadAndDrawTransferRoute(transfer),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First leg
          Row(
            children: [
              Icon(Icons.directions_bus, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(transfer.firstRouteName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          // Transfer point
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.sync_alt, color: Colors.orange, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Transfer at: ${transfer.transferStopName ?? 'Stop #${transfer.transferStopId}'}',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
                if (transfer.transferWalkMeters != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      transfer.transferWalkMeters! < 1000
                          ? '${transfer.transferWalkMeters!.toStringAsFixed(0)}m walk'
                          : '${(transfer.transferWalkMeters! / 1000).toStringAsFixed(1)}km walk',
                      style: TextStyle(fontSize: 10, color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          // Second leg
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.teal, size: 16), // ← teal to match map
              const SizedBox(width: 6),
              Expanded(
                child: Text(transfer.secondRouteName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (transfer.totalDistanceMeters != null)
                Text(transfer.formattedTotalDistance,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          // Tap hint
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Tap to view on map',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ],
      ),
    ),
  );
}

  // ── Current Location ──────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    try {
      final currentPosition = await mapController.myLocation();
      await mapController.moveTo(currentPosition);

      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );
      locationProvider.setCurrentLocation(currentPosition);
      locationProvider.setStartLocation(currentPosition);
      _startLocationController.text = 'Current Location';
      setState(() => _isSearchExpanded = true);

      await mapController.addMarker(
        currentPosition,
        markerIcon: MarkerIcon(
          icon: const Icon(Icons.my_location, color: Colors.blue, size: 48),
        ),
      );
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    }
  }

  // ── Clear Route ───────────────────────────────────────────────────────────
  Future<void> _clearRoute() async {
    _removeAllOverlays();
    _searchDebounce?.cancel();
    await mapController.clearAllRoads();
    await mapController.removeMarkers([]); // ← doesn't work for all, use below

    // Remove start/destination markers explicitly
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (locationProvider.startLocation != null) {
      await mapController.removeMarker(locationProvider.startLocation!);
    }
    if (locationProvider.destinationLocation != null) {
      await mapController.removeMarker(locationProvider.destinationLocation!);
    }
    // Remove stop markers
    if (_currentJourney?.closestStartStop != null) {
      await mapController.removeMarker(
        GeoPoint(
          latitude: _currentJourney!.closestStartStop!.latitude,
          longitude: _currentJourney!.closestStartStop!.longitude,
        ),
      );
    }
    if (_currentJourney?.closestEndStop != null) {
      await mapController.removeMarker(
        GeoPoint(
          latitude: _currentJourney!.closestEndStop!.latitude,
          longitude: _currentJourney!.closestEndStop!.longitude,
        ),
      );
    }

    Provider.of<LocationProvider>(context, listen: false).clearLocations();
    Provider.of<MapProvider>(context, listen: false).clearRoute();
    setState(() {
      _currentJourney = null;
      _showRouteDetails = false;
    });
    _startLocationController.clear();
    _destinationController.clear();

    // Re-center map
    await mapController.moveTo(_kathmanduCenter);
    await mapController.setZoom(zoomLevel: 13);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, AppRoutes.explore);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.updates);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          OSMFlutter(
            controller: mapController,
            osmOption: OSMOption(
              userTrackingOption: UserTrackingOption(
                enableTracking: true,
                unFollowUser: false,
              ),
              zoomOption: const ZoomOption(
                initZoom: 13,
                minZoomLevel: 10,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  icon: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 48,
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: const Icon(Icons.arrow_upward, size: 48),
                ),
              ),
              roadConfiguration: RoadOption(roadColor: AppColors.primary),
            ),
          ),

          // ── Search Panel ───────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Collapsed state
                      if (!_isSearchExpanded)
                        ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _isSearchExpanded = true),
                          icon: const Icon(Icons.search),
                          label: const Text(
                            'Where to?',
                            style: TextStyle(
                              height: 3.2,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(double.infinity, 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                      // Expanded state
                      if (_isSearchExpanded) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Plan Your Route',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _removeAllOverlays();
                                setState(() => _isSearchExpanded = false);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Start field
                        CompositedTransformTarget(
                          link: _startLayerLink,
                          child: TextField(
                            controller: _startLocationController,
                            focusNode: _startFocus,
                            onChanged: _onStartChanged,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                              ),
                              suffixIcon: _isSearchingStart
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _startLocationController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _startLocationController.clear();
                                        _removeStartOverlay();
                                        Provider.of<LocationProvider>(
                                          context,
                                          listen: false,
                                        ).setStartLocation(null);
                                      },
                                    )
                                  : null,
                              hintText: 'Start location',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Destination field
                        CompositedTransformTarget(
                          link: _destLayerLink,
                          child: TextField(
                            controller: _destinationController,
                            focusNode: _destFocus,
                            onChanged: _onDestChanged,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.flag,
                                color: Colors.green,
                              ),
                              suffixIcon: _isSearchingDest
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _destinationController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _destinationController.clear();
                                        _removeDestOverlay();
                                        Provider.of<LocationProvider>(
                                          context,
                                          listen: false,
                                        ).setDestinationLocation(null);
                                      },
                                    )
                                  : null,
                              hintText: 'Destination',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          onPressed: _calculateRoute,
                          icon: const Icon(Icons.directions),
                          label: const Text(
                            'Get Directions',
                            style: TextStyle(
                              height: 3.2,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(double.infinity, 25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Route Details Panel ────────────────────────────────────────────
          if (_showRouteDetails && _currentJourney != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: Material(
                color: Colors.transparent,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.70,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Route Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _showRouteDetails = false),
                                icon: const Icon(Icons.close),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const Divider(),

                          // Summary chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoChip(
                                icon: Icons.directions_bus,
                                label:
                                    '${_currentJourney!.directRoutes.length} route(s)',
                                color: AppColors.primary,
                              ),
                              if (_currentJourney!.hasWalkingSegments)
                                _buildInfoChip(
                                  icon: Icons.directions_walk,
                                  label:
                                      _currentJourney!.formattedWalkingDistance,
                                  color: Colors.orange,
                                ),
                            ],
                          ),

                          // Stop info
                          if (_currentJourney!.closestStartStop != null ||
                              _currentJourney!.closestEndStop != null) ...[
                            const SizedBox(height: 12),
                            _buildStopRow(
                              icon: Icons.trip_origin,
                              color: Colors.green,
                              label: 'Board at',
                              stop: _currentJourney!.closestStartStop,
                            ),
                            const SizedBox(height: 6),
                            _buildStopRow(
                              icon: Icons.location_on,
                              color: Colors.red,
                              label: 'Arrive at',
                              stop: _currentJourney!.closestEndStop,
                            ),
                          ],

                          // Available routes
                          // Direct routes
                          if (_currentJourney!.directRoutes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Available Routes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ..._currentJourney!.directRoutes.map(
                              _buildRouteListTile,
                            ),
                          ],

                          // Transfer routes (shown when no direct route)
                          if (_currentJourney!.directRoutes.isEmpty &&
                              _currentJourney!.transferRoutes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Transfer Routes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ..._currentJourney!.transferRoutes.map(
                              _buildTransferRouteTile,
                            ),
                          ],

                          // No direct route warning
                          if (!_currentJourney!.hasDirectRoute &&
                              _currentJourney!.transferRoutes.isEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'No route available. Try another location',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Walking notice
                          if (_currentJourney!.hasWalkingSegments) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.directions_walk,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Walk ${_currentJourney!.formattedWalkingDistance} to/from stops',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── FABs ───────────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 180,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'location',
                    onPressed: _getCurrentLocation,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.my_location),
                  ),
                  if (_currentJourney != null) ...[
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'clear',
                      onPressed: _clearRoute,
                      backgroundColor: Colors.red,
                      mini: true,
                      child: const Icon(Icons.clear),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Loading Overlay ────────────────────────────────────────────────
          Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              if (!mapProvider.isLoading) return const SizedBox.shrink();
              return Container(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Planning your journey...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStopRow({
    required IconData icon,
    required Color color,
    required String label,
    required NearestStop? stop,
  }) {
    if (stop == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            stop.displayName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          stop.formattedDistance,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRouteListTile(BusRoute route) {
    return InkWell(
      onTap: () => _loadAndDrawRoute(route),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_bus,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.routeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    route.routeType,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (route.distanceMeters != null)
              Text(
                route.formattedDistance,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  final String displayName;
  final GeoPoint point;

  _PlaceSuggestion({required this.displayName, required this.point});

  factory _PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return _PlaceSuggestion(
      displayName: json['display_name'] as String,
      point: GeoPoint(
        latitude: double.parse(json['lat']),
        longitude: double.parse(json['lon']),
      ),
    );
  }
}
