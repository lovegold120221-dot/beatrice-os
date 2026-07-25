import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  SupabaseClient get client => _client;

  User? get user => _client.auth.currentUser;

  Future<AuthResponse> signUp(String email, String password) =>
      _client.auth.signUp(email: email, password: password);

  Future<AuthResponse> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<List<Map<String, dynamic>>> getChats() async {
    final user = this.user;
    if (user == null) throw Exception('Not authenticated');
    final response = await _client
        .from('chats')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getChatContext(String chatId) async {
    try {
      final response = await _client
          .from('chats')
          .select('context_text')
          .eq('id', chatId)
          .single();
      return response as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createChat(
    String title,
    String contextText,
  ) async {
    final user = this.user;
    if (user == null) throw Exception('Not authenticated');
    final response = await _client
        .from('chats')
        .insert({
          'user_id': user.id,
          'title': title,
          'context_text': contextText,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<void> updateChatContext(String chatId, String contextText) async {
    await _client
        .from('chats')
        .update({'context_text': contextText})
        .eq('id', chatId);
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> insertMessage(Map<String, dynamic> message) async {
    final user = this.user;
    if (user == null) return;
    message['user_id'] = user.id;
    message['created_at'] = DateTime.now().toIso8601String();
    await _client.from('messages').insert(message);
  }

  Future<void> deleteChat(String chatId) async {
    await _client.from('chats').delete().eq('id', chatId);
  }

  Future<List<Map<String, dynamic>>> getMemories() async {
    final user = this.user;
    if (user == null) return [];
    final response = await _client
        .from('memories')
        .select()
        .eq('user_id', user.id)
        .order('last_accessed', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> storeMemory(Map<String, dynamic> memory) async {
    final user = this.user;
    if (user == null) return;
    memory['user_id'] = user.id;
    memory['created_at'] = DateTime.now().toIso8601String();
    memory['last_accessed'] = DateTime.now().toIso8601String();
    await _client
        .from('memories')
        .upsert(memory, onConflict: 'user_id,content');
  }

  Future<Map<String, dynamic>?> loadDeviceProfile(String deviceId) async {
    try {
      final response = await _client
          .from('device_profiles')
          .select()
          .eq('device_id', deviceId)
          .single();
      return response as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDeviceProfile(Map<String, dynamic> profile) async {
    await _client
        .from('device_profiles')
        .upsert(profile, onConflict: 'device_id');
  }

  Future<Map<String, dynamic>?> loadMobileAgentSettings() async {
    final user = this.user;
    if (user == null) return null;
    try {
      final response = await _client
          .from('mobile_agent_settings')
          .select('provider,model,updated_at')
          .eq('user_id', user.id)
          .maybeSingle();
      return response == null ? null : Map<String, dynamic>.from(response);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMobileAgentSettings({
    required String provider,
    required String model,
  }) async {
    final user = this.user;
    if (user == null) return;
    await _client.from('mobile_agent_settings').upsert({
      'user_id': user.id,
      'provider': provider,
      'model': model,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<String?> uploadImage(
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    final response = await _client.storage
        .from('chat-images')
        .uploadBinary('$userId/$fileName', bytes);
    if (response.isEmpty) return null;
    final publicUrl = _client.storage
        .from('chat-images')
        .getPublicUrl('$userId/$fileName');
    return publicUrl;
  }
}
