import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import '../../../services/location_service.dart';
import '../screens/location_map_screen.dart';
import 'package:geolocator/geolocator.dart';

class NoteEditorDialog extends StatefulWidget {
  final Note note;
  final Function(String, List<String>, String?, double?, double?, String?) onSave;

  const NoteEditorDialog({
    Key? key,
    required this.note,
    required this.onSave,
  }) : super(key: key);

  @override
  _NoteEditorDialogState createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late TextEditingController _contentController;
  late List<String> _tags;
  late String? _color;
  late double? _latitude;
  late double? _longitude;
  late String? _locationName;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note.content);
    _tags = List.from(widget.note.tags);
    _color = widget.note.color;
    _latitude = widget.note.latitude;
    _longitude = widget.note.longitude;
    _locationName = widget.note.locationName;
  }

  Future<void> _getLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getLocationAddress();
      
      setState(() {
        _latitude = position?.latitude;
        _longitude = position?.longitude;
        _locationName = address;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  void _clearLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
  }

  void _openLocationOnMap() {
    if (_latitude == null || _longitude == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationMapScreen(
          notes: [
            Note(
              id: widget.note.id,
              content: _contentController.text,
              timestamp: widget.note.timestamp,
              isUserNote: widget.note.isUserNote,
              chatId: widget.note.chatId,
              tags: _tags,
              color: _color,
              latitude: _latitude,
              longitude: _longitude,
              locationName: _locationName,
            ),
          ],
          title: 'Note Location',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter note content',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Location section
            if (LocationService.isLocationSupported)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_latitude != null && _longitude != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationName ?? 'Location attached',
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: _clearLocation,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: _isGettingLocation 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.my_location, size: 16),
                        label: Text(_latitude != null ? 'Update Location' : 'Add Location'),
                        onPressed: _isGettingLocation ? null : _getLocation,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      if (_latitude != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.map, size: 16),
                            label: Text('View on Map'),
                            onPressed: _openLocationOnMap,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            // Add tag and color editing widgets here
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(
              _contentController.text,
              _tags,
              _color,
              _latitude,
              _longitude,
              _locationName,
            );
            Navigator.pop(context);
          },
          child: Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}