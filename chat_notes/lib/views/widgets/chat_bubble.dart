import 'dart:async'; // Add missing import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for HapticFeedback
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/note_model.dart';
import '../../controllers/note_controller.dart';
import '../../services/audio_service.dart';
import '../dialogs/note_editor_dialog.dart';
import '../screens/location_map_screen.dart';
import '../../theme/app_theme.dart'; // Import AppTheme
import 'dart:math' as math; // For angle calculation
import 'package:flutter/rendering.dart';

class ChatBubble extends StatefulWidget {
  final Note note;
  final VoidCallback? onDeleted;

  const ChatBubble({super.key, required this.note, this.onDeleted});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  // Cache text color calculation
  static final Map<Color, Color> _textColorCache = {};

  @override
  void initState() {
    super.initState();
    _subscribeToAudioEvents();
  }

  void _subscribeToAudioEvents() {
    // Listen to player state changes
    _playerStateSubscription = _audioService.playbackStateStream.listen((event) {
      if (!mounted) return;
      // Check if the event is for THIS bubble's audio path
      if (event.path == widget.note.audioPath) {
        final state = event.data;
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _currentPosition = Duration.zero; // Reset position on completion for this bubble
          }
        });
      } else {
        // If another audio started playing, ensure this one shows as stopped
        if (_isPlaying) {
          setState(() {
            _isPlaying = false;
            _currentPosition = Duration.zero;
          });
        }
      }
    });

    // Listen to position changes
    _positionSubscription = _audioService.playbackPositionStream.listen((event) {
      if (!mounted) return;
      // Only update position if it's for this bubble's audio
      if (event.path == widget.note.audioPath) {
        setState(() {
          _currentPosition = event.data;
        });
      } else {
        // Reset position if another track is playing/seeking
         if (_currentPosition != Duration.zero) {
           setState(() { _currentPosition = Duration.zero; });
         }
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioService.playbackDurationStream.listen((event) {
       if (!mounted) return;
       // Only update duration if it's for this bubble's audio
       if (event.path == widget.note.audioPath && event.data != null) {
         setState(() {
           _totalDuration = event.data!;
         });
       }
    });
  }
  
  void _showNoteOptions(BuildContext context) {
    final noteController = Provider.of<NoteController>(context, listen: false);
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface, // Use theme surface
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Rounded top
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), // Adjusted padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(theme, Icons.edit_outlined, 'Edit Note', () {
               Navigator.pop(context);
               _showEditDialog(context, noteController);
            }),
            if (widget.note.hasLocation)
              _buildOptionTile(theme, Icons.map_outlined, 'View on Map', () {
                 Navigator.pop(context);
                 _showOnMap(context);
              }),
            if (widget.note.hasAudio)
              _buildOptionTile(theme, Icons.play_circle_outline, 'Play Audio', () {
                 Navigator.pop(context);
                 _playAudio();
              }),
             Divider(indent: 16, endIndent: 16, color: theme.colorScheme.outline.withOpacity(0.5)),
            _buildOptionTile(theme, Icons.delete_outline, 'Delete Note', () async {
               Navigator.pop(context);
               final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text('Are you sure you want to delete this note?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: theme.colorScheme.error))),
                    ],
                  )
                ) ?? false;
                
                if(confirm) {
                  await noteController.deleteNote(widget.note.id);
                  if (widget.onDeleted != null) {
                    widget.onDeleted!();
                  }
                }
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  // Helper for modal sheet options
  Widget _buildOptionTile(ThemeData theme, IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? theme.colorScheme.error : theme.colorScheme.secondary),
      title: Text(title, style: TextStyle(color: isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners for tile
    );
  }

  void _showEditDialog(BuildContext context, NoteController noteController) {
    showDialog(
      context: context,
      builder: (context) => NoteEditorDialog(
        note: widget.note,
        onSave: (content, tags, color, latitude, longitude, locationName) {
          noteController.updateNote(
            widget.note,
            content: content,
            tags: tags,
            color: color,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
          );
        },
      ),
    );
  }

  void _showOnMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationMapScreen(
          notes: [widget.note],
          title: 'Note Location',
        ),
      ),
    );
  }

  Future<void> _playAudio() async {
    if (widget.note.audioPath == null || widget.note.audioPath!.isEmpty) return;

    try {
      // Tell the service to play THIS bubble's audio path
      await _audioService.playAudio(widget.note.audioPath!); 
      
      // State updates are now handled by the stream listeners
      // We might still want an initial duration fetch if the stream hasn't emitted yet
      if (mounted && _totalDuration == Duration.zero) {
        final duration = await _audioService.getDuration(); 
        if (mounted && _audioService.currentlyPlayingPath == widget.note.audioPath) {
           setState(() {
             _totalDuration = duration ?? Duration.zero;
           });
        }
      }

    } catch (e) {
      debugPrint("Error playing audio for path ${widget.note.audioPath}: $e");
      if (mounted) {
        // Ensure UI reflects stop state on error
        setState(() { 
           _isPlaying = false; 
           _currentPosition = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    // Only stop if this bubble's audio is the one currently playing
    if (_audioService.currentlyPlayingPath == widget.note.audioPath) {
      await _audioService.stopPlayback();
    }
    // State updates (setting _isPlaying false) will happen via the stream listener
  }

  void _seekAudio(Duration position) {
     // Only allow seeking if this bubble's audio is the one playing
    if (_audioService.currentlyPlayingPath == widget.note.audioPath) {
       _audioService.seek(position);
    }
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    
    // Check if THIS bubble's audio was the one playing before disposing
    if (_audioService.currentlyPlayingPath == widget.note.audioPath) {
       _audioService.stopPlayback();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isUser = widget.note.isUserNote;
    final bool isLightMode = theme.brightness == Brightness.light;
    
    // Determine bubble background color based on theme mode & user
    final Color bubbleBgColor;
    final Color textColor;
    final Border? bubbleBorder = null; // No border for this approach
    final List<BoxShadow>? bubbleShadow = [ // Keep subtle shadow
       BoxShadow(
         color: theme.colorScheme.shadow.withOpacity(isLightMode ? 0.08 : 0.05),
         blurRadius: isLightMode ? 5 : 4,
         offset: const Offset(0, 1),
       )
    ];

    if (isLightMode) {
      bubbleBgColor = isUser 
        ? theme.colorScheme.surfaceContainerHighest // Slightly darker surface for user
        : theme.colorScheme.surfaceContainer;     // Elevated surface for other
      textColor = theme.colorScheme.onSurface; 
    } else { // Dark Mode
      bubbleBgColor = isUser 
        ? theme.colorScheme.primaryContainer 
        : theme.colorScheme.surfaceVariant;
      textColor = isUser 
        ? theme.colorScheme.onPrimaryContainer 
        : theme.colorScheme.onSurfaceVariant;
    }
    
    final timestampText = '${widget.note.timestamp.hour}:${widget.note.timestamp.minute.toString().padLeft(2, '0')}';
    final hasContent = widget.note.content.trim().isNotEmpty;
    final hasAudio = widget.note.hasAudio;
    final hasTags = widget.note.tags.isNotEmpty;
    final hasLocation = widget.note.hasLocation;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showNoteOptions(context),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: bubbleBgColor, 
            border: bubbleBorder, 
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: bubbleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Content Text (if any)
              if (hasContent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    widget.note.content,
                    style: TextStyle(color: textColor, fontSize: 15), 
                  ),
                ),
              
              // Audio Player (if any)
              if (hasAudio)
                 Padding(
                    padding: EdgeInsets.only(top: hasContent ? 4 : 0, bottom: 4),
                    child: _buildAudioPlayer(theme, textColor), // Pass correct text color
                 ),
              
              // Tags (if any)
              if (hasTags)
                Padding(
                  padding: EdgeInsets.only(top: hasAudio || hasContent ? 6.0 : 0),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widget.note.tags.map((tag) {
                      // --- Unified Tag Styling ---
                      final Color chipBackgroundColor = _getTagColor(tag, theme);
                      final Color chipTextColor = _getTagTextColor(chipBackgroundColor, theme);
                      final BorderSide chipBorderSide = BorderSide.none; // Generally avoid borders with colored chips
                        
                      return InkWell(
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove Tag'),
                              content: Text('Remove #$tag from this note?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    final updatedTags = List<String>.from(widget.note.tags)..remove(tag);
                                    final noteController = Provider.of<NoteController>(context, listen: false);
                                    noteController.updateNote(widget.note, tags: updatedTags);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tag #$tag removed')));
                                  },
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8), 
                        child: Chip(
                           label: Text('#$tag'),
                           labelStyle: TextStyle(
                             fontSize: 11,
                             color: chipTextColor, 
                           ),
                           backgroundColor: chipBackgroundColor, 
                           side: chipBorderSide, // Apply calculated border (now none)
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                           visualDensity: VisualDensity.compact,
                         ),
                      );
                    }).toList(),
                  ),
                ),
              
              // Meta Row (Location and Timestamp)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Location Indicator (if any)
                    if (hasLocation)
                      GestureDetector(
                        onTap: () => _showOnMap(context),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: textColor.withOpacity(0.7), 
                          ),
                        ),
                      ),
                    
                    // Timestamp
                    Text(
                      timestampText,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7), 
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Audio Player Widget
  Widget _buildAudioPlayer(ThemeData theme, Color iconColor) {
    // Ensure max value is not less than value
    final currentMillis = _currentPosition.inMilliseconds.toDouble();
    final totalMillis = _totalDuration.inMilliseconds.toDouble();
    final sliderValue = math.min(currentMillis, totalMillis);
    final maxSliderValue = totalMillis > 0 ? totalMillis : 1.0; // Avoid max <= 0

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          color: iconColor,
          iconSize: 28,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: _isPlaying ? _stopAudio : _playAudio,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              activeTrackColor: iconColor, // Use icon/text color for track
              inactiveTrackColor: iconColor.withOpacity(0.3),
              thumbColor: iconColor,
              overlayColor: iconColor.withOpacity(0.2),
            ),
            child: Slider(
              value: sliderValue.isNaN || sliderValue.isInfinite ? 0.0 : sliderValue, // Sanitize value
              min: 0.0,
              max: maxSliderValue.isNaN || maxSliderValue.isInfinite ? 1.0 : maxSliderValue, // Sanitize max
              onChanged: (value) {
                _seekAudio(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_totalDuration > Duration.zero ? _totalDuration : _currentPosition), // Show total or current
          style: TextStyle(fontSize: 11, color: iconColor.withOpacity(0.7)),
        ),
      ],
    );
  }
  
  // Helper to format duration (e.g., 0:34, 1:23)
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  // Optimized with caching for common colors (kept for potential note color feature)
  Color _getTextColorForBackground(Color backgroundColor) {
    if (_textColorCache.containsKey(backgroundColor)) {
      return _textColorCache[backgroundColor]!;
    }
    
    final luminance = backgroundColor.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black : Colors.white;
    _textColorCache[backgroundColor] = textColor;
    return textColor;
  }

  // --- Tag Color Helpers (can be moved to a common place later) ---

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
    // Use a simple hash to pick a color from the palette
    final hashCode = tag.hashCode;
    final color = _tagAccentColors[hashCode.abs() % _tagAccentColors.length];
    return color;
  }

  Color _getTagTextColor(Color backgroundColor, ThemeData theme) {
    // Use ThemeData standard for contrast
    return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}