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
import '../../../providers/poi_provider.dart';
import '../../../data/models/poi_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController mapController;
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _startFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  final LayerLink _startLayerLink = LayerLink();
  final LayerLink _destLayerLink = LayerLink();
  OverlayEntry? _startOverlay;
  OverlayEntry? _destOverlay;

  Timer? _searchDebounce;
  bool _isSearchingStart = false;
  bool _isSearchingDest = false;

  int _selectedIndex = 0;
  bool _isSearchExpanded = true;
  CompleteJourney? _currentJourney;

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

  final Map<GeoPoint, POI> _poiMarkerMap = {};
  bool _poisLoaded = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _kathmanduCenter,
      areaLimit: _kathmanduBounds,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setKathmanduView();
      await _loadPOIMarkers();
    });
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
// 1. Define Dio at the class level to reuse the connection (prevents socket exhaustion)
final Dio _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15), // Increased slightly
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      // Be very specific with the User-Agent
      'User-Agent': 'RoadPaari_App_v1.0 (contact: roadpaari@gmail.com)',
      'Accept-Language': 'en', // Helps Nominatim process the request faster
    },
  ),
);

Future<List<_PlaceSuggestion>> _searchPlaces(String query) async {
  if (query.isEmpty) return [];

  try {
    // 2. Use the full URL directly to avoid BaseUrl resolution issues
    // and use 'search' with a trailing slash or .php to be more explicit
    final response = await _dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': 5,
        'countrycodes': 'np', // Nepal filter
        'addressdetails': 1,
      },
    );

    if (response.statusCode == 200) {
      return (response.data as List)
          .map((r) => _PlaceSuggestion.fromJson(r))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    // 3. Specific logging to see exactly why it's timing out
    if (e.type == DioExceptionType.connectionTimeout) {
      debugPrint('Nominatim Timeout: Check your internet or if the IP is throttled');
    } else {
      debugPrint('Nominatim Dio Error: ${e.message}');
    }
    return [];
  } catch (e) {
    debugPrint('Nominatim General error: $e');
    return [];
  }
}

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

  Future<void> _loadPOIMarkers() async {
    if (_poisLoaded) return;
    final poiProvider = Provider.of<POIProvider>(context, listen: false);

    if (poiProvider.pois.isEmpty) {
      await poiProvider.loadPOIs();
    }

    for (final poi in poiProvider.pois) {
      if (poi.latitude == null || poi.longitude == null) continue;
      final point = GeoPoint(
        latitude: poi.latitude!,
        longitude: poi.longitude!,
      );
      try {
        await mapController.addMarker(
          point,
          markerIcon: MarkerIcon(
            iconWidget: SizedBox(
              width: 80,
              height: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      poi.name,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.location_on, color: Colors.blue, size: 28),
                ],
              ),
            ),
          ),
        );
        _poiMarkerMap[point] = poi;
      } catch (e) {
        debugPrint('Error adding POI marker: $e');
      }
    }
    _poisLoaded = true;
  }

  void _onStartChanged(String value) {
    _searchDebounce?.cancel();
    if (value.length < 3) {
      _removeStartOverlay();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isSearchingStart = true);
      try {
        var results = await _searchPlaces(value);
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
        var results = await _searchPlaces(value);
        if (mounted) _showDestOverlay(results);
      } finally {
        if (mounted) setState(() => _isSearchingDest = false);
      }
    });
  }

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
      await mapController.clearAllRoads();

      var journey = await mapProvider.planJourney(
        startLat: locationProvider.startLocation!.latitude,
        startLng: locationProvider.startLocation!.longitude,
        endLat: locationProvider.destinationLocation!.latitude,
        endLng: locationProvider.destinationLocation!.longitude,
      );

      if (journey == null || journey.errorMessage != null) {
        _showSnackBar(journey?.errorMessage ?? 'No routes found');
        return;
      }

      setState(() {
        _currentJourney = journey;
        _isSearchExpanded = false;
      });

      await _drawJourneyOnMap(journey);
    } catch (e) {
      _showSnackBar('Error calculating route: $e');
    }
  }

  Future<void> _drawJourneyOnMap(CompleteJourney journey) async {
    await mapController.clearAllRoads();

    for (var leg in journey.journeyLegs) {
      if (leg.legType == 'walk' &&
          leg.segments != null &&
          leg.segments!.isNotEmpty) {
        var walkPoints = leg.segments!
            .expand((w) => w.coordinates)
            .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
            .toList();

        if (walkPoints.isNotEmpty) {
          await mapController.drawRoadManually(
            walkPoints,
            RoadOption(roadWidth: 5, roadColor: Colors.orange, zoomInto: false),
          );
        }
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

    if (journey.closestStartStop != null) {
      await mapController.moveTo(
        GeoPoint(
          latitude: journey.closestStartStop!.latitude,
          longitude: journey.closestStartStop!.longitude,
        ),
      );
    }
  }

  Future<void> _zoomToLocation(double lat, double lng) async {
    if (lat == 0 && lng == 0) return;
    var point = GeoPoint(latitude: lat, longitude: lng);
    await mapController.moveTo(point, animate: true);
    await mapController.setZoom(zoomLevel: 17);
    await mapController.addMarker(
      point,
      markerIcon: MarkerIcon(
        icon: const Icon(Icons.location_on, color: Colors.blue, size: 50),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      var currentPosition = await mapController.myLocation();
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

  Future<void> _clearRoute() async {
    _removeAllOverlays();
    _searchDebounce?.cancel();
    await mapController.clearAllRoads();
    await mapController.removeMarkers([]);

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (locationProvider.startLocation != null)
      await mapController.removeMarker(locationProvider.startLocation!);
    if (locationProvider.destinationLocation != null)
      await mapController.removeMarker(locationProvider.destinationLocation!);

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

    locationProvider.clearLocations();
    Provider.of<MapProvider>(context, listen: false).clearRoute();

    setState(() {
      _currentJourney = null;
      _isSearchExpanded = true;
    });

    _startLocationController.clear();
    _destinationController.clear();

    await mapController.moveTo(_kathmanduCenter);
    await mapController.setZoom(zoomLevel: 13);
    _poisLoaded = false;
    await _loadPOIMarkers();
  }

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

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // ← Move journey panel here instead of inside Stack
      bottomSheet: _currentJourney != null ? _buildJourneySheet() : null,
      body: Stack(
        children: [
          OSMFlutter(
            controller: mapController,
            onGeoPointClicked: (point) {
              final poi = _poiMarkerMap[point];
              if (poi != null) _showPOIDetail(poi);
            },
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

          // Search card
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
                              onPressed: () =>
                                  setState(() => _isSearchExpanded = false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
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

          // FABs
          Positioned(
            right: 16,
            bottom: 180,
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

          // Loading overlay
          Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              if (!mapProvider.isLoading) return const SizedBox.shrink();
              return Container(
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

  // Extracted journey sheet into its own method
  Widget _buildJourneySheet() {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.2, 0.35, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Journey',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._currentJourney!.journeyLegs.map(
                        (leg) => _buildLegTile(leg),
                      ),
                      const Divider(height: 32),
                      // In _buildJourneySheet, replace the summary container:
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // Clear route button inside the sheet
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _clearRoute,
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Clear Route',
                                  style: TextStyle(color: Colors.red),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegTile(JourneyLeg leg) {
  final isBus = leg.legType == 'bus';
  final distMeters = leg.effectiveDistance;
  final distText = distMeters >= 1000
      ? '${(distMeters / 1000).toStringAsFixed(1)} km'
      : '${distMeters.toStringAsFixed(0)} m';

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + description + distance
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isBus ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isBus ? Icons.directions_bus : Icons.directions_walk,
                  color: isBus ? Colors.blue : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leg.description,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        Text(distText,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        if (isBus && (leg.fareNrs ?? 0) > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.confirmation_number, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 3),
                          Text('Nrs. ${(leg.fareNrs ?? 0).toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Stop chips row — only for bus legs
          if (isBus) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (leg.boardStop != null)
                    _buildStopChip(leg.boardStop!, Icons.circle, Colors.green),
                  if (leg.boardStop != null && leg.alightStop != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                    ),
                  if (leg.transferStop != null) ...[
                    _buildStopChip(leg.transferStop!, Icons.swap_horiz, Colors.purple),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                    ),
                  ],
                  if (leg.alightStop != null)
                    _buildStopChip(leg.alightStop!, Icons.location_on, Colors.red),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildStopChip(StopInfo stop, IconData icon, Color color) {
  return GestureDetector(
    onTap: () => _zoomToLocation(stop.latitude, stop.longitude),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            stop.displayName,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
}

  void _showPOIDetail(POI poi) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (poi.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  poi.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poi.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (poi.description != null && poi.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                poi.description!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (poi.latitude != null && poi.longitude != null) {
                    final point = GeoPoint(
                      latitude: poi.latitude!,
                      longitude: poi.longitude!,
                    );
                    Provider.of<LocationProvider>(
                      context,
                      listen: false,
                    ).setDestinationLocation(point);
                    _destinationController.text = poi.name;
                    setState(() => _isSearchExpanded = true);
                    mapController.moveTo(point);
                  }
                },
                icon: const Icon(Icons.directions),
                label: const Text('Set as destination'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
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
