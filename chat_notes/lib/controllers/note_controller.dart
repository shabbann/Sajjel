// Modified main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/note_controller.dart';
import 'controllers/theme_controller.dart'; // Add missing import
import 'services/database_service.dart';
import 'views/screens/chat_list_screen.dart'; // Import ChatListScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final databaseService = DatabaseService();
  await databaseService.initDatabase();
  
  final defaultChatId = DateTime.now().toString();
  await databaseService.createInitialChat(defaultChatId);
  
  runApp(MyApp(defaultChatId: defaultChatId));
}

class MyApp extends StatelessWidget {
  final String defaultChatId;

  const MyApp({super.key, required this.defaultChatId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NoteController(databaseService: DatabaseService()),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController(), // Add ThemeController
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'Sajjel',
            theme: themeController.isDarkMode 
                ? ThemeData.dark() 
                : ThemeData(primarySwatch: Colors.blue),
            home: ChatListScreen(), // Start with ChatListScreen
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}