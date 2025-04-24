import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';
import '../models/chat_model.dart';

class DatabaseService {
  static Database? _database;
  static const int _databaseVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    return openDatabase(
      join(path, 'notes.db'),
      onCreate: _createDb,
      version: _databaseVersion,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes(
        id TEXT PRIMARY KEY,
        content TEXT,
        timestamp TEXT,
        isUserNote INTEGER,
        chatId TEXT,
        tags TEXT,
        color TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chats(
        id TEXT PRIMARY KEY,
        name TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> initDatabase() async {
    await database;
  }

  Future<void> createInitialChat(String chatId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM chats'));
    
    if (count == 0) {
      await insertChat(Chat(
        id: chatId,
        name: 'My First Chat',
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotesByChatId(String chatId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<void> insertChat(Chat chat) async {
    final db = await database;
    await db.insert('chats', chat.toMap());
  }

  Future<List<Chat>> getChats() async {
    final db = await database;
    final maps = await db.query('chats', orderBy: 'createdAt DESC');
    return maps.map((map) => Chat.fromMap(map)).toList();
  }

  Future<List<String>> getAllTags(String chatId) async {
    final db = await database;
    final notes = await getNotesByChatId(chatId);
    
    final Set<String> allTags = {};
    for (final note in notes) {
      allTags.addAll(note.tags);
    }
    
    return allTags.toList();
  }

  Future<void> updateChat(Chat chat) async {
    final db = await database;
    await db.update(
      'chats',
      chat.toMap(),
      where: 'id = ?',
      whereArgs: [chat.id],
    );
  }

  Future<void> deleteChat(String chatId) async {
    final db = await database;
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    await db.delete('notes', where: 'chatId = ?', whereArgs: [chatId]);
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String noteId) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
  }

  Future<List<Note>> searchNotes(String chatId, String query) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'chatId = ? AND content LIKE ?',
      whereArgs: [chatId, '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<String> backupDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
    
    final dbPath = join(await getDatabasesPath(), 'notes.db');
    final backupDir = Directory('${Directory.systemTemp.path}/sajjel_backups');
    
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${backupDir.path}/notes_backup_$timestamp.db';
    
    final dbFile = File(dbPath);
    await dbFile.copy(backupPath);
    
    return backupPath;
  }

  Future<bool> restoreDatabase(String backupPath) async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      final dbPath = join(await getDatabasesPath(), 'notes.db');
      final backupFile = File(backupPath);
      
      if (await backupFile.exists()) {
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
        
        await backupFile.copy(dbPath);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error restoring database: $e');
      return false;
    }
  }
}