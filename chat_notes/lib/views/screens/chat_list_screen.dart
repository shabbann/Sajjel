import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Chat> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final chats = await _databaseService.getChats();
    setState(() {
      _chats = chats;
    });
  }

  Future<void> _createNewChat() async {
    final TextEditingController nameController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Chat'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Enter chat name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final chat = Chat(
                  id: DateTime.now().toString(),
                  name: nameController.text.trim(),
                  createdAt: DateTime.now(),
                );
                await _databaseService.insertChat(chat);
                Navigator.pop(context);
                _loadChats();
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sajjel'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _chats.isEmpty
          ? Center(
              child: Text(
                'No chats yet\nCreate a new chat to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      chat.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(chat.name),
                  subtitle: Text(
                    'Created on ${chat.createdAt.day}/${chat.createdAt.month}/${chat.createdAt.year}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: chat.id),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}