import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async'; // Import for error handling
import 'dart:io' show Platform;
import 'controllers/note_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/database_service.dart';
import 'services/preferences_service.dart';
import 'models/chat_model.dart';
import 'views/screens/chat_list_screen.dart';
import 'views/screens/chat_screen.dart';
import 'theme/app_theme.dart';

// Global database service to avoid creating multiple instances
final DatabaseService databaseService = DatabaseService();

void main() {
  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize FFI for desktop platforms
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // Start with the splash screen while initializing resources in background
    runApp(const AppStarter());
    
  }, (error, stack) {
    print('Unhandled error: $error');
    print(stack);
  });
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
      // Show minimal splash without heavy resources
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: Container(
            color: AppTheme.primaryColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_alt_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SAJJEL',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  const MyApp({super.key, this.initialChatId = ''});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NoteController(databaseService: databaseService),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'Sajjel',
            themeMode: themeController.themeMode,
            theme: themeController.getTheme(),
            darkTheme: themeController.getTheme(),
            home: FutureBuilder<List<Chat>>(
              future: databaseService.getChats(),
              builder: (context, snapshot) {
                // If there's an error or data is empty, show chat list
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return ChatListScreen(initialChatId: initialChatId);
                }
                
                // Check if the saved chat still exists
                final chatExists = snapshot.data!.any((chat) => chat.id == initialChatId);
                
                // If the saved chat exists, open it directly
                if (chatExists) {
                  return ChatScreen(chatId: initialChatId);
                }
                
                // Otherwise, show the chat list
                return ChatListScreen(initialChatId: initialChatId);
              },
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}