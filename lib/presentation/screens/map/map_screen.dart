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
  final GeoPoint _kathmanduCenter = GeoPoint(latitude: 27.7172, longitude: 85.3240);
  final BoundingBox _kathmanduBounds = BoundingBox(
    east: 85.45,
    north: 27.80,
    south: 27.65,
    west: 85.20,
  );

  RouteData? _currentRouteData;
  bool _showRouteDetails = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _kathmanduCenter,
      areaLimit: _kathmanduBounds,
    );
    
    // Set initial map view to Kathmandu Valley
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setKathmanduView();
    });
  }

  Future<void> _setKathmanduView() async {
    try {
      await mapController.setZoom(zoomLevel: 13);
      await mapController.moveTo(_kathmanduCenter);
    } catch (e) {
      print('Error setting Kathmandu view: $e');
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query, bool isStart) async {
    if (query.isEmpty) return;

    try {
      // Search within Kathmandu Valley
      List<SearchInfo> suggestions = await addressSuggestion(
        query,
        limitInformation: 5,
      );
      
      if (suggestions.isEmpty) {
        _showSnackBar('No locations found. Try searching within Kathmandu Valley.');
        return;
      }

      if (mounted) {
        // Show suggestions dialog
        final selected = await _showLocationSuggestions(suggestions);
        
        if (selected != null && selected.point != null) {
          final geoPoint = selected.point!;
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          
          if (isStart) {
            locationProvider.setStartLocation(geoPoint);
            _startLocationController.text = selected.address?.toString() ?? query;
          } else {
            locationProvider.setDestinationLocation(geoPoint);
            _destinationController.text = selected.address?.toString() ?? query;
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
      }
    } catch (e) {
      _showSnackBar('Error searching location: $e');
    }
  }

  Future<SearchInfo?> _showLocationSuggestions(List<SearchInfo> suggestions) {
    return showDialog<SearchInfo>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Location'),
        content: Container(
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
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _calculateRoute() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    if (locationProvider.startLocation == null || 
        locationProvider.destinationLocation == null) return;

    try {
      mapProvider.setLoading(true);
      setState(() => _showRouteDetails = false);
      
      await mapController.removeLastRoad();
      await mapController.clearAllRoads();

      // Calculate route using backend
      final routeData = await mapProvider.calculateRoute(
        startLat: locationProvider.startLocation!.latitude,
        startLng: locationProvider.startLocation!.longitude,
        endLat: locationProvider.destinationLocation!.latitude,
        endLng: locationProvider.destinationLocation!.longitude,
      );

      if (routeData == null) {
        _showSnackBar('No route found. Try different locations.');
        mapProvider.setLoading(false);
        return;
      }

      setState(() {
        _currentRouteData = routeData;
        _showRouteDetails = true;
      });

      // Draw route on map
      await _drawRouteOnMap(routeData);

      mapProvider.setLoading(false);
      
      // Collapse search panel
      setState(() => _isSearchExpanded = false);
    } catch (e) {
      mapProvider.setLoading(false);
      _showSnackBar('Error calculating route: $e');
    }
  }

  Future<void> _drawRouteOnMap(RouteData routeData) async {
    final coordinates = routeData.routeCoordinates;
    if (coordinates.isEmpty) return;

    final geoPoints = coordinates.map((coord) {
      return GeoPoint(latitude: coord[0], longitude: coord[1]);
    }).toList();

    await mapController.drawRoadManually(
      geoPoints,
      RoadOption(
        roadWidth: 8,
        roadColor: AppColors.primary,
        zoomInto: true,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final currentPosition = await mapController.myLocation();
      await mapController.moveTo(currentPosition);
      
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.setCurrentLocation(currentPosition);
      locationProvider.setStartLocation(currentPosition);

      _startLocationController.text = 'Current Location';

      await mapController.addMarker(
        currentPosition,
        markerIcon: MarkerIcon(
          icon: Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 48,
          ),
        ),
      );

      setState(() => _isSearchExpanded = true);
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    }
  }

  void _clearRoute() async {
    await mapController.removeLastRoad();
    await mapController.clearAllRoads();
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    locationProvider.clearLocations();
    mapProvider.clearRoute();
    
    setState(() {
      _currentRouteData = null;
      _showRouteDetails = false;
    });
    
    _startLocationController.clear();
    _destinationController.clear();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    
    switch (index) {
      case 0: break;
      case 1: Navigator.pushNamed(context, AppRoutes.explore); break;
      case 2: Navigator.pushNamed(context, AppRoutes.updates); break;
      case 3: Navigator.pushNamed(context, AppRoutes.profile); break;
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
              zoomOption: ZoomOption(
                initZoom: 13,
                minZoomLevel: 10,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  icon: Icon(Icons.navigation, color: Colors.blue, size: 48),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: Icon(Icons.arrow_upward, size: 48),
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
              duration: Duration(milliseconds: 300),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Compact mode: Just show button
                      if (!_isSearchExpanded)
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isSearchExpanded = true),
                          icon: Icon(Icons.search),
                          label: Text('Where to?'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      
                      // Expanded mode: Show full search fields
                      if (_isSearchExpanded) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Plan Your Route',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _isSearchExpanded = false),
                              icon: Icon(Icons.close),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildSearchField(
                          controller: _startLocationController,
                          icon: Icons.location_on,
                          hint: 'Start location',
                          onSubmitted: (value) => _searchLocation(value, true),
                        ),
                        SizedBox(height: 12),
                        _buildSearchField(
                          controller: _destinationController,
                          icon: Icons.flag,
                          hint: 'Destination',
                          onSubmitted: (value) => _searchLocation(value, false),
                        ),
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _calculateRoute,
                          icon: Icon(Icons.directions),
                          label: Text('Get Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: Size(double.infinity, 45),
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
          if (_showRouteDetails && _currentRouteData != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: Card(
                margin: EdgeInsets.all(16),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Route Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            onPressed: () => setState(() => _showRouteDetails = false),
                            icon: Icon(Icons.close),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoChip(
                            icon: Icons.straighten,
                            label: _currentRouteData!.formattedDistance,
                            color: Colors.blue,
                          ),
                          _buildInfoChip(
                            icon: Icons.access_time,
                            label: _currentRouteData!.formattedTime,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      if (_currentRouteData!.hasWalkingSegments) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.directions_walk, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This route includes walking segments',
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

          // Action Buttons
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'location',
                  onPressed: _getCurrentLocation,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.my_location),
                ),
                if (_currentRouteData != null) ...[
                  SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'clear',
                    onPressed: _clearRoute,
                    backgroundColor: Colors.red,
                    mini: true,
                    child: Icon(Icons.clear),
                  ),
                ],
              ],
            ),
          ),

          // Loading Indicator
          Consumer<MapProvider>(
            builder: (context, mapProvider, child) {
              if (mapProvider.isLoading) {
                return Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Calculating route...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}