// Modified main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/note_controller.dart';
import 'controllers/theme_controller.dart'; // Add missing import
import 'services/database_service.dart';
import 'views/screens/chat_list_screen.dart'; // Import ChatListScreen
import '../models/note_model.dart';

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

class NoteController extends ChangeNotifier {
  final DatabaseService databaseService;
  String? currentChatId;
  List<Note> notes = [];

  NoteController({required this.databaseService});

  void setCurrentChat(String chatId) {
    currentChatId = chatId;
    loadNotes();
  }

  Future<void> loadNotes() async {
    if (currentChatId == null) return;
    notes = await databaseService.getNotesByChatId(currentChatId!);
    notifyListeners();
  }

  Future<void> addNote(String content, bool isUserNote, {List<String> tags = const [], String? color}) async {
    if (currentChatId == null) return;
    
    final note = Note(
      id: DateTime.now().toString(),
      content: content,
      timestamp: DateTime.now(),
      isUserNote: isUserNote,
      chatId: currentChatId!,
      tags: tags,
      color: color,
    );

    await databaseService.insertNote(note);
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await databaseService.updateNote(note);
    await loadNotes();
  }

  Future<void> deleteNote(String noteId) async {
    await databaseService.deleteNote(noteId);
    await loadNotes();
  }
}