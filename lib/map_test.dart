import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MapTestApp());
}

class MapTestApp extends StatelessWidget {
  const MapTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapTestScreen(),
    );
  }
}

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({Key? key}) : super(key: key);

  @override
  _MapTestScreenState createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen> {
  final MapController _mapController = MapController();
  
  // Hardcoded test location (Riyadh)
  final LatLng _testLocation = LatLng(24.7136, 46.6753);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Test'),
      ),
      body: Column(
        children: [
          // Debug info bar
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Location: ${_testLocation.latitude}, ${_testLocation.longitude}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Map Controller Status: ${_mapController.camera.zoom}x zoom',
                  style: const TextStyle(color: Colors.yellow),
                ),
              ],
            ),
          ),
          
          // Map takes most of the screen
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _testLocation,
                initialZoom: 13.0,
                onMapReady: () {
                  debugPrint('Map is ready!');
                },
              ),
              children: [
                // Basic tile layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sajjel.app.dev',
                  maxZoom: 19,
                ),
                
                // Simple marker layer with a single marker
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _testLocation,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.white,
                            child: const Text('Riyadh', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoomIn',
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, currentZoom + 1);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'zoomOut',
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, currentZoom - 1);
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'recenter',
            onPressed: () {
              _mapController.move(_testLocation, 13.0);
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
} 