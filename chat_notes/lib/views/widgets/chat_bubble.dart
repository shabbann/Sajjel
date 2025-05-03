import 'dart:async'; // Add missing import
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/note_model.dart';
import '../../controllers/note_controller.dart';
import '../../services/audio_service.dart';
import '../dialogs/note_editor_dialog.dart';
import '../screens/location_map_screen.dart';
import '../../theme/app_theme.dart'; // Import AppTheme
import 'dart:math' as math; // For angle calculation

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
    // Listen to audio player state changes
    _playerStateSubscription = _audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _currentPosition = Duration.zero; // Reset position on completion
          }
        });
      }
    });

    // Listen to position changes
    _positionSubscription = _audioService.playbackPositionStream.listen((position) { // Use playbackPositionStream
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioService.playbackDurationStream.listen((duration) { // Use playbackDurationStream
       if (mounted && duration != null) {
        setState(() {
          // Correct type: Duration? to Duration
          _totalDuration = duration; 
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
      // Use the correct AudioService method
      await _audioService.playAudio(widget.note.audioPath!); 
      
      // Initial state might be set via listeners now, but we can still set isPlaying
      if (mounted) {
        // Use getDuration from AudioService
        final duration = await _audioService.getDuration(); 
        setState(() {
          _isPlaying = true;
          _totalDuration = duration ?? Duration.zero;
        });
      }

    } catch (e) {
      debugPrint("Error playing audio: $e");
      if (mounted) {
        setState(() { _isPlaying = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    await _audioService.stopPlayback();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    }
  }

  void _seekAudio(Duration position) {
    // Use the correct AudioService method
    _audioService.seek(position);
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    
    // Stop playback if this bubble was playing
    if (_isPlaying) {
       _audioService.stopPlayback();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isUser = widget.note.isUserNote;
    
    // Determine bubble background color from theme
    final bubbleColor = isUser 
        ? theme.colorScheme.primaryContainer // Use primary container for user
        : theme.colorScheme.surfaceVariant; // Use surface variant for others
            
    // Determine text color based on bubble background
    final textColor = isUser 
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    
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
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max width
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only( // Modern chat bubble corners
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ]
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
                    style: TextStyle(color: textColor, fontSize: 15), // Slightly larger font
                  ),
                ),
              
              // Audio Player (if any)
              if (hasAudio)
                 Padding(
                    padding: EdgeInsets.only(top: hasContent ? 4 : 0, bottom: 4),
                    child: _buildAudioPlayer(theme, textColor),
                 ),
              
              // Tags (if any)
              if (hasTags)
                Padding(
                  padding: EdgeInsets.only(top: hasAudio || hasContent ? 6.0 : 0), // Adjust top padding
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widget.note.tags.map((tag) {
                      return Chip(
                         label: Text(tag),
                         labelStyle: TextStyle(
                           fontSize: 11,
                           color: textColor.withOpacity(0.9), // Use text color variant
                         ),
                         backgroundColor: bubbleColor.withOpacity(0.8), // Use bubble color variant
                         side: BorderSide.none,
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                         visualDensity: VisualDensity.compact,
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
}