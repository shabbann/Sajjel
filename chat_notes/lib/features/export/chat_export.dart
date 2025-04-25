import 'dart:io';
import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart'; // Removed share_plus import
import 'package:intl/intl.dart';
import 'package:flutter/material.dart'; // Added for BuildContext
import '../../models/chat_model.dart';
import '../../models/note_model.dart';
import '../../services/database_service.dart';
import '../../services/share_service.dart'; // Added ShareService import

class ChatExport {
  final DatabaseService _databaseService = DatabaseService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final DateFormat _exportDateFormat = DateFormat('EEE, MMM d, yyyy');

  Future<String> exportChat(String chatId, {String format = 'txt'}) async {
    try {
      final notes = await _databaseService.getNotesByChatId(chatId);
      final chats = await _databaseService.getChats();
      final chat = chats.firstWhere((chat) => chat.id == chatId);

      final exportContent = StringBuffer();
      _buildHeader(exportContent, chat);
      _buildNotes(exportContent, notes);

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'sajjel_${chat.name}_${DateTime.now().millisecondsSinceEpoch}.$format';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(exportContent.toString());
      return file.path;
    } catch (e) {
      throw Exception('Failed to export chat: ${e.toString()}');
    }
  }

  void _buildHeader(StringBuffer content, Chat chat) {
    content.writeln('Sajjel Notes Export');
    content.writeln('=' * 50);
    content.writeln('Chat: ${chat.name}');
    content.writeln('Created: ${_exportDateFormat.format(chat.createdAt)}');
    content.writeln('Exported: ${_exportDateFormat.format(DateTime.now())}');
    content.writeln('=' * 50);
    content.writeln();
  }

  void _buildNotes(StringBuffer content, List<dynamic> notes) {
    String? currentDate;
    
    for (final note in notes) {
      final noteDate = _exportDateFormat.format(note.timestamp);
      if (noteDate != currentDate) {
        content.writeln('\n$noteDate');
        content.writeln('-' * 30);
        currentDate = noteDate;
      }
      
      content.writeln(
        '[${_dateFormat.format(note.timestamp)}] '
        '${note.isUserNote ? "USER" : "NOTE"}: ${note.content}'
      );
      
      if (note.tags.isNotEmpty) {
        content.writeln('  Tags: ${note.tags.join(', ')}');
      }
      
      if (note.hasLocation && note.locationName != null) {
        content.writeln('  Location: ${note.locationName}');
      }
      
      // Removed the reminder-related code that was causing errors
    }
  }

  Future<void> shareChat(String chatId, BuildContext context) async {
    try {
      final filePath = await exportChat(chatId);
      // Use our custom ShareService
      await ShareService.shareFile(context, filePath);
    } catch (e) {
      throw Exception('Failed to share chat: ${e.toString()}');
    }
  }

  Future<String> exportAsMarkdown(String chatId) async {
    return exportChat(chatId, format: 'md');
  }
}