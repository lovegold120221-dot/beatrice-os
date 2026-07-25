import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _key = 'eburon_device_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_key);
    if (deviceId == null) {
      final hash = DateTime.now().millisecondsSinceEpoch.toString();
      final random = Random().nextInt(99999).toString();
      deviceId = 'device_${hash}_$random';
      await prefs.setString(_key, deviceId);
    }
    return deviceId;
  }
}
