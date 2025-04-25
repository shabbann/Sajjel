import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../features/search/global_search_delegate.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String? initialChatId;

  const ChatListScreen({Key? key, this.initialChatId}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  String? _defaultChatId;
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadDefaultChat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultChat() async {
    final defaultChat = await PreferencesService.getDefaultChat();
    setState(() {
      _defaultChatId = defaultChat;
    });
  }

  Future<void> _loadChats() async {
    final chats = await _databaseService.getChats();
    setState(() {
      _chats = chats;
      _filteredChats = chats;
    });
  }

  void _filterChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats
            .where((chat) => chat.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _createNewChat() async {
    final TextEditingController nameController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Chat'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Enter chat name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
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
                Navigator.pop(context);
                _loadChats();
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsDefaultChat(String chatId) async {
    if (_defaultChatId == chatId) {
      // If this is already the default chat, remove it
      await PreferencesService.saveDefaultChat(null);
      setState(() {
        _defaultChatId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Default chat removed')),
      );
    } else {
      // Otherwise, set it as the default
      await PreferencesService.saveDefaultChat(chatId);
      setState(() {
        _defaultChatId = chatId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Default chat set')),
      );
    }
  }

  void _showGlobalSearch() {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(),
    ).then((chatId) {
      if (chatId != null && chatId.isNotEmpty) {
        Navigator.push(
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
      appBar: _isSearching
          ? AppBar(
              title: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  border: InputBorder.none,
                ),
                onChanged: _filterChats,
                autofocus: true,
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _filteredChats = _chats;
                  });
                },
              ),
            )
          : AppBar(
              title: Row(
                children: [
                  Icon(
                    Icons.note_alt_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text('Sajjel'),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                  tooltip: 'Search chats',
                ),
                IconButton(
                  icon: Icon(Icons.manage_search),
                  onPressed: _showGlobalSearch,
                  tooltip: 'Search across all chats',
                ),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    ).then((_) {
                      // Refresh when coming back from settings
                      _loadDefaultChat();
                    });
                  },
                ),
              ],
            ),
      body: _filteredChats.isEmpty
          ? Center(
              child: _chats.isEmpty
                  ? Text(
                      'No chats yet\nCreate a new chat to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    )
                  : Text(
                      'No matching chats found',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
            )
          : ListView.builder(
              itemCount: _filteredChats.length,
              itemBuilder: (context, index) {
                final chat = _filteredChats[index];
                final isDefault = chat.id == _defaultChatId;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      chat.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(chat.name),
                      if (isDefault)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Created on ${chat.createdAt.day}/${chat.createdAt.month}/${chat.createdAt.year}',
                  ),
                  onTap: () async {
                    // Save this as the last opened chat
                    await PreferencesService.saveLastOpenedChat(chat.id);
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: chat.id),
                      ),
                    );
                  },
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(isDefault ? Icons.star_border : Icons.star),
                            title: Text(isDefault ? 'Remove default chat' : 'Set as default chat'),
                            onTap: () {
                              Navigator.pop(context);
                              _setAsDefaultChat(chat.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}