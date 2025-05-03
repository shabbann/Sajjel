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
          _availableTags = tags..sort();
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
      setState(() {
        _currentLocation = null;
        _locationName = null;
      });
    } else {
      setState(() { _isGettingLocation = true; });
      try {
        final position = await LocationService.getCurrentLocation();
        final name = await LocationService.getLocationAddress();
        if (mounted) {
          setState(() {
            _currentLocation = position;
            _locationName = name;
             _isGettingLocation = false;
          });
        }
      } catch (e) {
         HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() { _isGettingLocation = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to get location: $e'), behavior: SnackBarBehavior.floating),
          );
        }
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
      child: Wrap(
        spacing: 6.0,
        runSpacing: 4.0,
        children: _availableTags.map((tag) {
          final isSelected = _selectedTags.contains(tag);
          return ChoiceChip(
            label: Text(tag),
            selected: isSelected,
            onSelected: (_) => _onTagSelected(tag),
             labelStyle: TextStyle(
               color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
               fontSize: 12,
             ),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.chipTheme.backgroundColor,
            shape: theme.chipTheme.shape,
            side: theme.chipTheme.side ?? BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }
}
