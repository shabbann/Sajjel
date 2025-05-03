import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/note_model.dart';

class NoteController extends ChangeNotifier {
  final DatabaseService databaseService;
  bool _isLoading = false;
  List<dynamic> _notes = [];
  String _currentChatId = '';
  bool _hasNewNote = false;

  NoteController({required this.databaseService});

  // Getters
  bool get isLoading => _isLoading;
  List<dynamic> get notes => _notes;
  String get currentChatId => _currentChatId;
  bool get hasNewNote => _hasNewNote;

  // Methods
  void resetNewNoteFlag() {
    _hasNewNote = false;
  }

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
    String? locationName,
    String? audioPath}) async {
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
      audioPath: audioPath,
    );

    try {
      await databaseService.insertNote(note);
      _hasNewNote = true;
      await loadNotes();
    } catch (e) {
      debugPrint("Error adding note: $e");
      // Rethrow the exception to be handled by the UI layer
      rethrow;
    }
  }

  Future<void> updateNote(Note note, {
    String? content, 
    List<String>? tags,
    String? color,
    double? latitude,
    double? longitude,
    String? locationName,
    String? audioPath,
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
      audioPath: audioPath ?? note.audioPath,
    );

    try {
      await databaseService.updateNote(updatedNote);
      await loadNotes();
    } catch (e) {
      debugPrint("Error updating note: $e");
      // Rethrow the exception to be handled by the UI layer
      rethrow;
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await databaseService.deleteNote(noteId);
      await loadNotes();
    } catch (e) {
      debugPrint("Error deleting note: $e");
      // Rethrow the exception to be handled by the UI layer
      rethrow;
    }
  }
} 