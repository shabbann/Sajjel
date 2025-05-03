import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'controllers/note_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/database_service.dart';
import 'services/preferences_service.dart';
import 'models/chat_model.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/chat_list_screen.dart';
import 'views/screens/chat_screen.dart';
import 'theme/app_theme.dart';
import 'controllers/chat_list_controller.dart';

// Global database service to avoid creating multiple instances
final DatabaseService databaseService = DatabaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database and cache
  await databaseService.initDatabase();
  
  // Initialize cache in the background to avoid blocking UI
  Future.microtask(() async {
    await databaseService.initCache();
  });
  
  // Get the last opened chat
  final lastChatId = await PreferencesService.getLastOpenedChat();
  final defaultChatId = await PreferencesService.getDefaultChat();
  
  final chatId = defaultChatId ?? lastChatId ?? 'default_chat_${DateTime.now().millisecondsSinceEpoch}';
  
  // Create an initial chat if no chats exist yet
  await databaseService.createInitialChat(chatId);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteController(databaseService: databaseService)),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => ChatListController()),
      ],
      child: MyApp(initialChatId: chatId),
    ),
  );
}

// Initial app launcher with minimal resources
class AppStarter extends StatefulWidget {
  const AppStarter({super.key});

  @override
  State<AppStarter> createState() => _AppStarterState();
}

class _AppStarterState extends State<AppStarter> {
  bool _isInitialized = false;
  String _initialChatId = '';
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    try {
      // Initialize quick preliminary resources
      await _initializeEssentialResources();
      
      // Show UI immediately
      setState(() {
        _isInitialized = true;
      });
      
      // Then continue loading the rest in the background
      _initializeRemainingResources();
    } catch (e) {
      print('Error during initialization: $e');
    }
  }
  
  Future<void> _initializeEssentialResources() async {
    // Initialize database with minimal work
    await databaseService.initDatabase();
    
    // Get initial chat ID with quick operation
    final defaultChatId = DateTime.now().toString();
    await databaseService.createInitialChat(defaultChatId);
    
    // Check if we have a saved chat to open (fast operation)
    String? chatToOpen = await PreferencesService.getChatToOpen();
    
    // If no chat is saved, use the default
    _initialChatId = chatToOpen ?? defaultChatId;
  }
  
  Future<void> _initializeRemainingResources() async {
    // Perform any remaining heavy operations here
    // These will happen after the UI is already displayed
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Location services and other heavy services can be initialized here
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Get default dark scheme for splash
      final colorScheme = AppTheme.colorSchemes[0].darkScheme;
      
      // Show modern splash screen
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: colorScheme,
          useMaterial3: true,
        ),
        home: Scaffold(
          backgroundColor: colorScheme.background,
          body: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chat_outlined,
                      size: 50,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SAJJEL',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onBackground,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Once initialized, launch the full app
      return MyApp(initialChatId: _initialChatId);
    }
  }
}

// A minimal error app in case of init errors
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sajjel')),
        body: const Center(
          child: Text('There was an error starting the app. Please restart.'),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyApp extends StatelessWidget {
  final String initialChatId;

  const MyApp({super.key, required this.initialChatId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) {
        return MaterialApp(
          title: 'Sajjel',
          themeMode: themeController.themeMode,
          theme: AppTheme.getLightTheme(themeController.colorSchemeIndex),
          darkTheme: AppTheme.getDarkTheme(themeController.colorSchemeIndex),
          // Use HomeScreen instead of ChatScreen
          home: HomeScreen(initialChatId: initialChatId),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}