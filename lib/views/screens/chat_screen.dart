import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for HapticFeedback
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Import flutter_animate
import '../../controllers/note_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/chat_model.dart';
import '../../models/note_model.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../../features/chat_management/chat_actions.dart';
import '../../features/export/chat_export.dart';
import '../../features/search/note_search_delegate.dart';
import '../../features/search/global_search_delegate.dart';

import './settings_screen.dart';
import './location_map_screen.dart';
import './chat_list_screen.dart';
import '../screens/tag_manager_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({Key? key, required this.chatId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();
  List<Chat> _chats = [];
  
  // Directly store notes in state
  List<dynamic> _notes = [];
  bool _isLoading = false;
  
  // Add a key for forcing ListView rebuilds
  int _dbVersion = 0;
  
  String _currentChatName = 'Sajjel';
  List<String> _selectedTags = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    
    // Register as a listener for database changes
    _databaseService.addListener(_onDatabaseChanged);
    _dbVersion = _databaseService.changeVersion;
    
    // Save as last opened chat (this is a lightweight operation)
    PreferencesService.saveLastOpenedChat(widget.chatId);
    
    // Defer heavier operations with different delays to avoid UI jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Stage 1: Most critical operations for the UI
      _loadCurrentChatName(); // Load name first for the app bar
      
      // Load notes directly rather than through controller
      _loadNotes();
      
      // Stage 2: Less critical operations with a slight delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _loadChats();
      });
    });
  }

  // Callback for database changes
  void _onDatabaseChanged() {
    debugPrint('ChatScreen: Database changed notification received');
    setState(() {
      _dbVersion = _databaseService.changeVersion;
    });
    _loadNotes();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _databaseService.getChats();
      setState(() {
        _chats = chats;
      });
    } catch (e) {
      print('Error loading chats: $e');
    }
  }

  Future<void> _loadCurrentChatName() async {
    try {
      // First check if we already have the chats loaded to avoid duplicate database calls
      if (_chats.isNotEmpty) {
        final currentChat = _chats.firstWhere(
          (chat) => chat.id == widget.chatId,
          orElse: () => Chat(id: widget.chatId, name: 'Chat', createdAt: DateTime.now()),
        );
        
        if (mounted) {
          setState(() {
            _currentChatName = currentChat.name;
          });
        }
        return;
      }
      
      // If we don't have chats loaded, load just this chat's name
      final dbService = DatabaseService();
      final chats = await dbService.getChats();
      
      if (!mounted) return;
      
      final currentChat = chats.firstWhere(
        (chat) => chat.id == widget.chatId,
        orElse: () => Chat(id: widget.chatId, name: 'Chat', createdAt: DateTime.now()),
      );
      
      setState(() {
        _currentChatName = currentChat.name;
      });
    } catch (e) {
      // Use a default name in case of error
      if (mounted) {
        setState(() {
          _currentChatName = 'Chat';
        });
      }
      debugPrint('Error loading current chat name: $e');
    }
  }

  Future<void> _loadNotes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final notes = await _databaseService.getNotesByChatId(widget.chatId);
      
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewChat() async {
    final TextEditingController nameController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter chat name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final chat = Chat(
                  id: DateTime.now().toString(),
                  name: nameController.text.trim(),
                  createdAt: DateTime.now(),
                );
                await _databaseService.insertChat(chat);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(chatId: chat.id),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handleSubmitted(String text, List<String> tags, String? color, double? latitude, double? longitude, String? locationName, String? audioPath) {
    try {
      // Handle empty text case but allow audio-only messages
      if (text.isEmpty && audioPath == null) {
        debugPrint('Empty message: no text and no audio');
        return;
      }
      
      final trimmedText = text.trim();
      debugPrint('Submitting message. Text: ${trimmedText.isNotEmpty ? 'Yes' : 'No'}, Audio: ${audioPath != null ? 'Yes' : 'No'}');
      
      // Add the note directly
      _addNote(
        trimmedText, 
        true, 
        tags: tags,
        color: color,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        audioPath: audioPath,
      );
      
      _textController.clear();
      
    } catch (e) {
      debugPrint('Error submitting message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Export as Text'),
              onTap: () async {
                Navigator.pop(context);
                final exporter = ChatExport();
                try {
                  final path = await exporter.exportChat(widget.chatId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported to: $path')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to export: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(context);
                final exporter = ChatExport();
                try {
                  await exporter.shareChat(widget.chatId, context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to share: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTagFilter() async {
    // Fetch GLOBAL tags instead of chat-specific tags
    List<String> tags = await _databaseService.getAllTagsGlobal();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Tags',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_selectedTags.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear Filters'),
                        onPressed: () {
                          setModalState(() {
                            _selectedTags.clear();
                          });
                          setState(() {
                            _selectedTags.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Select tags to filter notes. Long-press a tag to remove it.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 13,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Tag'),
                      onPressed: () {
                        _showAddTagDialog(context, (newTag) async {
                          await _addNewTag(newTag, setModalState, (updatedTags) {
                            tags = updatedTags;
                          });
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                tags.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tag,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tags found in this chat',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add tags using the button above or within notes.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 12,
                            children: tags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        _selectedTags.remove(tag);
                                      } else {
                                        _selectedTags.add(tag);
                                      }
                                    });
                                    setState(() {});
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Tag'),
                                        content: Text('Permanently remove #$tag from all notes in this chat?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              try {
                                                await _databaseService.removeTagFromChat(widget.chatId, tag);
                                                
                                                setModalState(() {
                                                  tags.remove(tag);
                                                  if (_selectedTags.contains(tag)) {
                                                    _selectedTags.remove(tag);
                                                  }
                                                });
                                                setState(() {});

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Tag #$tag removed'))
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error removing tag: $e'))
                                                );
                                              }
                                            },
                                            child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                         BoxShadow(
                                          color: Theme.of(context).colorScheme.shadow.withOpacity(isSelected ? 0.2 : 0.05),
                                          blurRadius: isSelected ? 4 : 2,
                                          offset: Offset(0, isSelected ? 2 : 1),
                                        ),
                                      ]
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '#$tag',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: 13,
                                                color: isSelected
                                                    ? Theme.of(context).colorScheme.onPrimary
                                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontWeight: isSelected ? FontWeight.w600 : null,
                                              ),
                                        ),
                                        if (isSelected)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6.0),
                                            child: Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, Function(String) onTagAdded) {
    final TextEditingController tagController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Tag'),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: 'Enter tag name',
            prefixText: '# ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (value) {
            final newTag = value.replaceAll('#', '').trim();
            if (newTag.isNotEmpty) {
              Navigator.pop(context);
              onTagAdded(newTag);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
               final newTag = tagController.text.replaceAll('#', '').trim();
               if (newTag.isNotEmpty) {
                 Navigator.pop(context);
                 onTagAdded(newTag);
              }
            },
            child: const Text('Add Tag'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _addNewTag(String tag, StateSetter setModalState, Function(List<String>) updateLocalTags) async {
    tag = tag.replaceAll('#', '').trim();
    if (tag.isEmpty) return;
    
    try {
      await _databaseService.saveTag(widget.chatId, tag);
      
      final updatedTags = await _databaseService.getAllTags(widget.chatId);
      
      setModalState(() {
         updateLocalTags(updatedTags);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag #$tag added'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding tag: $e'))
      );
    }
  }

  void _showGlobalSearch() {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(),
    ).then((chatId) {
      if (chatId != null && chatId.isNotEmpty && chatId != widget.chatId) {
        // Save this as the last opened chat
        PreferencesService.saveLastOpenedChat(chatId);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: chatId),
          ),
        );
      }
    });
  }

  // Custom deleteNote method using direct database call and state update
  Future<void> _deleteNote(Note note) async {
    try {
      await _databaseService.deleteNote(note.id, note.chatId);
      // Always reload from DB after delete
      final notes = await _databaseService.getNotesByChatId(widget.chatId);
      if (mounted) {
        setState(() {
          _notes = notes;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted'))
      );
    } catch (e) {
      debugPrint('Error deleting note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e'))
        );
      }
    }
  }

  // Add note directly
  Future<void> _addNote(String content, bool isUserNote, {
    List<String> tags = const [], 
    String? color,
    double? latitude,
    double? longitude,
    String? locationName,
    String? audioPath
  }) async {
    final note = Note(
      id: DateTime.now().toString(),
      content: content,
      timestamp: DateTime.now(),
      isUserNote: isUserNote,
      chatId: widget.chatId,
      tags: tags,
      color: color,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      audioPath: audioPath,
    );

    try {
      // Insert the note into the database
      await _databaseService.insertNote(note);
      
      // Let the database listener handle the UI update via _loadNotes()
      // Remove the local addition:
      // if (mounted) {
      //   setState(() {
      //     _notes.add(note);
      //   });
      //   _scrollToBottom();
      // }
      
      // Optionally, scroll to bottom optimistically
      if(mounted) {
        _scrollToBottom();
      }
      
    } catch (e) {
      debugPrint('Error adding note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding note: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _currentChatName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedTags.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _showTagFilter,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTags.length == 1
                              ? '1 filter'
                              : '${_selectedTags.length} filters',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Add Filter Button
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            tooltip: 'Filter by Tags',
            onPressed: _showTagFilter, 
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search in this chat',
            onPressed: () {
              showSearch(
                context: context,
                delegate: NoteSearchDelegate(chatId: widget.chatId),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  // ... existing code ...
                  break;
                case 'filter': 
                  _showTagFilter();
                  break;
                case 'export':
                  _showExportOptions();
                  break;
                case 'delete':
                  final shouldDelete = await ChatActions.confirmChatDelete(
                    context,
                    widget.chatId,
                    _currentChatName,
                  );
                  if (shouldDelete && mounted) {
                    final navigator = Navigator.of(context);
                    final chats = await _databaseService.getChats();
                    final remainingChats = chats.where((c) => c.id != widget.chatId).toList();
                    
                    if (remainingChats.isNotEmpty) {
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: remainingChats.first.id),
                        ),
                      );
                    } else {
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    }
                  }
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
                case 'map':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationMapScreen(
                        title: 'Chat Locations',
                      ),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'filter',
                child: Text('Filter by Tag'),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Text('Export Chat'),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // Use a key that changes when database changes to force rebuild
            key: ValueKey('notes_list_${widget.chatId}_v$_dbVersion'),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildNoteList(),
          ),
          ChatInput(
            textController: _textController,
            chatId: widget.chatId,
            onSubmit: _handleSubmitted,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoteList() {
    final filteredNotes = _selectedTags.isEmpty
        ? _notes
        : _notes.where((note) {
            return note.tags.any((tag) => _selectedTags.contains(tag));
          }).toList();
            
    return ListView.builder(
      controller: _scrollController,
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        // Determine slide direction based on isUserNote
        // final double slideBeginX = note.isUserNote ? 0.2 : -0.2; // Animation removed
        return KeyedSubtree(
          key: ValueKey('note_${note.id}'),
          child: ChatBubble(
            note: note,
            onDelete: () => _deleteNote(note),
          )
          // Remove the animation chain
          // .animate()
          // .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          // .slideX(begin: slideBeginX, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
        );
      },
    );
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final noteController = Provider.of<NoteController>(context, listen: false);
    final hasNotes = noteController.notes.isNotEmpty;
    final hasLocations = noteController.notes.any((note) => note.hasLocation);
    final hasTags = noteController.notes.any((note) => note.tags.isNotEmpty);

    // Use const for spacing widgets
    const divider = Divider();
    const sizedBox12 = SizedBox(height: 12);
    const sizedBox4 = SizedBox(height: 4);
    
    return Drawer(
      child: Column(
        children: [
          // Use selective rebuilding for the drawer header
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sajjel',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                sizedBox12,
                Text(
                  'Smart Notes with Location',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Current chat info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Chat',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      sizedBox4,
                      Text(
                        _currentChatName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                divider,
                
                // Action section - Create these widgets with memoization 
                _buildActionSection(hasNotes, hasLocations, hasTags, theme),
                divider,

                // Navigation section - Extract to reduce rebuilds
                _buildNavigationSection(theme),
                divider,
                
                // Settings section
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                // Use a separate builder for theme toggling to prevent rebuilding the whole drawer
                _buildThemeToggle(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '© 2023 Sajjel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Extract action section to a separate method
  Widget _buildActionSection(bool hasNotes, bool hasLocations, bool hasTags, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Search in This Chat'),
          enabled: hasNotes,
          onTap: hasNotes ? () {
            Navigator.pop(context);
            showSearch(
              context: context,
              delegate: NoteSearchDelegate(chatId: widget.chatId),
            );
          } : null,
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Search All Notes'),
          onTap: () {
            Navigator.pop(context);
            _showGlobalSearch();
          },
        ),
        if (hasLocations)
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('View Notes on Map'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationMapScreen(
                    title: '$_currentChatName - Map',
                  ),
                ),
              );
            },
          ),
        if (hasTags)
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('Filter by Tags'),
            onTap: () {
              Navigator.pop(context);
              _showTagFilter();
            },
          ),
      ],
    );
  }
  
  // Extract navigation section to a separate method
  Widget _buildNavigationSection(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.note_alt_outlined),
          title: const Text('All Chats'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatListScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('New Chat'),
          onTap: () {
            Navigator.pop(context);
            _createNewChat();
          },
        ),
        ListTile(
          leading: const Icon(Icons.manage_search),
          title: const Text('Manage Tags'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TagManagerScreen(chatId: widget.chatId),
              ),
            );
          },
        ),
      ],
    );
  }
  
  // Extract theme toggle to prevent rebuilding the entire drawer
  Widget _buildThemeToggle() {
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        return SwitchListTile(
          secondary: Icon(themeController.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          title: Text(themeController.isDarkMode ? 'Dark Mode' : 'Light Mode'),
          value: themeController.isDarkMode,
          onChanged: (value) {
            themeController.toggleTheme();
          },
        );
      }
    );
  }

  @override
  void dispose() {
    // Unregister from database change notifications
    _databaseService.removeListener(_onDatabaseChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}