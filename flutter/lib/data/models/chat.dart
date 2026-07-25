class Chat {
  final String id;
  final String userId;
  final String title;
  final String contextText;
  final DateTime createdAt;

  const Chat({
    required this.id,
    required this.userId,
    required this.title,
    this.contextText = '',
    required this.createdAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String? ?? '',
    contextText: json['context_text'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
