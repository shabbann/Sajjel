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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteController>().setCurrentChat(widget.chatId);
      _loadChats();
      _loadCurrentChatName();
      // Save this as the last opened chat
      PreferencesService.saveLastOpenedChat(widget.chatId);
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
      final chats = await _databaseService.getChats();
      final currentChat = chats.firstWhere((chat) => chat.id == widget.chatId);
      setState(() {
        _currentChatName = currentChat.name;
      });
    } catch (e) {
      print('Error loading current chat name: $e');
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

  void _handleSubmitted(String text, List<String> tags, String? color, double? latitude, double? longitude, String? locationName) {
    if (text.isEmpty) return;
    
    final trimmedText = text.trim();
    if (trimmedText.isNotEmpty) {
      Provider.of<NoteController>(context, listen: false).addNote(
        trimmedText, 
        true, 
        tags: tags,
        color: color,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );
      _textController.clear();
      _scrollToBottom();
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Tags',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: tags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
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
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filters active',
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
            onSubmitted: _handleSubmitted,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        tooltip: 'New Chat',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sajjel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Smart Notes with Location',
                  style: TextStyle(
                    color: Colors.white70,
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
                ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Search All Notes'),
                  onTap: () {
                    Navigator.pop(context);
                    _showGlobalSearch();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.note_alt_outlined),
                  title: Text('All Chats'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatListScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.map),
                  title: Text('Location Map'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationMapScreen(
                          notes: Provider.of<NoteController>(context, listen: false).notes.cast<Note>(),
                          title: 'Location Map',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.tag),
                  title: Text('Filter by Tags'),
                  onTap: () {
                    Navigator.pop(context);
                    _showTagFilter();
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                ),
                Consumer<ThemeController>(
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '© 2023 Sajjel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}