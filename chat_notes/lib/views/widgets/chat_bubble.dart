import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/note_model.dart';
import '../../controllers/note_controller.dart';
import '../../services/audio_service.dart';
import '../dialogs/note_editor_dialog.dart';
import '../screens/location_map_screen.dart';

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

  // Implement a cached color calculation for common background colors
  static final Map<Color, Color> _textColorCache = {};
  
  void _showNoteOptions(BuildContext context) {
    final noteController = Provider.of<NoteController>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Note'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, noteController);
              },
            ),
            if (widget.note.hasLocation)
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('View on Map'),
                onTap: () {
                  Navigator.pop(context);
                  _showOnMap(context);
                },
              ),
            if (widget.note.hasAudio)
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Play Audio'),
                onTap: () {
                  Navigator.pop(context);
                  _playAudio();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await noteController.deleteNote(widget.note.id);
                if (widget.onDeleted != null) {
                  widget.onDeleted!();
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
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
    if (widget.note.hasAudio) {
      setState(() {
        _isPlaying = true;
      });
      
      try {
        await _audioService.playAudio(widget.note.audioPath!);
        
        // Listen for when playback completes
        _audioService.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
              });
            }
          }
        });
      } catch (e) {
        setState(() {
          _isPlaying = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing audio: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _audioService.stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate bubble background color
    final bubbleColor = widget.note.color != null 
        ? Color(int.parse('0xff${widget.note.color!}'))
        : (widget.note.isUserNote 
            ? (isDarkMode ? Colors.blue.shade800 : Colors.blue.shade100) 
            : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200));
            
    // Calculate text color based on background
    final textColor = _getTextColorForBackground(bubbleColor);
    
    // Prepare timestamp text
    final timestampText = '${widget.note.timestamp.hour}:${widget.note.timestamp.minute.toString().padLeft(2, '0')}';
    
    // Check if this is a voice-only message
    final isVoiceOnly = widget.note.hasAudio && widget.note.content.trim().isEmpty;
    
    return Align(
      alignment: widget.note.isUserNote ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showNoteOptions(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only show content text if it's not empty
              if (!isVoiceOnly)
                Text(
                  widget.note.content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
              
              // Audio indicator with improved UI for voice-only messages
              if (widget.note.hasAudio)
                GestureDetector(
                  onTap: _playAudio,
                  child: Padding(
                    padding: EdgeInsets.only(top: isVoiceOnly ? 0 : 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.orange.shade900.withOpacity(isVoiceOnly ? 0.2 : 0.3) 
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isVoiceOnly ? 40 : 32,
                            height: isVoiceOnly ? 40 : 32,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.orange.shade800 : Colors.orange.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: isVoiceOnly ? 24 : 20,
                                color: isDarkMode ? Colors.white : Colors.orange.shade800,
                              ),
                              onPressed: _playAudio,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Voice waveform visualization
                          SizedBox(
                            width: 120,
                            height: isVoiceOnly ? 32 : 24,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                15,
                                (index) {
                                  // Create pattern of bars that resembles a waveform
                                  // Center bars are taller, edges are shorter
                                  final position = index / 14; // 0.0 to 1.0
                                  
                                  // Create a more organic wave pattern
                                  double height;
                                  if (index % 3 == 0) {
                                    height = 6 + (1 - (position - 0.5).abs() * 2) * 16;
                                  } else if (index % 3 == 1) {
                                    height = 4 + (1 - (position - 0.5).abs() * 2) * 18;
                                  } else {
                                    height = 8 + (1 - (position - 0.5).abs() * 2) * 14;
                                  }
                                  
                                  // Make waveform taller for voice-only messages
                                  if (isVoiceOnly) {
                                    height *= 1.3;
                                  }
                                  
                                  return Container(
                                    width: 3,
                                    height: height.clamp(4, isVoiceOnly ? 30 : 22),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      color: _isPlaying
                                          ? (isDarkMode ? Colors.orange.shade300 : Colors.orange)
                                          : (isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPlaying ? "Playing..." : "Voice",
                            style: TextStyle(
                              fontSize: isVoiceOnly ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Location indicator
              if (widget.note.hasLocation && widget.note.locationName != null)
                GestureDetector(
                  onTap: () => _showOnMap(context),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on, 
                          size: 12, 
                          color: isDarkMode ? Colors.lightBlue.shade300 : Colors.blue
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.note.locationName!,
                            style: TextStyle(
                              fontSize: 10, 
                              color: isDarkMode ? Colors.lightBlue.shade300 : Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                timestampText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode 
                      ? Colors.grey.shade300 
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to determine appropriate text color based on background
  // Optimized with caching for common colors
  Color _getTextColorForBackground(Color backgroundColor) {
    // Check cache first
    if (_textColorCache.containsKey(backgroundColor)) {
      return _textColorCache[backgroundColor]!;
    }
    
    // Calculate relative luminance of the background color
    final luminance = (0.299 * backgroundColor.red + 
                       0.587 * backgroundColor.green + 
                       0.114 * backgroundColor.blue) / 255;
    
    // Determine text color based on luminance
    final textColor = luminance > 0.5 ? Colors.black : Colors.white;
    
    // Cache the result
    _textColorCache[backgroundColor] = textColor;
    
    return textColor;
  }
}