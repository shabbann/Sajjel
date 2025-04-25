import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/note_model.dart';

class NoteController extends ChangeNotifier {
  final DatabaseService databaseService;
  bool _isLoading = false;
  List<dynamic> _notes = [];
  String _currentChatId = '';

  NoteController({required this.databaseService});

  // Getters
  bool get isLoading => _isLoading;
  List<dynamic> get notes => _notes;
  String get currentChatId => _currentChatId;

  // Methods
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadNotes() async {
    setLoading(true);
    try {
      if (_currentChatId.isNotEmpty) {
        _notes = await databaseService.getNotesByChatId(_currentChatId);
      } else {
        _notes = await databaseService.getNotes();
      }
    } catch (e) {
      print('Error loading notes: $e');
    } finally {
      setLoading(false);
    }
  }

  void setCurrentChat(String chatId) {
    _currentChatId = chatId;
    loadNotes();
  }

  Future<void> addNote(
    String content, 
    bool isUserNote, 
    {List<String> tags = const [], 
    String? color,
    double? latitude,
    double? longitude,
    String? locationName}) async {
    if (_currentChatId.isEmpty) return;
    
    final note = Note(
      id: DateTime.now().toString(),
      content: content,
      timestamp: DateTime.now(),
      isUserNote: isUserNote,
      chatId: _currentChatId,
      tags: tags,
      color: color,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );

    await databaseService.insertNote(note);
    await loadNotes();
  }

  Future<void> updateNote(Note note, {
    String? content, 
    List<String>? tags,
    String? color,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    final updatedNote = Note(
      id: note.id,
      content: content ?? note.content,
      timestamp: note.timestamp,
      isUserNote: note.isUserNote,
      chatId: note.chatId,
      tags: tags ?? note.tags,
      color: color ?? note.color,
      latitude: latitude ?? note.latitude,
      longitude: longitude ?? note.longitude,
      locationName: locationName ?? note.locationName,
    );

    await databaseService.updateNote(updatedNote);
    await loadNotes();
  }

  Future<void> deleteNote(String noteId) async {
    await databaseService.deleteNote(noteId);
    await loadNotes();
  }
} 