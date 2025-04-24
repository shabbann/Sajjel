class Note {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isUserNote;
  final String chatId;
  final List<String> tags;
  final String? color;

  Note({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isUserNote,
    required this.chatId,
    this.tags = const [],
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isUserNote': isUserNote ? 1 : 0,
      'chatId': chatId,
      'tags': tags.join(','),
      'color': color,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      isUserNote: map['isUserNote'] == 1,
      chatId: map['chatId'],
      tags: map['tags'] != null && map['tags'].isNotEmpty
          ? map['tags'].split(',')
          : [],
      color: map['color'],
    );
  }
}