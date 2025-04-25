import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/note_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/database_service.dart';
import 'views/screens/chat_list_screen.dart';

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
            home: ChatListScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}