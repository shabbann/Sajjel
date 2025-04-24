import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import 'package:flutter/material.dart';
import '../../models/note_model.dart';
class NoteEditorDialog extends StatefulWidget {
  final Note note;
  final Function(String, List<String>, String?) onSave;

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

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note.content);
    _tags = List.from(widget.note.tags);
    _color = widget.note.color;
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