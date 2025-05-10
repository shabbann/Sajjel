import 'package:flutter/material.dart';
import '../../map_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapLauncherScreen extends StatelessWidget {
  const MapLauncherScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Testing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 64, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Map Troubleshooting',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This screen helps diagnose map display issues.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapTestScreen()),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('Launch Standalone Map Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InlineMapTest()),
                );
              },
              icon: const Icon(Icons.pin_drop),
              label: const Text('Inline Map Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'The map test includes a minimal implementation that should work regardless of any issues in the main app. If this works but the main map doesn\'t, there may be an issue with data loading or markers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InlineMapTest extends StatefulWidget {
  const InlineMapTest({Key? key}) : super(key: key);

  @override
  _InlineMapTestState createState() => _InlineMapTestState();
}

class _InlineMapTestState extends State<InlineMapTest> {
  final MapController _mapController = MapController();
  final LatLng _testLocation = LatLng(24.7136, 46.6753); // Riyadh coordinates
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inline Map Test'),
      ),
      body: Column(
        children: [
          // Info panel
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INLINE MAP TEST',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Test Location: ${_testLocation.latitude}, ${_testLocation.longitude}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Map status: ${_mapReady ? "Ready" : "Loading..."}',
                  style: TextStyle(
                    color: _mapReady ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // The actual map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _testLocation,
                initialZoom: 13.0,
                onMapReady: () {
                  debugPrint('Inline map test: Map is ready!');
                  setState(() {
                    _mapReady = true;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sajjel.app.dev',
                  maxZoom: 19,
                ),
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
                            child: const Text('TEST MARKER', style: TextStyle(fontWeight: FontWeight.bold)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(_testLocation, 13.0);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
} 