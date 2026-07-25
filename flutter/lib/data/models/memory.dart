class Memory {
  final String? id;
  final String userId;
  final String content;
  final String category;
  final String? createdAt;
  final String? lastAccessed;

  const Memory({
    this.id,
    required this.userId,
    required this.content,
    required this.category,
    this.createdAt,
    this.lastAccessed,
  });

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
    id: json['id'] as String?,
    userId: json['user_id'] as String,
    content: json['content'] as String,
    category: json['category'] as String,
    createdAt: json['created_at'] as String?,
    lastAccessed: json['last_accessed'] as String?,
  );
}
