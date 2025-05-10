import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../services/database_service.dart';

class ChatListController extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Chat> _chats = [];

  ChatListController() {
    // Load chats when controller is created
    loadChats();
    
    // Register for database change notifications
    _databaseService.addListener(_onDatabaseChanged);
  }
  
  @override
  void dispose() {
    // Unregister listener when controller is disposed
    _databaseService.removeListener(_onDatabaseChanged);
    super.dispose();
  }
  
  // Callback for database changes
  void _onDatabaseChanged() {
    debugPrint('ChatListController: Database changed notification received');
    loadChats();
  }

  List<Chat> get chats => _chats;

  Future<void> loadChats() async {
    final newChats = await _databaseService.getChats();
    
    // Only notify if there's an actual change in the chat list
    if (_chatsListChanged(_chats, newChats)) {
      _chats = newChats;
    notifyListeners();
    } else {
      // Just update the reference without notification
      _chats = newChats;
    }
  }
  
  // Helper to check if chat lists differ
  bool _chatsListChanged(List<Chat> oldList, List<Chat> newList) {
    // Quick length check
    if (oldList.length != newList.length) return true;
    
    // Check if the IDs match (assuming order matters)
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id) return true;
    }
    
    return false;
  }

  Future<void> addChat(Chat chat) async {
    await _databaseService.insertChat(chat);
    await loadChats();
  }

  Future<void> deleteChat(String chatId) async {
    await _databaseService.deleteChat(chatId);
    // No need to load chats here - the database notification system will trigger refresh
  }
} 