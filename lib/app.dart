import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

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

  // Kathmandu coordinates as default
  final GeoPoint _defaultLocation = GeoPoint(latitude: 27.7172, longitude: 85.3240);
  
  GeoPoint? _startLocation;
  GeoPoint? _destinationLocation;
  RoadInfo? _currentRoute;

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
          setState(() {
            if (isStart) {
              _startLocation = geoPoint;
            } else {
              _destinationLocation = geoPoint;
            }
          });

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

          await mapController.goToLocation(geoPoint);

          if (_startLocation != null && _destinationLocation != null) {
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
    if (_startLocation == null || _destinationLocation == null) return;

    try {
      // Remove previous route
      await mapController.removeLastRoad();

      // Draw new route
      RoadInfo roadInfo = await mapController.drawRoad(
        _startLocation!,
        _destinationLocation!,
        roadType: RoadType.car,
        roadOption: RoadOption(
          roadWidth: 10,
          roadColor: const Color(0xFF1DD1A1),
          zoomInto: true,
        ),
      );

      setState(() {
        _currentRoute = roadInfo;
      });

      if (mounted) {
        _showRouteInfo(roadInfo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error drawing route: $e')),
        );
      }
    }
  }

  void _showRouteInfo(RoadInfo roadInfo) {
    final distance = (roadInfo.distance! / 1000).toStringAsFixed(2);
    final duration = (roadInfo.duration! / 60).toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.straighten, color: Color(0xFF1DD1A1)),
                const SizedBox(width: 12),
                Text(
                  'Distance: $distance km',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF1DD1A1)),
                const SizedBox(width: 12),
                Text(
                  'Duration: $duration min',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Implement route optimization logic here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DD1A1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Optimize Route',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      GeoPoint currentPosition = await mapController.myLocation();
      await mapController.goToLocation(currentPosition);
      
      setState(() {
        _startLocation = currentPosition;
      });

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
    setState(() {
      _startLocation = null;
      _destinationLocation = null;
      _currentRoute = null;
      _startLocationController.clear();
      _destinationController.clear();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation to other screens
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // OSM Map
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
                    color: Colors.blue,
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
                roadColor: const Color(0xFF1DD1A1),
              ),
            ),
          ),

          // Search Fields Container
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Start Location Field
                  _buildSearchField(
                    controller: _startLocationController,
                    icon: Icons.location_on,
                    hint: 'Start Location',
                    isStart: true,
                  ),
                  const SizedBox(height: 12),
                  // Destination Field
                  _buildSearchField(
                    controller: _destinationController,
                    icon: Icons.flag,
                    hint: 'Destination',
                    isStart: false,
                  ),
                ],
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: const Color(0xFF1DD1A1),
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          // Clear Route Button (shows when route exists)
          if (_currentRoute != null)
            Positioned(
              right: 16,
              bottom: 240,
              child: FloatingActionButton(
                onPressed: _clearRoute,
                backgroundColor: Colors.red,
                mini: true,
                child: const Icon(Icons.clear, color: Colors.white),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1DD1A1),
          borderRadius: BorderRadius.circular(50),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black87,
          unselectedItemColor: Colors.black54,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'Updates',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isStart,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black54),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () => _searchLocation(controller.text, isStart),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onSubmitted: (value) => _searchLocation(value, isStart),
      ),
    );
  }
}