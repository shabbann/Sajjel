import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../models/chat_model.dart';
import '../../models/note_model.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'location_map_screen.dart';
import 'map_launcher.dart'; // Import map launcher

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Position? _currentPosition;
  bool _isLoading = true;
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  double _currentZoom = 15.0;
  final DatabaseService _databaseService = DatabaseService();
  bool _mapInitialized = false;

  bool get _isMapSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    // Delay the location loading to ensure the map is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }
  
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _setupMarkers();
        });
        
        // Update map position if the map is initialized
        if (_currentPosition != null && _mapInitialized) {
          _mapController.move(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            15,
          );
          _currentZoom = 15.0;
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
      }
    }
  }
  
  void _setupMarkers() {
    if (_currentPosition == null) return;
    
    final marker = Marker(
      width: 80,
      height: 80,
      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 30,
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 4),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              "You are here",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
    
    setState(() {
      _markers = [marker];
    });
  }

  void _zoomIn() {
    if (!_mapInitialized) return;
    _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    if (!_mapInitialized) return;
    _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentLocation,
            tooltip: 'Refresh location',
          ),
          IconButton(
            icon: const Icon(Icons.new_releases),
            tooltip: 'Map Testing',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapLauncherScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildMapView(isDarkMode),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapLauncherScreen()),
          );
        },
        tooltip: 'Test Maps',
        child: const Icon(Icons.map_outlined),
      ),
    );
  }
  
  Widget _buildMapView(bool isDarkMode) {
    return _isLoading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Getting your location...'),
              ],
            ),
          )
        : _currentPosition == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Location not available',
                        style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Try Again'),
                      onPressed: _loadCurrentLocation,
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _currentPosition?.latitude ?? 0,
                        _currentPosition?.longitude ?? 0,
                      ),
                      initialZoom: 15,
                      minZoom: 3,
                      maxZoom: 18,
                      onMapReady: () {
                        setState(() {
                          _mapInitialized = true;
                          if (_currentPosition != null) {
                            _mapController.move(
                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              15,
                            );
                          }
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        // Use dark mode tiles if in dark mode
                        urlTemplate: isDarkMode
                            ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.sajjel.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(markers: _markers),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            isDarkMode
                                ? '© CartoDB | © OpenStreetMap contributors'
                                : '© OpenStreetMap contributors',
                            onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Map Controls
                  Positioned(
                    right: 16,
                    bottom: 96,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'zoom_in',
                          onPressed: _zoomIn,
                          child: Icon(Icons.add),
                          tooltip: 'Zoom in',
                        ),
                        SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_out',
                          onPressed: _zoomOut,
                          child: Icon(Icons.remove),
                          tooltip: 'Zoom out',
                        ),
                        SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'my_location',
                          onPressed: () {
                            if (_currentPosition != null) {
                              _mapController.move(
                                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                15,
                              );
                            }
                          },
                          child: Icon(Icons.my_location),
                          tooltip: 'My location',
                        ),
                      ],
                    ),
                  ),
                ],
              );
  }
} 