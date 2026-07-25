import 'package:beatrice/data/repositories/supabase_repository.dart';

class MemoryService {
  final SupabaseRepository _repo;

  MemoryService(this._repo);

  String buildMemoryContext(List<Map<String, dynamic>> memories) {
    if (memories.isEmpty) return '';

    final grouped = <String, List<String>>{};
    for (final m in memories) {
      final cat = m['category'] as String? ?? 'context';
      final content = m['content'] as String? ?? '';
      if (content.isNotEmpty) {
        grouped.putIfAbsent(cat, () => []).add(content);
      }
    }

    final labels = {
      'user_preference': 'User Preferences',
      'fact': 'Known Facts',
      'context': 'Context',
      'instruction': 'Instructions',
      'emotion': 'Emotional State',
      'relationship': 'Relationships',
    };

    final sections = grouped.entries
        .map((e) {
          final label = labels[e.key] ?? e.key;
          final items = e.value.map((i) => '- $i').join('\n');
          return '$label:\n$items';
        })
        .join('\n\n');

    if (sections.isEmpty) return '';
    return '\n\n## Long-Term Memory\nThe following are things you remember about this user from previous conversations:\n\n$sections';
  }

  Future<List<Map<String, dynamic>>> extractAndStoreMemories(
    String userMessage,
    String assistantMessage,
  ) async {
    final combined = 'User: $userMessage\nAssistant: $assistantMessage';
    final memories = <Map<String, dynamic>>[];

    if (combined.contains(
      RegExp(
        r'(?:i prefer|i like|i love|i hate|i want|i need|i always|i never|i usually)',
        caseSensitive: false,
      ),
    )) {
      memories.add({
        'content': combined.length > 200
            ? combined.substring(0, 200)
            : combined,
        'category': 'user_preference',
      });
    }
    if (combined.contains(
      RegExp(
        r'(?:how (?:do|should|can) i|teach me|show me|walk me through)',
        caseSensitive: false,
      ),
    )) {
      memories.add({
        'content': combined.length > 200
            ? combined.substring(0, 200)
            : combined,
        'category': 'instruction',
      });
    }
    if (combined.contains(
      RegExp(
        r"(?:i feel|i'm feeling|frustrated|happy|excited|confused|annoyed|thank)",
        caseSensitive: false,
      ),
    )) {
      memories.add({
        'content': combined.length > 200
            ? combined.substring(0, 200)
            : combined,
        'category': 'emotion',
      });
    }
    if (combined.contains(
      RegExp(
        r'(?:my team|my boss|my client|my friend|my family|my colleague)',
        caseSensitive: false,
      ),
    )) {
      memories.add({
        'content': combined.length > 200
            ? combined.substring(0, 200)
            : combined,
        'category': 'relationship',
      });
    }

    for (final m in memories) {
      await _repo.storeMemory(m);
    }
    return memories;
  }
}
