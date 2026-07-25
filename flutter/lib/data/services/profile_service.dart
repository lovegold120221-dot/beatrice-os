import 'package:beatrice/data/models/device_profile.dart';
import 'package:beatrice/data/repositories/supabase_repository.dart';
import 'package:beatrice/data/services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  final SupabaseRepository _repo;

  ProfileService(this._repo);

  // Local (SharedPreferences) keys. The Ollama base URL is intentionally
  // local-only: the deployed `device_profiles` table has no `ollama_base_url`
  // column, so syncing it would break the upsert. The base URL is a
  // per-device property anyway (Termux runs on 127.0.0.1 on the device).
  static const _userContextKey = 'eburon_userContext';
  static const _responseStyleKey = 'eburon_responseStyle';
  static const _themeKey = 'eburon_theme';
  static const _ollamaModelKey = 'eburon_ollamaModel';
  static const _ollamaBaseUrlKey = 'eburon_ollamaBaseUrl';

  Future<Map<String, String>> loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userContext': prefs.getString(_userContextKey) ?? '',
      'responseStyle': prefs.getString(_responseStyleKey) ?? '',
      'theme': prefs.getString(_themeKey) ?? 'system',
      'ollamaModel': prefs.getString(_ollamaModelKey) ?? '',
      'ollamaBaseUrl':
          prefs.getString(_ollamaBaseUrlKey) ?? 'http://127.0.0.1:11434',
    };
  }

  Future<void> saveLocalSettings({
    required String userContext,
    required String responseStyle,
    required String theme,
    required String ollamaModel,
    required String ollamaBaseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userContextKey, userContext);
    await prefs.setString(_responseStyleKey, responseStyle);
    await prefs.setString(_themeKey, theme);
    await prefs.setString(_ollamaModelKey, ollamaModel);
    await prefs.setString(_ollamaBaseUrlKey, ollamaBaseUrl);
  }

  Future<DeviceProfile?> loadCloudProfile() async {
    final deviceId = await DeviceService.getDeviceId();
    final data = await _repo.loadDeviceProfile(deviceId);
    if (data != null) {
      return DeviceProfile.fromJson(data);
    }
    return null;
  }

  Future<void> saveCloudProfile({
    required String userContext,
    required String responseStyle,
    required String theme,
    required String ollamaModel,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    await _repo.saveDeviceProfile({
      'device_id': deviceId,
      'user_context': userContext,
      'response_style': responseStyle,
      'theme': theme,
      'ollama_model': ollamaModel,
      'last_seen_at': DateTime.now().toIso8601String(),
    });
  }
}
