import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import './chat_list_screen.dart';
import './chat_screen.dart';
import './settings_screen.dart';
import './map_screen.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_list_controller.dart';
import '../../controllers/note_controller.dart';
import '../screens/map_launcher.dart'; // Import map launcher

class HomeScreen extends StatefulWidget {
  final String? initialChatId;

  const HomeScreen({Key? key, this.initialChatId}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  String _currentChatId = 'default';
  late PageController _pageController;
  bool _isInitialized = false;
  bool _swipeEnabled = true;

  // Pre-rendered screens to avoid rebuilding on tab change
  late List<Widget> _preRenderedScreens = [];
  
  @override
  void initState() {
    super.initState();
    
    // Determine the initial chat and index
    _currentChatId = widget.initialChatId ?? 'default';
    if (_currentChatId != 'default') {
      _selectedIndex = 1; // Start on the ChatScreen page if initialChatId is valid
    }
    
    // Initialize PageController using the determined _selectedIndex
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Delay initialization slightly to allow the build context to be available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Set the current chat in the note controller
      final noteController = Provider.of<NoteController>(context, listen: false);
      noteController.setCurrentChat(_currentChatId);
      
      // Initialize chat list if needed
      final chatListController = Provider.of<ChatListController>(context, listen: false);
      if (chatListController.chats.isEmpty) {
        await chatListController.loadChats();
      }
      
      // If we have a valid chat ID, save it as the last opened
      if (_currentChatId != 'default') {
        await PreferencesService.saveLastOpenedChat(_currentChatId);
      }
      
      // Build initial screens
      _buildPreRenderedScreens(); 
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing HomeScreen: $e');
      // Show an error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing app: $e')),
        );
      }
    }
  }
  
  void _buildPreRenderedScreens() {
    _preRenderedScreens = [
      // Chat list screen (always uses the same instance)
      ChatListScreen(
        // No longer pass initialChatId, it uses NoteController
        showAppBar: true,
        onChatSelected: (chatId) {
          setState(() {
            _currentChatId = chatId;
            _selectedIndex = 1; // Switch to chat view
            _buildPreRenderedScreens(); // Rebuild screens to update chat screen
          });
          
          // Set the current chat in the note controller (already done in ChatListScreen)
          // final noteController = Provider.of<NoteController>(context, listen: false);
          // noteController.setCurrentChat(chatId); 
          
          // Navigate to chat page
          _pageController.jumpToPage(1);
        },
      ),
      
      // Chat screen (rebuilt with the new _currentChatId)
      ChatScreen(chatId: _currentChatId),
      
      // Map screen (preloaded)
      const MapScreen(),
      
      // Settings screen (preloaded)
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Use a smoother animation
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _createNewChat() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  
    try {
      final TextEditingController nameController = TextEditingController();
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'New Chat', 
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter chat name',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              autofocus: true,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.white : Colors.black,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Create'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
              width: 1,
            ),
          ),
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
        ),
      );
      
      if (result == true && nameController.text.trim().isNotEmpty) {
        // Generate a unique chat ID
        final chatId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
        
        // Create the chat object
        final chat = Chat(
          id: chatId,
          name: nameController.text.trim(),
          createdAt: DateTime.now(),
        );
        
        // Save the chat
        await _databaseService.insertChat(chat);
        
        // Reload the chat list
        final chatListController = Provider.of<ChatListController>(context, listen: false);
        await chatListController.loadChats();
        
        // Update the current chat and switch to the chat tab
        setState(() {
          _currentChatId = chatId;
          _selectedIndex = 1; // Switch to chat tab
          
          // Rebuild screens to update chat screen instance
          _buildPreRenderedScreens();
        });
        
        // Navigate to the new chat
        _pageController.animateToPage(
          1, // Chat tab index
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        
        // Set the current chat in the note controller
        final noteController = Provider.of<NoteController>(context, listen: false);
        noteController.setCurrentChat(chatId);
        
        // Save as last opened chat
        await PreferencesService.saveLastOpenedChat(chatId);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat "${chat.name}" created')),
        );
      }
    } catch (e) {
      debugPrint('Error creating new chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isInitialized
          ? PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              physics: _swipeEnabled
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              children: _preRenderedScreens,
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _isInitialized
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_outlined),
                  activeIcon: Icon(Icons.chat),
                  label: 'Current',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map),
                  label: 'Map',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            )
          : null,
      floatingActionButton: _isInitialized && _selectedIndex == 2 // Show only on map tab (index 2)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapLauncherScreen()),
                );
              },
              tooltip: 'Map Testing',
              child: const Icon(Icons.map_outlined),
            )
          : _isInitialized && _selectedIndex == 0 // Show FAB for creating chat on chats tab
              ? FloatingActionButton(
                  onPressed: _createNewChat,
                  tooltip: 'New Chat',
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
} 