import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../controllers/note_controller.dart';
import '../dialogs/note_editor_dialog.dart';
import '../screens/location_map_screen.dart';

class ChatBubble extends StatelessWidget {
  final Note note;

  const ChatBubble({super.key, required this.note});

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
            if (note.hasLocation)
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('View on Map'),
                onTap: () {
                  Navigator.pop(context);
                  _showOnMap(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await noteController.deleteNote(note.id);
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
        note: note,
        onSave: (content, tags, color, latitude, longitude, locationName) {
          noteController.updateNote(
            note,
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
          notes: [note],
          title: 'Note Location',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate bubble background color
    final bubbleColor = note.color != null 
        ? Color(int.parse('0xff${note.color!}'))
        : (note.isUserNote 
            ? (isDarkMode ? Colors.blue.shade800 : Colors.blue.shade100) 
            : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200));
            
    // Calculate text color based on background
    final textColor = _getTextColorForBackground(bubbleColor);
    
    // Prepare timestamp text
    final timestampText = '${note.timestamp.hour}:${note.timestamp.minute.toString().padLeft(2, '0')}';
    
    return Align(
      alignment: note.isUserNote ? Alignment.centerRight : Alignment.centerLeft,
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
              Text(
                note.content,
                style: TextStyle(color: textColor),
              ),
              if (note.hasLocation && note.locationName != null)
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
                            note.locationName!,
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