import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../features/search/global_search_delegate.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  final String? initialChatId;

  const ChatListScreen({Key? key, this.initialChatId}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _drawerSearchController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  String? _defaultChatId;
  bool _isSearching = false;
  bool _isDrawerSearching = false;
  ThemeMode _currentThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadDefaultChat();
    _searchController.addListener(_filterChats);
    _drawerSearchController.addListener(_filterChats);
    _loadThemePreference();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _drawerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadThemePreference() async {
    final themePreference = await PreferencesService.getThemeMode();
    setState(() {
      _currentThemeMode = themePreference;
    });
  }

  Future<void> _toggleThemeMode() async {
    ThemeMode newMode;
    if (_currentThemeMode == ThemeMode.light) {
      newMode = ThemeMode.dark;
    } else if (_currentThemeMode == ThemeMode.dark) {
      newMode = ThemeMode.system;
    } else {
      newMode = ThemeMode.light;
    }
    
    await PreferencesService.saveThemeMode(newMode);
    setState(() {
      _currentThemeMode = newMode;
    });
    
    // Update app theme
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    themeNotifier.setThemeMode(newMode);
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

  void _filterChats([String? query]) {
    final searchText = query ?? (_isDrawerSearching 
        ? _drawerSearchController.text 
        : _searchController.text);
        
    setState(() {
      if (searchText.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats
            .where((chat) => chat.name.toLowerCase().contains(searchText.toLowerCase()))
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
      key: _scaffoldKey,
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
              leading: IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
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
              ],
            ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.chat,
                            size: 35,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chat Notes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Your personal chat assistant',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (_isDrawerSearching)
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _drawerSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search chats...',
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.search, color: Colors.white70),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                setState(() {
                                  _isDrawerSearching = false;
                                  _drawerSearchController.clear();
                                  _filteredChats = _chats;
                                });
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: TextStyle(color: Colors.white),
                          onChanged: _filterChats,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        icon: Icon(Icons.search),
                        label: Text('Search Chats'),
                        onPressed: () {
                          setState(() {
                            _isDrawerSearching = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.add_circle_outline),
                    title: Text('New Chat'),
                    onTap: () {
                      Navigator.pop(context);
                      _createNewChat();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Global Search'),
                    onTap: () {
                      Navigator.pop(context);
                      _showGlobalSearch();
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.brightness_6),
                    title: Text('Theme: ${_getThemeModeName()}'),
                    onTap: () {
                      _toggleThemeMode();
                      Navigator.pop(context);
                    },
                  ),
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
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('About'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _filteredChats.isEmpty
          ? Center(
              child: _chats.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a new chat to get started',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
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
                
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        chat.name[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                      'Created: ${chat.createdAt.toString().substring(0, 10)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete Chat'),
                              content: Text('Are you sure you want to delete "${chat.name}"? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ) ?? false;

                          if (shouldDelete) {
                            await _databaseService.deleteChat(chat.id);
                            if (isDefault) {
                              await PreferencesService.saveDefaultChat(null);
                            }
                            _loadChats();
                          }
                        } else if (value == 'default') {
                          _setAsDefaultChat(chat.id);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'default',
                          child: ListTile(
                            leading: Icon(
                              isDefault ? Icons.star_border : Icons.star,
                              color: isDefault ? Colors.grey : Colors.amber,
                            ),
                            title: Text(isDefault ? 'Remove Default' : 'Set as Default'),
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete'),
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: chat.id),
                        ),
                      ).then((_) {
                        // Refresh when coming back from chat
                        _loadChats();
                      });
                    },
                  ),
                );
              },
            ),
    );
  }

  String _getThemeModeName() {
    switch (_currentThemeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
      default:
        return 'System';
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Chat Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat Notes is a personal note-taking app in a chat interface.'),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Developed with Flutter'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}