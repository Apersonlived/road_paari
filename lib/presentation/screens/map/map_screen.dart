import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../providers/map_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import 'widgets/location_search_field.dart';
import 'widgets/route_info_card.dart';

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

  final GeoPoint _defaultLocation = GeoPoint(latitude: 27.7172, longitude: 85.3240);

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _defaultLocation,
      areaLimit: BoundingBox(
        east: 85.5,
        north: 27.9,
        south: 27.5,
        west: 85.1,
      ),
    );
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
      List<SearchInfo> suggestions = await addressSuggestion(query);
      
      if (suggestions.isNotEmpty && mounted) {
        final selected = suggestions.first;
        final geoPoint = selected.point;

        if (geoPoint != null) {
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          
          if (isStart) {
            locationProvider.setStartLocation(geoPoint);
          } else {
            locationProvider.setDestinationLocation(geoPoint);
          }

          await mapController.addMarker(
            geoPoint,
            markerIcon: MarkerIcon(
              icon: Icon(
                isStart ? Icons.location_on : Icons.flag,
                color: isStart ? AppColors.green : AppColors.red,
                size: 48,
              ),
            ),
          );

          await mapController.goToLocation(geoPoint);

          if (locationProvider.startLocation != null && 
              locationProvider.destinationLocation != null) {
            _drawRoute();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching location: $e')),
        );
      }
    }
  }

  Future<void> _drawRoute() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    if (locationProvider.startLocation == null || 
        locationProvider.destinationLocation == null) return;

    try {
      mapProvider.setLoading(true);
      
      await mapController.removeLastRoad();

      RoadInfo roadInfo = await mapController.drawRoad(
        locationProvider.startLocation!,
        locationProvider.destinationLocation!,
        roadType: RoadType.car,
        roadOption: RoadOption(
          roadWidth: 10,
          roadColor: AppColors.primary,
          zoomInto: true,
        ),
      );

      mapProvider.setCurrentRoute(roadInfo);
      mapProvider.setLoading(false);

      if (mounted) {
        _showRouteInfo(roadInfo);
      }
    } catch (e) {
      mapProvider.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error drawing route: $e')),
        );
      }
    }
  }

  void _showRouteInfo(RoadInfo roadInfo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RouteInfoCard(roadInfo: roadInfo),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      GeoPoint currentPosition = await mapController.myLocation();
      await mapController.moveTo(currentPosition);
      
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.setCurrentLocation(currentPosition);
      locationProvider.setStartLocation(currentPosition);

      await mapController.addMarker(
        currentPosition,
        markerIcon: MarkerIcon(
          icon: Icon(
            Icons.my_location,
            color: AppColors.blue,
            size: 48,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting current location: $e')),
        );
      }
    }
  }

  void _clearRoute() async {
    await mapController.removeLastRoad();
    await mapController.clearAllRoads();
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    locationProvider.clearLocations();
    mapProvider.clearRoute();
    
    _startLocationController.clear();
    _destinationController.clear();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
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
          OSMFlutter(
            controller: mapController,
            osmOption: OSMOption(
              userTrackingOption: UserTrackingOption(
                enableTracking: true,
                unFollowUser: false,
              ),
              zoomOption: ZoomOption(
                initZoom: 13,
                minZoomLevel: 3,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  icon: Icon(
                    Icons.location_history_rounded,
                    color: AppColors.blue,
                    size: 48,
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
              roadConfiguration: RoadOption(
                roadColor: AppColors.primary,
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  LocationSearchField(
                    controller: _startLocationController,
                    icon: Icons.location_on,
                    hint: AppStrings.startLocation,
                    onSearch: (value) => _searchLocation(value, true),
                  ),
                  SizedBox(height: 12),
                  LocationSearchField(
                    controller: _destinationController,
                    icon: Icons.flag,
                    hint: AppStrings.destination,
                    onSearch: (value) => _searchLocation(value, false),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.my_location, color: AppColors.white),
            ),
          ),

          Consumer<MapProvider>(
            builder: (context, mapProvider, child) {
              if (mapProvider.currentRoute != null) {
                return Positioned(
                  right: 16,
                  bottom: 240,
                  child: FloatingActionButton(
                    onPressed: _clearRoute,
                    backgroundColor: AppColors.red,
                    mini: true,
                    child: Icon(Icons.clear, color: AppColors.white),
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
}