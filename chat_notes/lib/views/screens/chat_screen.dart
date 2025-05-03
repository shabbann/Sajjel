import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String _currentChatName = 'Sajjel';
  List<String> _selectedTags = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    
    // Set the current chat ID immediately
    context.read<NoteController>().setCurrentChat(widget.chatId);
    
    // Save as last opened chat (this is a lightweight operation)
    PreferencesService.saveLastOpenedChat(widget.chatId);
    
    // Defer heavier operations with different delays to avoid UI jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Stage 1: Most critical operations for the UI
      _loadCurrentChatName(); // Load name first for the app bar
      
      // Stage 2: Less critical operations with a slight delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _loadChats();
      });
    });
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
      
      // Fix database connection first
      _databaseService.closeAndReopen().then((_) {
        final noteController = Provider.of<NoteController>(context, listen: false);
        
        // Ensure we have the right chat ID
        noteController.setCurrentChat(widget.chatId);
        
        // Add the note
        noteController.addNote(
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
        _scrollToBottom();
        
        debugPrint('Note added successfully');
      }).catchError((error) {
        debugPrint('Error reconnecting to database: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $error')),
        );
      });
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
    final tags = await _databaseService.getAllTags(widget.chatId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                    onPressed: () {
                      setState(() {
                        _selectedTags = [];
                      });
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select tags to filter your notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 16),
            tags.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                            'No tags found',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add tags to your notes to filter them here',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: tags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#$tag',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected ? FontWeight.bold : null,
                                    ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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
                  _selectedTags.isEmpty ? 'Close' : 'Apply Filters (${_selectedTags.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
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
                  await ChatActions.renameChatDialog(
                    context,
                    widget.chatId,
                    _currentChatName,
                    () {
                      _loadCurrentChatName();
                    },
                  );
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
                      builder: (context) => LocationMapScreen(
                        notes: Provider.of<NoteController>(context, listen: false).notes.cast<Note>(),
                        title: 'Chat Locations',
                      ),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Rename Chat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('Export Chat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'map',
                child: Row(
                  children: [
                    Icon(Icons.map, size: 20),
                    SizedBox(width: 8),
                    Text('View on Map'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child: Consumer<NoteController>(
              builder: (context, controller, child) {
                final notes = _selectedTags.isEmpty
                    ? controller.notes
                    : controller.notes.where((note) {
                        return note.tags.any((tag) => _selectedTags.contains(tag));
                      }).toList();
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (controller.hasNewNote) {
                    _scrollToBottom();
                    controller.resetNewNoteFlag();
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ChatBubble(
                      note: note,
                      onDeleted: () {
                        controller.deleteNote(note.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
          ChatInput(
            textController: _textController,
            chatId: widget.chatId,
          ),
        ],
      ),
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
                    notes: Provider.of<NoteController>(context, listen: false).notes.cast<Note>(),
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
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}