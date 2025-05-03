import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/note_controller.dart';
import '../../services/database_service.dart';

class TagManagerScreen extends StatefulWidget {
  final String chatId;

  const TagManagerScreen({Key? key, required this.chatId}) : super(key: key);

  @override
  _TagManagerScreenState createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  final TextEditingController _newTagController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  List<String> _tags = [];
  bool _isLoading = true;
  String? _editingTag;
  TextEditingController? _editTagController;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load tags from all chats, not just this one
      final tags = await _databaseService.getAllTagsGlobal();
      setState(() {
        _tags = tags..sort(); // Sort alphabetically
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tags: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addNewTag() {
    final newTag = _newTagController.text.trim();
    if (newTag.isEmpty) return;

    if (_tags.contains(newTag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag "$newTag" already exists')),
      );
      return;
    }

    // Save tag globally
    _databaseService.saveTagGlobal(newTag);

    setState(() {
      _tags.add(newTag);
      _tags.sort(); // Sort alphabetically
      _newTagController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tag "$newTag" added')),
    );
  }

  void _deleteTag(String tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Tag'),
        content: Text('Are you sure you want to delete the tag "$tag"? This will remove it from all notes in all chats.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                // Use optimized batch delete operation
                await _databaseService.batchDeleteTag(tag);
                
                setState(() {
                  _tags.remove(tag);
                  _isLoading = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tag "$tag" deleted from all chats')),
                );
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting tag: $e')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startEditingTag(String tag) {
    setState(() {
      _editingTag = tag;
      _editTagController = TextEditingController(text: tag);
    });
  }

  void _renameTag(String oldTag, String newTag) async {
    if (newTag.isEmpty) {
      setState(() {
        _editingTag = null;
        _editTagController = null;
      });
      return;
    }

    if (oldTag == newTag) {
      setState(() {
        _editingTag = null;
        _editTagController = null;
      });
      return;
    }

    if (_tags.contains(newTag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag "$newTag" already exists')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the optimized batch update operation
      await _databaseService.batchUpdateTag(oldTag, newTag);
      
      // Also save the new tag globally to ensure it persists
      await _databaseService.saveTagGlobal(newTag);
      
      setState(() {
        _tags.remove(oldTag);
        _tags.add(newTag);
        _tags.sort(); // Sort alphabetically
        _editingTag = null;
        _editTagController = null;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag renamed to "$newTag" across all chats')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _editingTag = null;
        _editTagController = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error renaming tag: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Tags'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTags,
            tooltip: 'Refresh tags',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _newTagController.clear();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Add New Tag'),
              content: TextField(
                controller: _newTagController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter tag name',
                  prefixIcon: Icon(Icons.sell),
                ),
                onSubmitted: (_) {
                  _addNewTag();
                  Navigator.pop(context);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addNewTag();
                    Navigator.pop(context);
                  },
                  child: Text('Add'),
                ),
              ],
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add new tag',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                
                // Existing Tags
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'Existing Tags (${_tags.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      if (_tags.isEmpty)
                        TextButton.icon(
                          onPressed: () {
                            _newTagController.text = 'Important';
                            _addNewTag();
                            _newTagController.text = 'Personal';
                            _addNewTag();
                            _newTagController.text = 'Work';
                            _addNewTag();
                            _newTagController.text = 'Todo';
                            _addNewTag();
                          },
                          icon: Icon(Icons.add_circle_outline, size: 16),
                          label: Text('Add Sample Tags'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _tags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tag,
                                size: 64,
                                color: theme.colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tags yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add tags to organize your notes',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            final tag = _tags[index];
                            
                            if (_editingTag == tag) {
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _editTagController,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            prefixIcon: Icon(Icons.edit),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onSubmitted: (value) => _renameTag(tag, value),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.check),
                                        onPressed: () => _renameTag(tag, _editTagController!.text),
                                        color: theme.colorScheme.primary,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close),
                                        onPressed: () {
                                          setState(() {
                                            _editingTag = null;
                                            _editTagController = null;
                                          });
                                        },
                                        color: theme.colorScheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text(
                                    tag[0].toUpperCase(),
                                    style: TextStyle(color: theme.colorScheme.onPrimary),
                                  ),
                                ),
                                title: Text(
                                  '#$tag',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit),
                                      onPressed: () => _startEditingTag(tag),
                                      tooltip: 'Rename tag',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: theme.colorScheme.error),
                                      onPressed: () => _deleteTag(tag),
                                      tooltip: 'Delete tag',
                                    ),
                                  ],
                                ),
                                onLongPress: () => _deleteTag(tag),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _newTagController.dispose();
    _editTagController?.dispose();
    super.dispose();
  }
} 