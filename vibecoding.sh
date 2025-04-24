#!/bin/bash

# Create a new Flutter project
flutter create chat_notes
cd chat_notes

# Create directory structure
mkdir -p lib/{controllers,models,views/{screens,widgets},services}

# Create model file
cat > lib/models/note_model.dart << 'EOL'
class Note {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isUserNote;

  Note({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isUserNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isUserNote': isUserNote ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      isUserNote: map['isUserNote'] == 1,
    );
  }
}
EOL

# Create controller file
cat > lib/controllers/note_controller.dart << 'EOL'
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../services/database_service.dart';

class NoteController extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  Future<void> addNote(String content, bool isUserNote) async {
    final note = Note(
      id: DateTime.now().toString(),
      content: content,
      timestamp: DateTime.now(),
      isUserNote: isUserNote,
    );

    await _databaseService.insertNote(note);
    _notes.add(note);
    notifyListeners();
  }

  Future<void> loadNotes() async {
    _notes = await _databaseService.getNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _databaseService.deleteNote(id);
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
  }
}
EOL

# Create database service file
cat > lib/services/database_service.dart << 'EOL'
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'chat_notes.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        content TEXT,
        timestamp TEXT,
        isUserNote INTEGER
      )
    ''');
  }

  Future<void> insertNote(Note note) async {
    final Database db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getNotes() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<void> deleteNote(String id) async {
    final Database db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
EOL

# Create chat bubble widget
cat > lib/views/widgets/chat_bubble.dart << 'EOL'
import 'package:flutter/material.dart';
import '../../models/note_model.dart';

class ChatBubble extends StatelessWidget {
  final Note note;

  const ChatBubble({Key? key, required this.note}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: note.isUserNote ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: note.isUserNote ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.content,
              style: TextStyle(fontSize: 16.0),
            ),
            Text(
              '${note.timestamp.hour}:${note.timestamp.minute}',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
EOL

# Create chat input widget
cat > lib/views/widgets/chat_input.dart << 'EOL'
import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type a note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () => onSubmitted(controller.text),
          ),
        ],
      ),
    );
  }
}
EOL

# Create chat screen
cat > lib/views/screens/chat_screen.dart << 'EOL'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/note_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteController>().loadNotes();
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    context.read<NoteController>().addNote(text, true);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Notes'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<NoteController>(
              builder: (context, noteController, child) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8.0),
                  itemCount: noteController.notes.length,
                  itemBuilder: (context, index) {
                    return ChatBubble(note: noteController.notes[index]);
                  },
                );
              },
            ),
          ),
          ChatInput(
            controller: _textController,
            onSubmitted: _handleSubmitted,
          ),
        ],
      ),
    );
  }
}
EOL

# Create main.dart
cat > lib/main.dart << 'EOL'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/note_controller.dart';
import 'views/screens/chat_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NoteController(),
      child: MaterialApp(
        title: 'Chat Notes',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: ChatScreen(),
      ),
    );
  }
}
EOL

# Update pubspec.yaml with dependencies
sed -i '/dependencies:/a\
  provider: ^6.0.5\
  sqflite: ^2.2.8+4\
  path: ^1.8.3' pubspec.yaml

# Get dependencies
flutter pub get

echo "Project setup complete!"