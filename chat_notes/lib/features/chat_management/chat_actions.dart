import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';

class ChatActions {
  final BuildContext context;
  final DatabaseService _databaseService = DatabaseService();

  ChatActions(this.context);

  // Static methods for direct access without instantiation
  static Future<void> renameChatDialog(
    BuildContext context, 
    String chatId, 
    String currentName, 
    Function onComplete
  ) async {
    final databaseService = DatabaseService();
    final TextEditingController nameController = TextEditingController(text: currentName);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final chats = await databaseService.getChats();
                final chat = chats.firstWhere((c) => c.id == chatId);
                
                final updatedChat = Chat(
                  id: chat.id,
                  name: nameController.text.trim(),
                  createdAt: chat.createdAt,
                );
                await databaseService.updateChat(updatedChat);
                Navigator.pop(context);
                onComplete();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  static Future<bool> confirmChatDelete(
    BuildContext context,
    String chatId,
    String chatName,
  ) async {
    final databaseService = DatabaseService();
    bool deleted = false;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "$chatName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await databaseService.deleteChat(chatId);
              deleted = true;
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    return deleted;
  }

  void showChatOptions(Chat chat, Function onComplete) async {
    // Check if this chat is currently set as default
    final defaultChatId = await PreferencesService.getDefaultChat();
    final isDefault = chat.id == defaultChatId;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isDefault ? Icons.star : Icons.star_border),
              title: Text(isDefault ? 'Remove default chat' : 'Set as default chat'),
              onTap: () async {
                if (isDefault) {
                  await PreferencesService.saveDefaultChat(null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Default chat removed')),
                  );
                } else {
                  await PreferencesService.saveDefaultChat(chat.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Default chat set')),
                  );
                }
                Navigator.pop(context);
                onComplete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Chat'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(chat, onComplete);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(chat, onComplete);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Chat chat, Function onComplete) {
    final TextEditingController nameController = TextEditingController(text: chat.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final updatedChat = Chat(
                  id: chat.id,
                  name: nameController.text.trim(),
                  createdAt: chat.createdAt,
                );
                await _databaseService.updateChat(updatedChat);
                Navigator.pop(context);
                onComplete();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Chat chat, Function onComplete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "${chat.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _databaseService.deleteChat(chat.id);
              Navigator.pop(context);
              onComplete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool> deleteChat(Chat chat) async {
    bool deleted = false;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "${chat.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _databaseService.deleteChat(chat.id);
              deleted = true;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    return deleted;
  }
}