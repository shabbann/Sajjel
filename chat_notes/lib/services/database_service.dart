import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';
import '../models/chat_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class DatabaseService {
  static Database? _database;
  static const int _databaseVersion = 2;

  // Add memory cache for commonly accessed data
  static final Map<String, List<dynamic>> _notesCache = {};
  static final Map<String, List<String>> _tagsCache = {};
  static final Map<String, String> _chatNameCache = {};
  static List<Chat> _chatsCache = [];
  static bool _cacheInitialized = false;
  
  // Clear cache on app close or when needed
  Future<void> clearCache() async {
    _notesCache.clear();
    _tagsCache.clear();
    _chatNameCache.clear();
    _chatsCache.clear();
    _cacheInitialized = false;
  }
  
  Future<void> initCache() async {
    if (_cacheInitialized) return;
    
    try {
      final db = await database;
      // Load chats
      final chatMaps = await db.query('chats', orderBy: 'createdAt DESC');
      _chatsCache = chatMaps.map((map) => Chat.fromMap(map)).toList();
      
      // Cache chat names for quick access
      for (final chat in _chatsCache) {
        _chatNameCache[chat.id] = chat.name;
      }
      
      _cacheInitialized = true;
    } catch (e) {
      debugPrint('Error initializing cache: $e');
    }
  }

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

  // Close and reopen the database to fix connection issues
  Future<void> closeAndReopen() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Reopen the database
    await database;
    
    // Verify the database is working by running a simple query
    final db = await database;
    try {
      await db.rawQuery('SELECT 1');
      debugPrint('Database reopened successfully');
    } catch (e) {
      debugPrint('Error reopening database: $e');
      await _recoverDatabase();
      _database = await _initDatabase();
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
    
    // Update cache
    if (_notesCache.containsKey(note.chatId)) {
      _notesCache[note.chatId]!.add(note);
    }
    
    // Update tags cache if note has tags
    if (note.tags.isNotEmpty) {
      final currentTags = _tagsCache[note.chatId] ?? [];
      for (final tag in note.tags) {
        if (!currentTags.contains(tag)) {
          currentTags.add(tag);
        }
      }
      _tagsCache[note.chatId] = currentTags;
    }
  }

  Future<List<dynamic>> getNotesByChatId(String chatId) async {
    // Return from cache if available
    if (_notesCache.containsKey(chatId)) {
      return _notesCache[chatId]!;
    }
    
    final db = await database;
    
    try {
      // Query with limit and index hint for better performance
      final maps = await db.rawQuery(
        'SELECT * FROM notes WHERE chatId = ? ORDER BY timestamp ASC LIMIT 1000',
        [chatId],
      );
      
      final notes = maps.map((map) => Note.fromMap(map)).toList();
      
      // Cache results
      _notesCache[chatId] = notes;
      
      return notes;
    } catch (e) {
      debugPrint('Error getting notes: $e');
      // Fall back to regular query if optimized one fails
      final maps = await db.query(
        'notes',
        where: 'chatId = ?',
        whereArgs: [chatId],
        orderBy: 'timestamp ASC',
      );
      return maps.map((map) => Note.fromMap(map)).toList();
    }
  }

  Future<void> insertChat(Chat chat) async {
    final db = await database;
    await db.insert('chats', chat.toMap());
    
    // Update cache
    _chatsCache.insert(0, chat);
    _chatNameCache[chat.id] = chat.name;
  }

  Future<List<Chat>> getChats() async {
    // Return from cache if available and initialized
    if (_cacheInitialized && _chatsCache.isNotEmpty) {
      return _chatsCache;
    }
    
    final db = await database;
    final maps = await db.query('chats', orderBy: 'createdAt DESC');
    final chats = maps.map((map) => Chat.fromMap(map)).toList();
    
    // Cache results
    _chatsCache = chats;
    // Update chat name cache
    for (final chat in chats) {
      _chatNameCache[chat.id] = chat.name;
    }
    
    return chats;
  }

  Future<String?> getChatName(String chatId) async {
    // Return from cache if available
    if (_chatNameCache.containsKey(chatId)) {
      return _chatNameCache[chatId];
    }
    
    final db = await database;
    final maps = await db.query(
      'chats',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final name = maps.first['name'] as String;
    _chatNameCache[chatId] = name;
    return name;
  }

  Future<List<String>> getAllTags(String chatId) async {
    // Return from cache if available
    if (_tagsCache.containsKey(chatId)) {
      return _tagsCache[chatId]!;
    }
    
    final db = await database;
    final notes = await getNotesByChatId(chatId);
    
    final Set<String> allTags = {};
    for (final note in notes) {
      allTags.addAll(note.tags);
    }
    
    // Cache results
    _tagsCache[chatId] = allTags.toList();
    
    return allTags.toList();
  }

  // Get tags from all chats, not just a specific one
  Future<List<String>> getAllTagsGlobal() async {
    final db = await database;
    
    try {
      // Use a direct SQL query to extract unique tags - much more efficient than loading all notes
      final result = await db.rawQuery(
        "SELECT DISTINCT value FROM (SELECT tags FROM notes WHERE tags IS NOT NULL AND tags != '') t, "
        "json_each('[\"|' || replace(replace(t.tags, ',', '|\",\"'), ' ', '') || '|\"]') "
        "WHERE value != ''"
      );
      
      // Extract the tag values from the result
      final Set<String> allTags = {};
      for (final row in result) {
        final tag = row['value'] as String;
        if (tag.isNotEmpty) {
          allTags.add(tag.trim());
        }
      }
      
      return allTags.toList();
    } catch (e) {
      // If the optimized query fails (e.g., on older SQLite versions), fall back to the original method
      debugPrint('Optimized tag query failed, falling back to original method: $e');
      
      final notes = await getNotes();
      final Set<String> allTags = {};
      for (final note in notes) {
        allTags.addAll(note.tags);
      }
      
      return allTags.toList();
    }
  }

  // Save a tag globally (not tied to a specific chat)
  Future<void> saveTagGlobal(String tag) async {
    final tags = await getAllTagsGlobal();
    
    // If tag already exists globally, no need to save it
    if (tags.contains(tag)) {
      return;
    }
    
    // Get the first chat or create a default one if none exists
    final chats = await getChats();
    String chatId;
    
    if (chats.isEmpty) {
      // Create a default chat if none exists
      chatId = 'global_tags_${DateTime.now().millisecondsSinceEpoch}';
      await insertChat(Chat(
        id: chatId,
        name: 'System',
        createdAt: DateTime.now(),
      ));
    } else {
      chatId = chats.first.id;
    }
    
    // Create a special "tag storage" note
    final note = Note(
      id: 'tag_global_${DateTime.now().millisecondsSinceEpoch}_${tag.hashCode}',
      content: '_GLOBAL_TAG_STORAGE_',
      timestamp: DateTime.now(),
      isUserNote: true,
      chatId: chatId,
      tags: [tag],
    );
    
    await insertNote(note);
    debugPrint('Global tag saved: $tag');
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

  // Add a method to save a tag to a special note if it doesn't exist
  Future<void> saveTag(String chatId, String tag) async {
    final tags = await getAllTags(chatId);
    
    // If tag already exists, no need to save it
    if (tags.contains(tag)) {
      return;
    }
    
    // Create a special "tag storage" note
    // This is an invisible note that just stores the tag
    final note = Note(
      id: 'tag_${DateTime.now().millisecondsSinceEpoch}_${tag.hashCode}',
      content: '_TAG_STORAGE_',  // Special content that could be filtered out of UI
      timestamp: DateTime.now(),
      isUserNote: true,
      chatId: chatId,
      tags: [tag],
    );
    
    await insertNote(note);
    debugPrint('Tag saved: $tag');
  }

  // Batch update all notes with a specific tag
  Future<void> batchUpdateTag(String oldTag, String newTag) async {
    final db = await database;
    
    // Get all notes with the old tag
    final notes = await db.query(
      'notes',
      where: 'tags LIKE ?',
      whereArgs: ['%$oldTag%'],
    );
    
    // Prepare batch update
    final batch = db.batch();
    
    for (final note in notes) {
      final noteObj = Note.fromMap(note);
      if (noteObj.tags.contains(oldTag)) {
        final updatedTags = List<String>.from(noteObj.tags);
        updatedTags.remove(oldTag);
        if (newTag.isNotEmpty) {
          updatedTags.add(newTag);
        }
        
        note['tags'] = updatedTags.join(',');
        batch.update(
          'notes',
          {'tags': note['tags']},
          where: 'id = ?',
          whereArgs: [note['id']],
        );
      }
    }
    
    // Execute all updates in a single transaction
    await batch.commit(noResult: true);
  }
  
  // Batch delete a tag from all notes
  Future<void> batchDeleteTag(String tag) async {
    // Reuse the batch update with empty new tag to delete
    await batchUpdateTag(tag, '');
  }
}