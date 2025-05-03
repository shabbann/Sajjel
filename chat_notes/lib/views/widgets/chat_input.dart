import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_service.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../screens/tag_manager_screen.dart';
import '../../services/database_service.dart';
import 'package:provider/provider.dart';
import '../../controllers/note_controller.dart';
import '../../theme/app_theme.dart';

// --- Copied Tag Color Helpers (Ideally move to a shared utility) ---

// Palette of modern accent colors
final List<Color> _tagAccentColors = [
  const Color(0xFF38A3A5), // Teal
  const Color(0xFF57CC99), // Mint Green
  const Color(0xFF80ED99), // Bright Green
  const Color(0xFFF4A261), // Sandy Brown
  const Color(0xFFE76F51), // Burnt Sienna
  const Color(0xFF2A9D8F), // Darker Teal
  const Color(0xFF264653), // Dark Blue-Green
  const Color(0xFFE9C46A), // Saffron
];

// Helper function to get a consistent color based on the tag string
Color _getTagColor(String tag, ThemeData theme) {
  final hashCode = tag.hashCode;
  return _tagAccentColors[hashCode.abs() % _tagAccentColors.length];
}

Color _getTagTextColor(Color backgroundColor, ThemeData theme) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
      ? Colors.white
      : Colors.black;
}
// --- End Copied Helpers ---

class ChatInput extends StatefulWidget {
  final TextEditingController textController;
  final String chatId;

  const ChatInput({
    super.key,
    required this.textController,
    required this.chatId,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final AudioService _audioService = AudioService();
  final DatabaseService _databaseService = DatabaseService();
  String? _recordingPath;
  
  // Animation controller for recording pulse effect
  late AnimationController _pulseController;
  
  // Location data
  Position? _currentLocation;
  String? _locationName;
  bool _isGettingLocation = false;
  
  // Tags
  List<String> _selectedTags = [];
  List<String> _availableTags = [];
  bool _showTagSelector = false;
  
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_updateSendButtonState);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _loadTags();
  }

