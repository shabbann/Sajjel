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
  final PageController _pageController = PageController();
  bool _isInitialized = false;

  // Pre-rendered screens to avoid rebuilding on tab change
  late List<Widget> _preRenderedScreens = [];
  
  @override
  void initState() {
    super.initState();
    // Set initial chat ID from widget or use default
    _currentChatId = widget.initialChatId ?? 'default';
    
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
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final theme = Theme.of(context);
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _preRenderedScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          _buildNavItem(Icons.list_alt, Icons.list_alt_outlined, 'Chats', 0, theme),
          _buildNavItem(Icons.chat_bubble, Icons.chat_bubble_outline, 'Notes', 1, theme),
          _buildNavItem(Icons.map, Icons.map_outlined, 'Map', 2, theme),
          _buildNavItem(Icons.settings, Icons.settings_outlined, 'Settings', 3, theme),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // Apply theme styles
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
        elevation: theme.bottomNavigationBarTheme.elevation,
        showSelectedLabels: false, // Hide labels for a cleaner look
        showUnselectedLabels: false,
      ),
    );
  }
  
  // Helper to build nav items with glow effect
  BottomNavigationBarItem _buildNavItem(IconData selectedIcon, IconData unselectedIcon, String label, int index, ThemeData theme) {
    final isSelected = _selectedIndex == index;
    final color = isSelected 
        ? theme.bottomNavigationBarTheme.selectedItemColor 
        : theme.bottomNavigationBarTheme.unselectedItemColor;
        
    // Define the even lighter glow effect
    final glowEffect = isSelected ? [
      BoxShadow(
        color: theme.colorScheme.primary.withOpacity(0.08), // Further reduced opacity (from 0.15)
        blurRadius: 6, // Reduced blur (from 8)
        spreadRadius: 0,
      )
    ] : null;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          boxShadow: glowEffect,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: color,
          size: isSelected ? 28 : 24, // Slightly larger when selected
        ),
      ),
      label: label, // Label is needed but hidden
    );
  }
} 