import 'package:flutter/material.dart';
import 'tag_selector.dart';
import '../../services/location_service.dart';
import '../../services/map_launcher.dart';
import 'package:geolocator/geolocator.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String, List<String>, String?, double?, double?, String?) onSubmitted;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  List<String> _selectedTags = [];
  String? _selectedColor;
  bool _showTagSelector = false;
  Position? _currentLocation;
  bool _isGettingLocation = false;
  String? _locationName;
  List<MapProvider> _availableMapProviders = [MapProvider.defaultMap];
  MapProvider _selectedMapProvider = MapProvider.defaultMap;
  bool _showMapProviders = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableMapProviders();
  }

  Future<void> _loadAvailableMapProviders() async {
    try {
      final providers = await MapLauncher.getAvailableMaps();
      if (mounted) {
        setState(() {
          _availableMapProviders = providers;
        });
      }
    } catch (e) {
      debugPrint('Error loading map providers: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getLocationAddress();
      
      setState(() {
        _currentLocation = position;
        _locationName = address;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _openCurrentLocationOnMap() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isGettingLocation = true;
    });
    
    try {
      print('Opening map from chat input for: ${_currentLocation!.latitude}, ${_currentLocation!.longitude} using $_selectedMapProvider');
      
      // Use MapLauncher with selected provider
      final success = await MapLauncher.openMap(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        label: _locationName,
        provider: _selectedMapProvider,
      );
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open selected map provider. Falling back to default.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in _openCurrentLocationOnMap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening map: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          _showMapProviders = false;
        });
      }
    }
  }

  String _getMapProviderName(MapProvider provider) {
    switch (provider) {
      case MapProvider.googleMaps:
        return 'Google Maps';
      case MapProvider.osmAnd:
        return 'OsmAnd';
      case MapProvider.waze:
        return 'Waze';
      case MapProvider.mapQuest:
        return 'MapQuest';
      case MapProvider.hereMaps:
        return 'HERE Maps';
      case MapProvider.defaultMap:
        return 'Default Map';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showTagSelector)
          TagSelector(
            selectedTags: _selectedTags,
            onTagsChanged: (tags) => setState(() => _selectedTags = tags),
            noteColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
          ),
        if (_currentLocation != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _openCurrentLocationOnMap,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationName ?? 'Location attached',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _showMapProviders = !_showMapProviders;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _currentLocation = null;
                          _locationName = null;
                          _showMapProviders = false;
                        });
                      },
                    ),
                  ],
                ),
                if (_showMapProviders) 
                  Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _availableMapProviders.map((provider) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(_getMapProviderName(provider)),
                            selected: _selectedMapProvider == provider,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedMapProvider = provider;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.tag),
                onPressed: () => setState(() => _showTagSelector = !_showTagSelector),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (text) {
                    _submitMessage(text);
                  },
                ),
              ),
              if (LocationService.isLocationSupported)
                IconButton(
                  icon: _isGettingLocation 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _currentLocation != null ? Icons.location_on : Icons.location_off,
                        color: _currentLocation != null ? Colors.blue : null,
                      ),
                  onPressed: _isGettingLocation ? null : _getLocation,
                ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (widget.controller.text.isNotEmpty) {
                    _submitMessage(widget.controller.text);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _submitMessage(String text) {
    if (text.isNotEmpty) {
      widget.onSubmitted(
        text,
        _selectedTags,
        _selectedColor,
        _currentLocation?.latitude,
        _currentLocation?.longitude,
        _locationName,
      );
      widget.controller.clear();
      setState(() {
        _selectedTags = [];
        _selectedColor = null;
        _showTagSelector = false;
        // Keep the location data until the user explicitly clears it
        // _currentLocation = null;
        // _locationName = null;
      });
    }
  }
}