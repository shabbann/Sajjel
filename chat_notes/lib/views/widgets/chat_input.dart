import 'package:flutter/material.dart';
import 'tag_selector.dart';
import '../../services/location_service.dart';
import '../../services/map_launcher.dart';
import 'package:geolocator/geolocator.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController textController;
  final Function(String, List<String>, String?, double?, double?, String?) onSubmitted;

  const ChatInput({
    super.key,
    required this.textController,
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
  FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableMapProviders();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showTagSelector)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: TagSelector(
              selectedTags: _selectedTags,
              onTagsChanged: (tags) => setState(() => _selectedTags = tags),
              noteColor: _selectedColor,
              onColorChanged: (color) => setState(() => _selectedColor = color),
            ),
          ),
        if (_currentLocation != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? Colors.grey[850] 
                : Colors.blue.withOpacity(0.05),
              border: Border(
                top: BorderSide(
                  color: isDarkMode 
                    ? Colors.grey[700]! 
                    : Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
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
                            Icon(
                              Icons.location_on, 
                              size: 16, 
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationName ?? 'Location attached',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
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
                      icon: Icon(
                        Icons.map, 
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _showMapProviders = !_showMapProviders;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close, 
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                            selectedColor: Theme.of(context).primaryColor.withOpacity(0.7),
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Colors.grey[850] 
                : Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tag,
                  color: _showTagSelector 
                      ? Theme.of(context).primaryColor 
                      : null,
                ),
                onPressed: () => setState(() => _showTagSelector = !_showTagSelector),
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isFocused 
                          ? Theme.of(context).primaryColor.withOpacity(0.5) 
                          : Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: widget.textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isCollapsed: true,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isGettingLocation
                  ? Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(10),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.location_on,
                        color: _currentLocation != null 
                            ? Theme.of(context).primaryColor 
                            : null,
                      ),
                      onPressed: _currentLocation != null ? null : _getLocation,
                    ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.textController.text.trim().isNotEmpty
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).primaryColor.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: widget.textController.text.trim().isNotEmpty
                      ? () {
                          final text = widget.textController.text;
                          if (text.isNotEmpty) {
                            widget.onSubmitted(
                              text,
                              _selectedTags,
                              _selectedColor,
                              _currentLocation?.latitude,
                              _currentLocation?.longitude,
                              _locationName,
                            );
                            setState(() {
                              _selectedTags = [];
                              _selectedColor = null;
                              _currentLocation = null;
                              _locationName = null;
                              _showTagSelector = false;
                              _showMapProviders = false;
                            });
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}