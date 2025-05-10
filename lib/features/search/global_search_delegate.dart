import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import '../../services/database_service.dart';
import '../../views/screens/chat_screen.dart';
import 'package:intl/intl.dart';

class GlobalSearchDelegate extends SearchDelegate<String> {
  final DatabaseService _databaseService = DatabaseService();
  final DateFormat _dateFormat = DateFormat('MMM d, HH:mm');
  
  @override
  String get searchFieldLabel => 'Search across all chats';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Type to search across all chats'),
      );
    }
    
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<Note>>(
      future: _databaseService.searchAllNotes(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No results found for "$query"'),
          );
        }

        // Get all unique chat IDs from the results
        final chatIds = snapshot.data!.map((note) => note.chatId).toSet().toList();
        
        return FutureBuilder<Map<String, String>>(
          future: _databaseService.getChatNames(chatIds),
          builder: (context, chatNamesSnapshot) {
            final chatNames = chatNamesSnapshot.data ?? {};
            
            return ListView.separated(
              itemCount: snapshot.data!.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final note = snapshot.data![index];
                final chatName = chatNames[note.chatId] ?? 'Unknown Chat';
                
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: note.isUserNote 
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.surfaceVariant,
                    child: Icon(
                      note.isUserNote ? Icons.person : Icons.note,
                      color: note.isUserNote 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  title: RichText(
                    text: TextSpan(
                      text: note.content,
                      style: theme.textTheme.bodyMedium,
                      children: _buildHighlightSpans(note.content, theme),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateFormat.format(note.timestamp),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'In chat: $chatName',
                        style: theme.textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // Navigate to the chat containing this note
                    close(context, note.chatId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: note.chatId),
                      ),
                    );
                  },
                );
              },
            );
          }
        );
      },
    );
  }

  List<TextSpan> _buildHighlightSpans(String text, ThemeData theme) {
    if (query.isEmpty) return [];
    
    final List<TextSpan> spans = [];
    final String lowercaseText = text.toLowerCase();
    final String lowercaseQuery = query.toLowerCase();
    
    int lastMatchEnd = 0;
    
    // Find all occurrences of the query in the note content
    while (true) {
      final int matchStart = lowercaseText.indexOf(lowercaseQuery, lastMatchEnd);
      if (matchStart == -1) break;
      
      final int matchEnd = matchStart + query.length;
      
      // Add span for text before match
      if (matchStart > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, matchStart),
          style: theme.textTheme.bodyMedium,
        ));
      }
      
      // Add span for the match with highlight
      spans.add(TextSpan(
        text: text.substring(matchStart, matchEnd),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        ),
      ));
      
      lastMatchEnd = matchEnd;
    }
    
    // Add span for text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: theme.textTheme.bodyMedium,
      ));
    }
    
    return spans;
  }
} 