  void _updateSendButtonState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _databaseService.getAllTagsGlobal();
      if (mounted) {
        setState(() {
          _availableTags = List<String>.from(tags)..sort();
        });
      }
    } catch (e) {
      debugPrint("Error loading tags: $e");
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_updateSendButtonState);
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  bool get _canSend => widget.textController.text.trim().isNotEmpty;

  Future<void> _sendMessage() async {
    if (!_canSend && _recordingPath == null) return;

    final text = widget.textController.text.trim();
    final tags = List<String>.from(_selectedTags);
    final lat = _currentLocation?.latitude;
    final lon = _currentLocation?.longitude;
    final locName = _locationName;
    final audioPath = _recordingPath;

    widget.textController.clear();
    setState(() {
      _selectedTags = [];
      _currentLocation = null;
      _locationName = null;
      _recordingPath = null;
      _showTagSelector = false;
    });
    _focusNode.unfocus();

    try {
      final noteController = Provider.of<NoteController>(context, listen: false);
      await noteController.addNote(
        text,
        true,
        tags: tags,
        latitude: lat,
        longitude: lon,
        locationName: locName,
        audioPath: audioPath,
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_audioService.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioService.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission needed'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    final success = await _audioService.startRecording();
    if (success) {
      HapticFeedback.mediumImpact();
      setState(() {
         _showTagSelector = false;
      });
    } else {
       HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start recording'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _stopRecording({bool canceled = false}) async {
    if (!_audioService.isRecording && !canceled) return;

    if (canceled) {
      await _audioService.cancelRecording();
       HapticFeedback.lightImpact();
      setState(() {
        _recordingPath = null;
      });
    } else {
      final path = await _audioService.stopRecording();
       HapticFeedback.mediumImpact();
      if (path != null) {
        setState(() {
          _recordingPath = path;
        });
        if (!_canSend) {
           _sendMessage();
         } else {
            if(mounted) setState(() {});
         }

      } else {
         HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save recording'), behavior: SnackBarBehavior.floating),
          );
        }
        setState(() {
          _recordingPath = null;
        });
      }
    }
  }
  
  Future<void> _attachLocation() async {
     HapticFeedback.lightImpact();
     if (_currentLocation != null) {
       // Detach location
       setState(() {
         _currentLocation = null;
         _locationName = null;
         _isGettingLocation = false; 
       });
       return; // Exit early after detaching
     }
     
     // Attach location
     setState(() { _isGettingLocation = true; });
     
     try {
       // 1. Check if location services are enabled on the device
       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
       if (!serviceEnabled && mounted) {
         setState(() { _isGettingLocation = false; });
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Location services are disabled. Please enable them.'), behavior: SnackBarBehavior.floating),
         );
         return;
       }
       
       // 2. Check and Request Permissions
       bool permissionGranted = await LocationService.checkLocationPermission();
       if (!permissionGranted && mounted) {
         setState(() { _isGettingLocation = false; });
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Location permission denied.'), behavior: SnackBarBehavior.floating),
         );
         return;
       }
       
       // 3. Try getting Last Known Position (Fast)
       Position? position = await Geolocator.getLastKnownPosition();
       bool usedLastKnown = false;
       
       // Check if last known position is valid and recent (e.g., within 5 minutes)
       if (position != null && 
           position.timestamp != null && 
           DateTime.now().difference(position.timestamp!).inMinutes < 5) {
         usedLastKnown = true;
         if (mounted) {
            // Update UI immediately with last known coords
            setState(() {
              _currentLocation = position;
              _locationName = "Updating address..."; // Placeholder
            });
         }
       } else {
         // 4. If no good last known position, get Current Position (Slower)
         position = await Geolocator.getCurrentPosition(
           desiredAccuracy: LocationAccuracy.medium, // Balance speed/accuracy
         );
         if (mounted) {
           setState(() {
             _currentLocation = position;
             _locationName = "Fetching address..."; 
           });
         }
       }

       // Ensure we actually got a position (either last known or current)
       if (position == null) {
         throw Exception("Could not obtain location.");
       }

       // 5. Fetch Address Asynchronously using the obtained position
       try {
          final name = await LocationService.getLocationAddress(); // Assuming this uses _currentLocation or pass position
          if (mounted && _currentLocation?.latitude == position.latitude && _currentLocation?.longitude == position.longitude) {
             setState(() {
               _locationName = name ?? 'Lat: ${position!.latitude.toStringAsFixed(3)}, Lon: ${position!.longitude.toStringAsFixed(3)}';
               _isGettingLocation = false; // Fully done
             });
          }
       } catch (addrErr) {
          debugPrint('Error getting address: $addrErr');
          if (mounted && _currentLocation?.latitude == position.latitude && _currentLocation?.longitude == position.longitude) {
             setState(() {
               _locationName = 'Lat: ${position!.latitude.toStringAsFixed(3)}, Lon: ${position!.longitude.toStringAsFixed(3)}'; 
               _isGettingLocation = false; // Done, even with address error
             });
          }
       }

     } catch (e) {
       // Catch errors from permission checks, service checks, or getting position
       HapticFeedback.heavyImpact();
       if (mounted) {
         setState(() { _isGettingLocation = false; });
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to get location: $e'), behavior: SnackBarBehavior.floating),
         );
       }
     }
   }

  void _toggleTagSelector() {
     HapticFeedback.lightImpact();
    setState(() {
      _showTagSelector = !_showTagSelector;
       if (_showTagSelector) {
         _loadTags();
       }
    });
  }

  void _onTagSelected(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  // Method to show Add Tag dialog
  void _showAddTagDialog() {
    final TextEditingController tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Global Tag'),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: 'Enter tag name',
            prefixText: '# ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (value) {
            final newTag = value.replaceAll('#', '').trim();
            if (newTag.isNotEmpty) {
              Navigator.pop(context);
              _addNewGlobalTag(newTag);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTag = tagController.text.replaceAll('#', '').trim();
              if (newTag.isNotEmpty) {
                Navigator.pop(context);
                _addNewGlobalTag(newTag);
              }
            },
            child: const Text('Add Tag'),
          ),
        ],
      ),
    );
  }

  // Method to add a new global tag
  Future<void> _addNewGlobalTag(String tag) async {
    if (_availableTags.contains(tag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag #$tag already exists'))
      );
      return;
    }
    try {
      await _databaseService.saveTagGlobal(tag);
      await _loadTags(); // Reload tags to include the new one
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag #$tag added globally'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding global tag: $e'))
      );
    }
  }

  // Method to remove a global tag (now handles confirmation)
  Future<void> _confirmAndRemoveGlobalTag(String tag) async {
     // Ask for confirmation before deleting globally
     final confirm = await showDialog<bool>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Delete Global Tag?'),
         content: Text('This will remove #$tag from ALL notes in ALL chats. This action cannot be undone.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
           TextButton(
             onPressed: () => Navigator.pop(context, true),
             child: const Text('Remove Globally', style: TextStyle(color: Colors.red)),
           ),
         ],
       ),
     ) ?? false;

     if (!confirm || !mounted) return; // Check mounted after await

     // If confirmed, proceed with removal and state updates
     try {
        await _databaseService.batchDeleteTag(tag); // Removes tag from all notes
        
        // Update the state directly to remove the tag from the UI
        setState(() {
           _availableTags.remove(tag);
           // Also remove from current selection if present
           if(_selectedTags.contains(tag)) {
              _selectedTags.remove(tag);
           }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tag #$tag removed globally'))
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing global tag: $e'))
        );
      }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showTagSelector) _buildTagSelector(theme),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5), width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                 icon: _isGettingLocation 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
                    : Icon(
                        _currentLocation != null ? Icons.location_on : Icons.location_off_outlined,
                        color: _currentLocation != null ? theme.colorScheme.primary : theme.colorScheme.secondary,
                      ),
                onPressed: _attachLocation,
                tooltip: _currentLocation != null ? (_locationName ?? 'Location Attached') : 'Attach Location',
              ),

              IconButton(
                icon: Icon(
                   _selectedTags.isEmpty ? Icons.label_outline : Icons.label,
                   color: _selectedTags.isEmpty ? theme.colorScheme.secondary : theme.colorScheme.primary,
                ),
                onPressed: _toggleTagSelector,
                tooltip: 'Tags',
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                     color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                     borderRadius: theme.inputDecorationTheme.border is OutlineInputBorder 
                        ? (theme.inputDecorationTheme.border as OutlineInputBorder).borderRadius 
                        : BorderRadius.circular(12.0),
                  ),
                  child: TextField(
                    controller: widget.textController,
                    focusNode: _focusNode,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    keyboardType: TextInputType.multiline,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Enter note...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                      isCollapsed: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),

              _buildSendRecordButton(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSendRecordButton(ThemeData theme) {
    if (_canSend || _recordingPath != null) {
      return IconButton(
        icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
        onPressed: _sendMessage,
        tooltip: 'Send',
      );
    } 
    else if (_audioService.isRecording) {
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           IconButton(
             icon: FadeTransition(
               opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_pulseController),
               child: Icon(Icons.stop_circle_rounded, color: theme.colorScheme.error),
             ),
             onPressed: () => _stopRecording(canceled: false),
             tooltip: 'Stop Recording',
           ),
           IconButton(
             icon: Icon(Icons.cancel_rounded, color: theme.colorScheme.secondary),
             onPressed: () => _stopRecording(canceled: true),
             tooltip: 'Cancel Recording',
           ),
         ],
       );
    }
    else {
      return IconButton(
        icon: Icon(Icons.mic_none_rounded, color: theme.colorScheme.secondary),
        onPressed: _toggleRecording,
        tooltip: 'Record Audio',
      );
    }
  }

  Widget _buildTagSelector(ThemeData theme) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
       decoration: BoxDecoration(
         color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
         border: Border(
           bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5), width: 0.5),
         ),
       ),
       // Make the row scrollable horizontally
       child: SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         // Use a Row to include the Add button
         child: Row(
           children: [
             // Map available tags to chips with unified styling
             ...List<Widget>.from(_availableTags.map((tag) {
               final isSelected = _selectedTags.contains(tag);

               // Use the same color logic as ChatBubble
               final Color chipBackgroundColor = isSelected 
                  ? theme.colorScheme.primary // Keep selected color distinct
                  : _getTagColor(tag, theme); // Use helper for unselected color
               final Color chipTextColor = isSelected
                  ? theme.colorScheme.onPrimary
                  : _getTagTextColor(chipBackgroundColor, theme);
               final BorderSide chipBorderSide = BorderSide.none; // No border

               return Padding(
                 padding: const EdgeInsets.only(right: 6.0),
                 child: InkWell(
                    borderRadius: BorderRadius.circular(16), 
                    onTap: () => _onTagSelected(tag),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      _confirmAndRemoveGlobalTag(tag); 
                    },
                    child: Chip(
                       label: Text('#$tag'),
                       backgroundColor: chipBackgroundColor,
                       labelStyle: TextStyle(
                         color: chipTextColor,
                         fontSize: 12,
                         fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                       ),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       side: chipBorderSide,
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       visualDensity: VisualDensity.compact,
                    ),
                 ),
               );
             })),

             // Add "Add Tag" button
             Padding(
               padding: const EdgeInsets.only(left: 4.0),
               child: ActionChip(
                 avatar: Icon(Icons.add_circle_outline, size: 16, color: theme.colorScheme.secondary),
                 label: const Text('New Tag'),
                 onPressed: _showAddTagDialog,
                 labelStyle: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
                 tooltip: 'Add a new global tag',
                 pressElevation: 2,
                 backgroundColor: theme.chipTheme.backgroundColor,
                 side: theme.chipTheme.side ?? BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
                 shape: theme.chipTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                 visualDensity: VisualDensity.compact,
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
               ),
             ),
           ],
         ),
       ),
    );
  }
}
