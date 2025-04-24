import 'package:flutter/material.dart';
import '../../models/note_model.dart';

class ChatBubble extends StatelessWidget {
  final Note note;

  const ChatBubble({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: note.isUserNote ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: note.color != null 
              ? Color(int.parse('0xff${note.color!}'))
              : (note.isUserNote ? Colors.blue.shade100 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.content),
            const SizedBox(height: 4),
            Text(
              '${note.timestamp.hour}:${note.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}