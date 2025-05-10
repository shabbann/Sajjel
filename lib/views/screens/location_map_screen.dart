import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // Import for min() function
import '../../models/note_model.dart';
import '../../services/location_service.dart';
import '../../services/map_launcher.dart';
import '../../services/database_service.dart';
import '../../controllers/note_controller.dart';
import 'map_launcher.dart'; // Import the map launcher screen

class LocationMapScreen extends StatefulWidget {
  final String title;

  const LocationMapScreen({
    Key? key,
    this.title = 'All Note Locations',
  }) : super(key: key);

  @override
  _LocationMapScreenState createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  late final MapController _mapController;
  List<Marker> _markers = [];
  LatLng _center = LatLng(0, 0);
  double _zoom = 2.0;
  double _currentZoom = 2.0;
  bool _isLoading = true;
  bool _showList = false;
  List<Note> _notesWithLocation = [];
  String? _errorMessage;
  int _allNotesCount = 0;
  List<Note> _recentNotes = [];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadAllLocationNotes();
  }

  Future<void> _loadAllLocationNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final allNotes = await dbService.getAllNotes();
      _allNotesCount = allNotes.length;
      debugPrint('LocationMapScreen: Fetched ${allNotes.length} total notes from DB.');

      // Store the 10 most recent notes regardless of location
      _recentNotes = List<Note>.from(allNotes); // Create a copy of the list
      _recentNotes.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by timestamp, newest first
      if (_recentNotes.length > 10) {
        _recentNotes = _recentNotes.sublist(0, 10); // Keep only the 10 most recent
      }
          
      _notesWithLocation = allNotes.where((note) => note.hasLocation).toList();
      debugPrint('LocationMapScreen: Found ${_notesWithLocation.length} notes with location data.');
      
      // Print details of each location note for debugging
      for (int i = 0; i < _notesWithLocation.length; i++) {
        final note = _notesWithLocation[i];
        debugPrint('Location Note $i: Lat=${note.latitude}, Lng=${note.longitude}, Name=${note.locationName}');
      }

      if (_notesWithLocation.isEmpty) {
        debugPrint("No notes with location found. Using default coordinates.");
        _center = LatLng(24.7136, 46.6753); // Riyadh coordinates
        _zoom = 5.0;
        _currentZoom = _zoom;
      } else {
        _calculateCenterAndZoom();
      }
      _setupMarkers();
      debugPrint('LocationMapScreen: Finished setting up ${_markers.length} markers.');

    } catch (e) {
      debugPrint('LocationMapScreen: Error loading location notes: $e');
      setState(() {
        _errorMessage = "Failed to load location notes: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateCenterAndZoom() {
    if (_notesWithLocation.isEmpty) return;
    
    if (_notesWithLocation.length > 1) {
      double sumLat = 0;
      double sumLng = 0;
      double minLat = _notesWithLocation.first.latitude!;
      double maxLat = _notesWithLocation.first.latitude!;
      double minLng = _notesWithLocation.first.longitude!;
      double maxLng = _notesWithLocation.first.longitude!;

      for (final note in _notesWithLocation) {
        sumLat += note.latitude!;
        sumLng += note.longitude!;
        minLat = note.latitude! < minLat ? note.latitude! : minLat;
        maxLat = note.latitude! > maxLat ? note.latitude! : maxLat;
        minLng = note.longitude! < minLng ? note.longitude! : minLng;
        maxLng = note.longitude! > maxLng ? note.longitude! : maxLng;
      }

      _center = LatLng(sumLat / _notesWithLocation.length, sumLng / _notesWithLocation.length);

      final distance = calculateDistance(minLat, minLng, maxLat, maxLng);
      _zoom = getZoomLevel(distance);
      _currentZoom = _zoom;
    } else if (_notesWithLocation.isNotEmpty) {
      _center = LatLng(_notesWithLocation.first.latitude!, _notesWithLocation.first.longitude!);
      _zoom = 15.0;
      _currentZoom = 15.0;
    }
  }

  void _setupMarkers() {
    List<Marker> markers = [];
    
    // Always add a test marker for verification
    final testPosition = LatLng(24.7136, 46.6753); // Default position (Riyadh)
    markers.add(
      Marker(
        width: 60,
        height: 60,
        point: testPosition,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              color: Colors.black,
              child: const Text('TEST', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
            const Icon(
              Icons.star,
              color: Colors.red,
              size: 40,
            ),
          ],
        ),
      )
    );
    
    // Add markers for each note with location
    if (_notesWithLocation.isNotEmpty) {
      final colors = [
        Colors.red, 
        Colors.blue, 
        Colors.green, 
        Colors.orange, 
        Colors.purple
      ];
      
      for (int i = 0; i < _notesWithLocation.length; i++) {
        final note = _notesWithLocation[i];
        final position = LatLng(note.latitude!, note.longitude!);
        final color = colors[i % colors.length];
        
        markers.add(
          Marker(
            width: 60,
            height: 60,
            point: position,
            child: GestureDetector(
              onTap: () => _showNoteDetailsDialog(note),
              child: Column(
                children: [
                  if (note.locationName != null)
                    Container(
                      padding: const EdgeInsets.all(2),
                      color: Colors.white,
                      child: Text(
                        note.locationName!.length > 10 
                            ? '${note.locationName!.substring(0, 10)}...' 
                            : note.locationName!,
                        style: TextStyle(color: Colors.black, fontSize: 10),
                      ),
                    ),
                  Icon(
                    Icons.location_pin,
                    color: color,
                    size: 40,
                  ),
                ],
              ),
            ),
          )
        );
      }
    }

    setState(() {
      _markers = markers;
      debugPrint('Markers setup complete, ${_markers.length} markers created');
    });
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return const Distance().distance(
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  double getZoomLevel(double distance) {
    if (distance <= 100) return 15.0;
    if (distance <= 500) return 14.0;
    if (distance <= 2000) return 13.0;
    if (distance <= 5000) return 12.0;
    if (distance <= 20000) return 10.0;
    if (distance <= 50000) return 8.0;
    return 6.0;
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _showNoteDetailsDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.content),
              const SizedBox(height: 16),
              if (note.locationName != null)
                Text('Location: ${note.locationName}'),
              const SizedBox(height: 8),
              Text('Date: ${note.timestamp.toLocal().toString().split('.')[0]}'),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Tags: ${note.tags.join(', ')}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () => _openInMaps(note),
            child: Text('Open in Maps'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(Note note) async {
    if (!note.hasLocation) return;
    
    try {
      print('Opening map from location screen for: ${note.latitude!}, ${note.longitude!}');
      
      final success = await MapLauncher.openMap(
        note.latitude!, 
        note.longitude!,
        label: note.locationName,
      );
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps application. Make sure you have a maps app installed.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in _openInMaps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening map: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location Map (${_notesWithLocation.length} notes)'),
        actions: [
          // Add a button to launch the standalone map test
          IconButton(
            icon: const Icon(Icons.new_releases),
            tooltip: 'Try Standalone Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapLauncherScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Map',
            onPressed: _loadAllLocationNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Debug information at the top
                    Container(
                      width: double.infinity,
                      color: Colors.black,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCATION DATA DIAGNOSTIC',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Total notes in database: ${_allNotesCount}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Notes with location: ${_notesWithLocation.length}',
                            style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Markers created: ${_markers.length}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Map center: ${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.cyan),
                          ),
                          Text(
                            'Map status: ${_mapReady ? "Ready" : "Not yet ready"}',
                            style: TextStyle(color: _mapReady ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    
                    // Button row
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _createTestNoteWithLocation,
                            child: const Text('Create Test Note'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _loadAllLocationNotes, 
                            child: const Text('Refresh Data'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MapLauncherScreen()),
                              );
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Test Map'),
                          ),
                        ],
                      ),
                    ),
                    
                    // Map
                    Expanded(
                      child: _buildMapView(),
                    ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoomIn',
            onPressed: () {
              _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
              _mapController.move(_mapController.camera.center, _currentZoom);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'zoomOut',
            onPressed: () {
              _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
              _mapController.move(_mapController.camera.center, _currentZoom);
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'recenter',
            onPressed: () {
              _mapController.move(_center, _zoom);
              setState(() {
                _currentZoom = _zoom;
              });
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _zoom,
        onMapReady: () {
          debugPrint('Map is ready!');
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
        MarkerLayer(markers: _markers),
      ],
    );
  }

  // Create a test note with location to diagnose any issues
  Future<void> _createTestNoteWithLocation() async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      
      // Get all chats to find a valid chatId
      final chats = await dbService.getChats();
      if (chats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: No chats found in database. Please create a chat first.')),
        );
        return;
      }
      
      final chatId = chats.first.id; // Use the first available chat
      
      final note = Note(
        id: 'test_location_note_${DateTime.now().millisecondsSinceEpoch}',
        content: 'This is a test note with location data',
        timestamp: DateTime.now(),
        isUserNote: true,
        chatId: chatId, // Use a valid chat ID
        tags: ['test', 'location'],
        latitude: 24.7136, // Riyadh coordinates
        longitude: 46.6753,
        locationName: 'Test Location in Riyadh',
      );
      
      await dbService.insertNote(note);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test note with location created in chat: ${chats.first.name}')),
      );
      
      // Reload the data
      _loadAllLocationNotes();
    } catch (e) {
      debugPrint('Error creating test note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating test note: $e')),
      );
    }
  }
} 