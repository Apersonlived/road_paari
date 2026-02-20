import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/routing_models.dart';
import '../../providers/map_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/common/bottom_nav_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController mapController;

  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  int _selectedIndex = 0;
  bool _isSearchExpanded = false;

  // Kathmandu Valley center and bounds
  final GeoPoint _kathmanduCenter =
      GeoPoint(latitude: 27.7172, longitude: 85.3240);
  final BoundingBox _kathmanduBounds = BoundingBox(
    east: 85.45,
    north: 27.80,
    south: 27.65,
    west: 85.20,
  );

  CompleteJourney? _currentJourney;
  bool _showRouteDetails = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _kathmanduCenter,
      areaLimit: _kathmanduBounds,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setKathmanduView();
    });
  }

  Future<void> _setKathmanduView() async {
    try {
      await mapController.setZoom(zoomLevel: 13);
      await mapController.moveTo(_kathmanduCenter);
    } catch (e) {
      debugPrint('Error setting Kathmandu view: $e');
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // Location Search
  Future<void> _searchLocation(String query, bool isStart) async {
    if (query.isEmpty) return;

    try {
      final List<SearchInfo> suggestions = await addressSuggestion(
        query,
        limitInformation: 5,
      );

      if (suggestions.isEmpty) {
        _showSnackBar('No locations found. Try searching within Kathmandu Valley.');
        return;
      }

      if (!mounted) return;

      final selected = await _showLocationSuggestions(suggestions);

      if (selected != null && selected.point != null) {
        final geoPoint = selected.point!;
        final locationProvider =
            Provider.of<LocationProvider>(context, listen: false);

        if (isStart) {
          locationProvider.setStartLocation(geoPoint);
          _startLocationController.text =
              selected.address?.toString() ?? query;
        } else {
          locationProvider.setDestinationLocation(geoPoint);
          _destinationController.text =
              selected.address?.toString() ?? query;
        }

        await mapController.addMarker(
          geoPoint,
          markerIcon: MarkerIcon(
            icon: Icon(
              isStart ? Icons.location_on : Icons.flag,
              color: isStart ? Colors.green : Colors.red,
              size: 48,
            ),
          ),
        );

        await mapController.moveTo(geoPoint);

        if (locationProvider.startLocation != null &&
            locationProvider.destinationLocation != null) {
          await _calculateRoute();
        }
      }
    } catch (e) {
      _showSnackBar('Error searching location: $e');
    }
  }

  Future<SearchInfo?> _showLocationSuggestions(List<SearchInfo> suggestions) {
    return showDialog<SearchInfo>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Location'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                leading: Icon(Icons.location_on, color: AppColors.primary),
                title: Text(
                  suggestion.address?.toString() ?? 'Unknown',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, suggestion),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Route Calculation ────────────────────────────────────────────────────────

  Future<void> _calculateRoute() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    if (locationProvider.startLocation == null ||
        locationProvider.destinationLocation == null) return;

    try {
      mapProvider.setLoading(true);
      setState(() => _showRouteDetails = false);

      await mapController.removeLastRoad();
      await mapController.clearAllRoads();

      final journey = await mapProvider.planJourney(
        startLat: locationProvider.startLocation!.latitude,
        startLng: locationProvider.startLocation!.longitude,
        endLat: locationProvider.destinationLocation!.latitude,
        endLng: locationProvider.destinationLocation!.longitude,
      );

      if (journey == null) {
        _showSnackBar('No route found. Try different locations.');
        mapProvider.setLoading(false);
        return;
      }

      setState(() {
        _currentJourney = journey;
        _showRouteDetails = true;
      });

      await _drawJourneyOnMap(journey);

      mapProvider.setLoading(false);
      setState(() => _isSearchExpanded = false);
    } catch (e) {
      Provider.of<MapProvider>(context, listen: false).setLoading(false);
      _showSnackBar('Error calculating route: $e');
    }
  }

  Future<void> _drawJourneyOnMap(CompleteJourney journey) async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Draw walking segment TO the first bus stop (orange dashed-style)
    if (journey.walkingToStart != null &&
        journey.walkingToStart!.isNotEmpty) {
      final walkPoints = journey.walkingToStart!
          .expand((w) => w.coordinates)
          .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
          .toList();

      if (walkPoints.isNotEmpty) {
        await mapController.drawRoadManually(
          walkPoints,
          RoadOption(
            roadWidth: 4,
            roadColor: Colors.orange,
            zoomInto: false,
          ),
        );
      }
    }

    // Draw walking segment FROM the last bus stop (orange)
    if (journey.walkingFromEnd != null &&
        journey.walkingFromEnd!.isNotEmpty) {
      final walkPoints = journey.walkingFromEnd!
          .expand((w) => w.coordinates)
          .map((c) => GeoPoint(latitude: c[0], longitude: c[1]))
          .toList();

      if (walkPoints.isNotEmpty) {
        await mapController.drawRoadManually(
          walkPoints,
          RoadOption(
            roadWidth: 4,
            roadColor: Colors.orange,
            zoomInto: false,
          ),
        );
      }
    }

    // Draw bus route geometry if a route has been selected/loaded
    if (mapProvider.selectedRouteDetails != null) {
      final busPoints = mapProvider.selectedRouteDetails!.flatCoordinates
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
      }
    }

    // Marker: nearest start stop
    if (journey.closestStartStop != null) {
      await mapController.addMarker(
        GeoPoint(
          latitude: journey.closestStartStop!.latitude,
          longitude: journey.closestStartStop!.longitude,
        ),
        markerIcon: MarkerIcon(
          icon: Icon(Icons.directions_bus, color: Colors.green, size: 40),
        ),
      );
    }

    // Marker: nearest end stop
    if (journey.closestEndStop != null) {
      await mapController.addMarker(
        GeoPoint(
          latitude: journey.closestEndStop!.latitude,
          longitude: journey.closestEndStop!.longitude,
        ),
        markerIcon: MarkerIcon(
          icon: Icon(Icons.directions_bus, color: Colors.red, size: 40),
        ),
      );
    }
  }

  Future<void> _loadAndDrawRoute(BusRoute route) async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    final details = await mapProvider.loadRouteDetails(
      routeId: route.routeId,
      startStopId: _currentJourney?.closestStartStop?.stopId,
      endStopId: _currentJourney?.closestEndStop?.stopId,
    );

    if (details != null && _currentJourney != null) {
      await mapController.clearAllRoads();
      await _drawJourneyOnMap(_currentJourney!);
    }
  }

  // Current Location 
  Future<void> _getCurrentLocation() async {
    try {
      final currentPosition = await mapController.myLocation();
      await mapController.moveTo(currentPosition);

      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      locationProvider.setCurrentLocation(currentPosition);
      locationProvider.setStartLocation(currentPosition);

      _startLocationController.text = 'Current Location';

      await mapController.addMarker(
        currentPosition,
        markerIcon: MarkerIcon(
          icon: const Icon(Icons.my_location, color: Colors.blue, size: 48),
        ),
      );

      setState(() => _isSearchExpanded = true);
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    }
  }

  // Clear Route
  Future<void> _clearRoute() async {
    await mapController.removeLastRoad();
    await mapController.clearAllRoads();

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    locationProvider.clearLocations();
    mapProvider.clearRoute();

    setState(() {
      _currentJourney = null;
      _showRouteDetails = false;
    });

    _startLocationController.clear();
    _destinationController.clear();
  }

  // Helpers 

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        break;
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map 
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
                  icon: const Icon(Icons.navigation,
                      color: Colors.blue, size: 48),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: const Icon(Icons.arrow_upward, size: 48),
                ),
              ),
              roadConfiguration: RoadOption(
                roadColor: AppColors.primary,
              ),
            ),
          ),

          // Search Panel
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
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
                          label: const Text('Where to?'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(double.infinity, 50),
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
                        _buildSearchField(
                          controller: _startLocationController,
                          icon: Icons.location_on,
                          hint: 'Start location',
                          onSubmitted: (v) => _searchLocation(v, true),
                        ),
                        const SizedBox(height: 12),
                        _buildSearchField(
                          controller: _destinationController,
                          icon: Icons.flag,
                          hint: 'Destination',
                          onSubmitted: (v) => _searchLocation(v, false),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _calculateRoute,
                          icon: const Icon(Icons.directions),
                          label: const Text('Get Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(double.infinity, 45),
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

          // Route Details Panel
          if (_showRouteDetails && _currentJourney != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: Card(
                margin: const EdgeInsets.all(16),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary),
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
                              label: _currentJourney!.formattedWalkingDistance,
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
                          label: 'Alight at',
                          stop: _currentJourney!.closestEndStop,
                        ),
                      ],

                      // Available bus routes list
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
                          (route) => _buildRouteListTile(route),
                        ),
                      ],

                      // No direct route warning
                      if (!_currentJourney!.hasDirectRoute) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'No direct route found. You may need to transfer.',
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
                              const Icon(Icons.directions_walk,
                                  color: Colors.orange),
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

          // Loading Overlay
          Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              if (!mapProvider.isLoading) return const SizedBox.shrink();
              return Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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
    Widget _buildSearchField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onSubmitted: onSubmitted,
    );
  }

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
              child: Icon(Icons.directions_bus,
                  color: AppColors.primary, size: 20),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (route.distanceMeters != null)
              Text(
                route.formattedDistance,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}