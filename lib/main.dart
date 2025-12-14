import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const RoadPaariApp());
}

class RoadPaariApp extends StatelessWidget {
  const RoadPaariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Paari',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  final MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Road Paari – Bus Routing")),
      body: Column(
        children: [
          // Embedded Map
          SizedBox(
            height: 250, // Adjust height as needed
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.road_paari",
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(27.7172, 85.3240),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Start / Destination Inputs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                TextField(
                  controller: startController,
                  decoration: InputDecoration(
                    labelText: "Starting Point",
                    border: OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: endController,
                  decoration: InputDecoration(
                    labelText: "Destination",
                    border: OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    // Navigate or fetch route later
                  },
                  child: const Text("Find Route"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}