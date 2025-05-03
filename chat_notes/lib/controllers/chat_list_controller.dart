import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../services/database_service.dart';

class ChatListController extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Chat> _chats = [];

  ChatListController() {
    // Load chats when controller is created
    loadChats();
  }

  List<Chat> get chats => _chats;

  Future<void> loadChats() async {
    _chats = await _databaseService.getChats();
    notifyListeners();
  }

  Future<void> addChat(Chat chat) async {
    await _databaseService.insertChat(chat);
    await loadChats();
  }

  Future<void> deleteChat(String chatId) async {
    await _databaseService.deleteChat(chatId);
    await loadChats();
  }
} 