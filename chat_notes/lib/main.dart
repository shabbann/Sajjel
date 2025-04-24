import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/note_controller.dart';
import 'services/database_service.dart';
import 'views/screens/chat_screen.dart';

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
    return ChangeNotifierProvider(
      create: (_) => NoteController(databaseService: DatabaseService()),
      child: MaterialApp(
        title: 'Chat App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: ChatScreen(chatId: defaultChatId),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}