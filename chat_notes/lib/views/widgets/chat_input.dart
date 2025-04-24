import 'package:flutter/material.dart';
import 'tag_selector.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String, List<String>, String?) onSubmitted;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  List<String> _selectedTags = [];
  String? _selectedColor;
  bool _showTagSelector = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showTagSelector)
          TagSelector(
            selectedTags: _selectedTags,
            onTagsChanged: (tags) => setState(() => _selectedTags = tags),
            noteColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.tag),
                onPressed: () => setState(() => _showTagSelector = !_showTagSelector),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (text) {
                    widget.onSubmitted(text, _selectedTags, _selectedColor);
                    setState(() {
                      _selectedTags = [];
                      _selectedColor = null;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (widget.controller.text.isNotEmpty) {
                    widget.onSubmitted(
                      widget.controller.text,
                      _selectedTags,
                      _selectedColor,
                    );
                    widget.controller.clear();
                    setState(() {
                      _selectedTags = [];
                      _selectedColor = null;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}