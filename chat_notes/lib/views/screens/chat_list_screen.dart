import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../features/search/global_search_delegate.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_list_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/note_controller.dart';

class ChatListScreen extends StatefulWidget {
  final bool showAppBar;
  final Function(String)? onChatSelected;

  const ChatListScreen({
    Key? key, 
    this.showAppBar = true,
    this.onChatSelected,
  }) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _drawerSearchController = TextEditingController();
  String? _defaultChatId;
  bool _isSearching = false;
  bool _isDrawerSearching = false;
  ThemeMode _currentThemeMode = ThemeMode.system;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    final chatListController = Provider.of<ChatListController>(context, listen: false);
    chatListController.loadChats();
    _searchController.addListener(() => _onSearchChanged());
    _drawerSearchController.addListener(() => _onSearchChanged());
    _loadThemePreference();
    _loadDefaultChat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _drawerSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _isDrawerSearching 
        ? _drawerSearchController.text 
        : _searchController.text;
    });
  }

  Future<void> _loadThemePreference() async {
    final themePreference = await PreferencesService.getThemeMode();
    setState(() {
      _currentThemeMode = themePreference;
    });
  }

  Future<void> _toggleThemeMode() async {
    final newMode = _currentThemeMode == ThemeMode.light 
      ? ThemeMode.dark 
      : ThemeMode.light;
      
    await PreferencesService.saveThemeMode(newMode);
    setState(() {
      _currentThemeMode = newMode;
    });
    
    // Update app theme
    final themeController = Provider.of<ThemeController>(context, listen: false);
    themeController.setThemeMode(newMode);
  }

  Future<void> _loadDefaultChat() async {
    final defaultChat = await PreferencesService.getDefaultChat();
    if (mounted) {
      setState(() {
        _defaultChatId = defaultChat;
      });
    }
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
      appBar: widget.showAppBar ? _buildAppBar() : null,
      drawer: widget.showAppBar ? _buildDrawer() : null,
      body: _buildBody(),
      floatingActionButton: widget.showAppBar ? _buildFloatingActionButton() : null,
    );
  }

  AppBar? _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search chats...',
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
      );
    }
    
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text('Sajjel'),
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sajjel',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your personal notes',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Divider(),
          if (_isDrawerSearching)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _drawerSearchController,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _isDrawerSearching = false;
                        _drawerSearchController.clear();
                      });
                    },
                  ),
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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final noteController = Provider.of<NoteController>(context);
    final currentChatId = noteController.currentChatId;
    
    return Consumer<ChatListController>(
      builder: (context, controller, child) {
        List<Chat> chats = controller.chats;
        if (_searchText.isNotEmpty) {
          chats = chats.where((chat) => chat.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
        }
        if (chats.isEmpty) {
          return Center(
            child: Text('No chats yet'),
          );
        }
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final isDefault = chat.id == _defaultChatId;
            final isSelected = chat.id == currentChatId;
            return _buildChatItem(chat, isDefault, isSelected);
          },
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _createNewChat,
      child: Icon(Icons.add),
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

  Future<void> _createNewChat() async {
    final TextEditingController nameController = TextEditingController();
    final controller = Provider.of<ChatListController>(context, listen: false);
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
                await controller.addChat(chat);
                
                // Force UI refresh - Consider more robust state management later
                setState(() {}); 
                
                Navigator.pop(context);
                
                // Show a confirmation 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Chat created: ${chat.name}')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Chat chat, bool isDefault, bool isSelected) {
    final controller = Provider.of<ChatListController>(context, listen: false);
    final theme = Theme.of(context);
    
    // Define the even lighter glow effect
    final glowEffect = isSelected ? [
      BoxShadow(
        color: theme.colorScheme.primary.withOpacity(0.08), // Further reduced opacity (from 0.12)
        blurRadius: 4, // Further reduced blur (from 6)
        spreadRadius: 0,
      )
    ] : null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          // Use theme list tile color for selection
          color: isSelected
              ? theme.listTileTheme.selectedTileColor
              : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected 
              ? theme.colorScheme.primary.withOpacity(0.3) // Slightly less opacity on border
              : theme.colorScheme.outline.withOpacity(0.15), // Slightly less opacity on outline
            width: isSelected ? 1.0 : 0.5, // Make selected border less thick
          ),
          // Apply glow effect or subtle default shadow
          boxShadow: glowEffect ?? [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.02),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
          borderRadius: BorderRadius.circular(theme.listTileTheme.shape is RoundedRectangleBorder 
            ? ((theme.listTileTheme.shape as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x // Use theme radius
            : 12.0
          ), // Use theme radius
        ),
        child: ListTile(
          selected: isSelected,
          shape: theme.listTileTheme.shape, // Use theme shape
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
              style: TextStyle(color: theme.colorScheme.onPrimary),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chat.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDefault)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.star_rounded,
                    color: theme.colorScheme.outline, // Use outline grey for star
                    size: 18,
                  ),
                ),
            ],
          ),
          subtitle: Text(
            'Created: ${chat.createdAt.toString().substring(0, 10)}',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.outline),
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
                        child: Text('Cancel')
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ) ?? false;

                if (shouldDelete) {
                  await controller.deleteChat(chat.id);
                  if (isDefault) {
                    await PreferencesService.saveDefaultChat(null);
                  }
                  final noteController = Provider.of<NoteController>(context, listen: false);
                  if (noteController.currentChatId == chat.id) {
                     noteController.setCurrentChat(''); 
                  }
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
                    isDefault ? Icons.star_border_rounded : Icons.star_rounded,
                    color: isDefault ? theme.colorScheme.outline : theme.colorScheme.secondary, // Use outline for remove
                  ),
                  title: Text(isDefault ? 'Remove Default' : 'Set as Default'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          onTap: () {
            _onChatTap(chat.id, chat.name);
          },
        ),
      ),
    );
  }

  void _onChatTap(String chatId, String chatName) {
    PreferencesService.saveLastOpenedChat(chatId);
    
    Provider.of<NoteController>(context, listen: false).setCurrentChat(chatId);

    if (widget.onChatSelected != null) {
      widget.onChatSelected!(chatId);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId),
        ),
      );
    }
  }
}