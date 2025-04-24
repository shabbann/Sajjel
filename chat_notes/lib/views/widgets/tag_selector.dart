import 'package:flutter/material.dart';

class TagSelector extends StatefulWidget {
  final List<String> selectedTags;
  final Function(List<String>) onTagsChanged;
  final String? noteColor;
  final Function(String?)? onColorChanged;

  const TagSelector({
    Key? key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.noteColor,
    this.onColorChanged,
  }) : super(key: key);

  @override
  _TagSelectorState createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  final TextEditingController _tagController = TextEditingController();
  final List<Color> _availableColors = [
    Colors.grey.shade200,
    Colors.red.shade100,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.yellow.shade100,
    Colors.purple.shade100,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onColorChanged != null)
            Container(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableColors.length,
                itemBuilder: (context, index) {
                  final color = _availableColors[index];
                  final isSelected = widget.noteColor == color.value.toRadixString(16);
                  return GestureDetector(
                    onTap: () {
                      widget.onColorChanged!(
                        color.value.toRadixString(16),
                      );
                    },
                    child: Container(
                      width: 40,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: 'Add tag...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      final newTags = List<String>.from(widget.selectedTags);
                      newTags.add(value.trim());
                      widget.onTagsChanged(newTags);
                      _tagController.clear();
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  if (_tagController.text.trim().isNotEmpty) {
                    final newTags = List<String>.from(widget.selectedTags);
                    newTags.add(_tagController.text.trim());
                    widget.onTagsChanged(newTags);
                    _tagController.clear();
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.selectedTags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: Icon(Icons.close, size: 18),
                onDeleted: () {
                  final newTags = List<String>.from(widget.selectedTags);
                  newTags.remove(tag);
                  widget.onTagsChanged(newTags);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }
}