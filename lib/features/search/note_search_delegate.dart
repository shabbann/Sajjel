import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class NoteSearchDelegate extends SearchDelegate<String?> {
  final String chatId;
  final DatabaseService _databaseService = DatabaseService();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy - h:mm a');

  NoteSearchDelegate({required this.chatId});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.hintColor,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<Note>>(
      future: _databaseService.searchNotes(chatId, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error searching notes'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: theme.hintColor),
                SizedBox(height: 16),
                Text(
                  'No notes found',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (context, index) => Divider(height: 1),
          itemBuilder: (context, index) {
            final note = snapshot.data![index];
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
              subtitle: Text(
                _dateFormat.format(note.timestamp),
                style: theme.textTheme.bodySmall,
              ),
              onTap: () => close(context, note.id),
            );
          },
        );
      },
    );
  }

  List<TextSpan> _buildHighlightSpans(String content, ThemeData theme) {
    if (query.isEmpty) return [];
    
    final matches = query.toLowerCase().allMatches(content.toLowerCase());
    if (matches.isEmpty) return [];
    
    final spans = <TextSpan>[];
    int lastEnd = 0;
    
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: theme.textTheme.bodyMedium,
        ));
      }
      
      spans.add(TextSpan(
        text: content.substring(match.start, match.end),
        style: theme.textTheme.bodyMedium?.copyWith(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ));
      
      lastEnd = match.end;
    }
    
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: theme.textTheme.bodyMedium,
      ));
    }
    
    return spans;
  }

  @override
  String get searchFieldLabel => 'Search notes...';
}