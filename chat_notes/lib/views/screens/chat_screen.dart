import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/note_controller.dart';
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
      appBar: AppBar(
        title: Text(_currentChatName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showGlobalSearch,
            tooltip: 'Search across all chats',
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              _showMap(context);
            },
            tooltip: 'View location map',
          ),
          IconButton(
            icon: const Icon(Icons.tag),
            onPressed: _showTagFilter,
          ),
          IconButton(
            icon: const Icon(Icons.find_in_page),
            onPressed: () {
              showSearch(
                context: context,
                delegate: NoteSearchDelegate(chatId: widget.chatId),
              );
            },
            tooltip: 'Search in this chat',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _showExportOptions,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final currentChat = _chats.firstWhere((chat) => chat.id == widget.chatId);
              switch (value) {
                case 'rename':
                  ChatActions(context).showChatOptions(
                    currentChat,
                    () async {
                      await _loadChats();
                      await _loadCurrentChatName();
                    },
                  );
                  break;
                case 'delete':
                  final deleted = await ChatActions(context).deleteChat(currentChat);
                  if (deleted && mounted) {
                    await _loadChats();
                    if (_chats.isNotEmpty) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: _chats.first.id),
                        ),
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Rename Chat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: Center(
                child: Text(
                  'Sajjel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.black,
                      child: Text(
                        chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(chat.name),
                    subtitle: const Text('Long press for options'),
                    selected: chat.id == widget.chatId,
                    onTap: () {
                      if (chat.id != widget.chatId) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(chatId: chat.id),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    onLongPress: () {
                      ChatActions(context).showChatOptions(
                        chat,
                        () async {
                          await _loadChats();
                          if (chat.id == widget.chatId) {
                            await _loadCurrentChatName();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context);
                _createNewChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedTags.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: _selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() {
                        _selectedTags.remove(tag);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: Consumer<NoteController>(
              builder: (context, controller, _) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.notes.isEmpty) {
                  return Center(
                    child: Text(
                      'Start writing your notes...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                final filteredNotes = _selectedTags.isEmpty
                    ? controller.notes
                    : controller.notes.where((note) {
                        return note.tags.any((tag) => _selectedTags.contains(tag));
                      }).toList();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    return ChatBubble(note: filteredNotes[index]);
                  },
                );
              },
            ),
          ),
          ChatInput(
            controller: _textController,
            onSubmitted: _handleSubmitted,
          ),
        ],
      ),
      floatingActionButton: Consumer<NoteController>(
        builder: (context, controller, _) {
          final dynamicNotes = controller.notes;
          // Convert from List<dynamic> to List<Note>
          final notes = dynamicNotes.map((noteObj) => noteObj as Note).toList();
          
          // Only show the map button if there are notes with location data
          final hasLocationNotes = notes.any((note) => note.hasLocation);
          
          if (!hasLocationNotes) return const SizedBox.shrink();
          
          return FloatingActionButton(
            onPressed: () => _showMap(context),
            child: const Icon(Icons.map),
            tooltip: 'View All Locations',
          );
        },
      ),
    );
  }

  void _showMap(BuildContext context) {
    final noteController = Provider.of<NoteController>(context, listen: false);
    final dynamicNotes = noteController.notes;
    
    // Convert from List<dynamic> to List<Note>
    final notes = dynamicNotes.map((noteObj) => noteObj as Note).toList();
    
    // Check if there are any notes with location data
    final hasLocationNotes = notes.any((note) => note.hasLocation);
    
    if (!hasLocationNotes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes with location data in this chat')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationMapScreen(
          notes: notes,
          title: 'Locations in $_currentChatName',
        ),
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