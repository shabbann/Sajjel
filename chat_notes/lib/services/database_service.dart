import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';
import '../models/chat_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class DatabaseService {
  static Database? _database;
  static const int _databaseVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      debugPrint('Error initializing database: $e');
      // Attempt to recover by deleting and recreating the database
      await _recoverDatabase();
      _database = await _initDatabase();
      return _database!;
    }
  }

  Future<void> _recoverDatabase() async {
    try {
      final path = await getDatabasesPath();
      final dbPath = join(path, 'notes.db');
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted corrupted database file');
      }
    } catch (e) {
      debugPrint('Error during database recovery: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    return openDatabase(
      join(path, 'notes.db'),
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
      version: _databaseVersion,
      singleInstance: true,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add audioPath column to the notes table
      await db.execute('ALTER TABLE notes ADD COLUMN audioPath TEXT');
    }
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
        color TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        audioPath TEXT
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
    try {
      // Just initialize the connection, don't perform any operations yet
      await database;
      debugPrint('Database initialized successfully');
    } catch (e) {
      debugPrint('Error initializing database: $e');
      // Try to recover
      await _recoverDatabase();
    }
  }

  Future<void> createInitialChat(String chatId) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      final count = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM chats LIMIT 1')
      );
      
      if (count == 0 || count == null) {
        await txn.insert('chats', {
          'id': chatId,
          'name': 'My First Chat',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert('notes', note.toMap());
  }

  Future<List<dynamic>> getNotesByChatId(String chatId) async {
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

  Future<List<Note>> searchAllNotes(String query) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<Map<String, String>> getChatNames(List<String> chatIds) async {
    final db = await database;
    final result = <String, String>{};
    
    for (final chatId in chatIds) {
      final maps = await db.query(
        'chats', 
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [chatId],
      );
      
      if (maps.isNotEmpty) {
        result[chatId] = maps.first['name'] as String;
      }
    }
    
    return result;
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

  Future<List<dynamic>> getNotes() async {
    final db = await database;
    final results = await db.query('notes');
    return results.map((row) => Note.fromMap(row)).toList();
  }
}