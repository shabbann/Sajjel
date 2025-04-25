import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/note_model.dart';
import '../../services/location_service.dart';
import '../../services/map_launcher.dart';

class LocationMapScreen extends StatefulWidget {
  final List<Note> notes;
  final String title;

  const LocationMapScreen({
    Key? key,
    required this.notes,
    this.title = 'Note Locations',
  }) : super(key: key);

  @override
  _LocationMapScreenState createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  MapController _mapController = MapController();
  List<Marker> _markers = [];
  LatLng _center = LatLng(0, 0);
  double _zoom = 13.0;
  double _currentZoom = 13.0;
  bool _showList = false;
  List<Note> _notesWithLocation = [];

  @override
  void initState() {
    super.initState();
    // Initialize notes with location
    _notesWithLocation = widget.notes.where((note) => note.hasLocation).toList();
    // Calculate center and zoom level
    _calculateCenterAndZoom();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Setup markers after dependencies are initialized
    _setupMarkers();
  }

  void _calculateCenterAndZoom() {
    if (_notesWithLocation.isEmpty) return;
    
    // Calculate center and zoom level
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

      // Calculate center
      _center = LatLng(sumLat / _notesWithLocation.length, sumLng / _notesWithLocation.length);

      // Estimate zoom level based on distance between the farthest points
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
    if (_notesWithLocation.isEmpty) return;
    
    // Create markers for each note with location data
    final markers = _notesWithLocation.asMap().entries.map((entry) {
      final index = entry.key;
      final note = entry.value;
      final position = LatLng(note.latitude!, note.longitude!);

      // Use different colors for different markers
      final colors = [
        Colors.red, 
        Colors.blue, 
        Colors.green, 
        Colors.orange, 
        Colors.purple
      ];
      final color = colors[index % colors.length];
      
      return Marker(
        width: 150,
        height: 80,
        point: position,
        child: GestureDetector(
          onTap: () => _showNoteDetailsDialog(note),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints: const BoxConstraints(maxWidth: 120),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  note.locationName ?? 'Location',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    setState(() {
      _markers = markers;
    });
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple distance calculation
    return const Distance().distance(
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  double getZoomLevel(double distance) {
    // Estimate zoom level based on distance
    if (distance <= 100) return 15.0;  // Very close points
    if (distance <= 500) return 14.0;  // Close points
    if (distance <= 2000) return 13.0; // Neighborhood
    if (distance <= 5000) return 12.0; // Small city
    if (distance <= 20000) return 10.0; // City
    if (distance <= 50000) return 8.0;  // Region
    return 6.0; // Default for large distances
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
    final notesWithLocation = widget.notes.where((note) => note.hasLocation).toList();
    // Check if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_showList ? Icons.map : Icons.list),
            onPressed: () {
              setState(() {
                _showList = !_showList;
              });
            },
            tooltip: _showList ? 'Show Map' : 'Show List',
          ),
        ],
      ),
      body: notesWithLocation.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notes with location data found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : _showList
              ? ListView.builder(
                  itemCount: notesWithLocation.length,
                  itemBuilder: (context, index) {
                    final note = notesWithLocation[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.primaries[index % Colors.primaries.length],
                        child: Icon(Icons.location_on, color: Colors.white),
                      ),
                      title: Text(
                        note.content.length > 50
                            ? '${note.content.substring(0, 50)}...'
                            : note.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(note.locationName ?? 'Unknown location'),
                      trailing: IconButton(
                        icon: Icon(Icons.map),
                        onPressed: () {
                          setState(() {
                            _showList = false;
                          });
                          // Center map on this location
                          _mapController.move(
                            LatLng(note.latitude!, note.longitude!),
                            15.0,
                          );
                          _currentZoom = 15.0;
                        },
                      ),
                      onTap: () => _showNoteDetailsDialog(note),
                    );
                  },
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _zoom,
                        minZoom: 3,
                        maxZoom: 18,
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
                          tileBuilder: (context, widget, tile) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: widget,
                            );
                          },
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
                            heroTag: 'reset_view',
                            onPressed: () {
                              _mapController.move(_center, _zoom);
                              _currentZoom = _zoom;
                            },
                            child: Icon(Icons.fit_screen),
                            tooltip: 'Reset view',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 