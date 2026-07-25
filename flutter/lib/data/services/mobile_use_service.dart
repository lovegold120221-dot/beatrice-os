import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MobileUseStatus {
  final int version;
  final bool runtimeRunning;
  final bool accessibilityEnabled;
  final bool accessibilityConnected;
  final LocalModelSelection localModel;
  final Map<String, bool> optionalPermissions;
  final String runtimeTaskState;
  final String runtimeTaskDetail;

  const MobileUseStatus({
    required this.version,
    required this.runtimeRunning,
    required this.accessibilityEnabled,
    required this.accessibilityConnected,
    required this.localModel,
    required this.optionalPermissions,
    required this.runtimeTaskState,
    required this.runtimeTaskDetail,
  });

  factory MobileUseStatus.fromMap(Map<dynamic, dynamic> map) {
    return MobileUseStatus(
      version: map['version'] as int? ?? 1,
      runtimeRunning: map['runtimeRunning'] == true,
      accessibilityEnabled: map['accessibilityEnabled'] == true,
      accessibilityConnected: map['accessibilityConnected'] == true,
      localModel: LocalModelSelection.fromMap(
        map['localModel'] as Map<dynamic, dynamic>? ?? const {},
      ),
      optionalPermissions: Map<String, bool>.from(
        (map['optionalPermissions'] as Map<dynamic, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value == true),
        ),
      ),
      runtimeTaskState: map['runtimeTaskState'] as String? ?? 'stopped',
      runtimeTaskDetail:
          map['runtimeTaskDetail'] as String? ?? 'No task is running',
    );
  }
}

class LocalModelSelection {
  final bool selected;
  final String? name;
  final int size;
  final String? localPath;
  final bool localFileReady;
  final bool runtimeReady;
  final String runtimeStatus;

  const LocalModelSelection({
    required this.selected,
    required this.name,
    required this.size,
    required this.localPath,
    required this.localFileReady,
    required this.runtimeReady,
    required this.runtimeStatus,
  });

  factory LocalModelSelection.fromMap(Map<dynamic, dynamic> map) {
    return LocalModelSelection(
      selected: map['selected'] == true,
      name: map['name'] as String?,
      size: (map['size'] as num?)?.toInt() ?? 0,
      localPath: map['path'] as String?,
      localFileReady: map['localFileReady'] == true,
      runtimeReady: map['runtimeReady'] == true,
      runtimeStatus:
          map['runtimeStatus'] as String? ?? 'Runtime setup required',
    );
  }
}

class MobileUseService {
  static const MethodChannel _channel = MethodChannel(
    'com.eburon.beatrice/mobile_use_v1',
  );
  static final StreamController<String> _runtimeStopController =
      StreamController<String>.broadcast();
  static bool _nativeHandlerInstalled = false;

  MobileUseService() {
    if (_nativeHandlerInstalled || kIsWeb) return;
    _nativeHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'runtimeStopped') return;
      final arguments = call.arguments;
      final reason = arguments is Map ? arguments['reason']?.toString() : null;
      _runtimeStopController.add(
        reason?.trim().isNotEmpty == true
            ? reason!.trim()
            : 'Stopped by the user',
      );
    });
  }

  bool get isSupported => !kIsWeb;
  Stream<String> get runtimeStopEvents => _runtimeStopController.stream;

  Future<MobileUseStatus> getStatus() async {
    if (kIsWeb) {
      return MobileUseStatus.fromMap(const {
        'runtimeRunning': false,
        'accessibilityEnabled': false,
        'accessibilityConnected': false,
        'optionalPermissions': <String, bool>{},
        'runtimeTaskState': 'unsupported',
        'runtimeTaskDetail':
            'Android MobileUseAgent controls are unavailable in Flutter Web.',
      });
    }
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getStatus',
    );
    return MobileUseStatus.fromMap(result ?? const {});
  }

  Future<void> openAccessibilitySettings() async {
    if (kIsWeb) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'Android Accessibility settings are unavailable on web.',
      );
    }
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<bool> requestOptionalPermission(String permission) async {
    if (kIsWeb) return false;
    return await _channel.invokeMethod<bool>('requestOptionalPermission', {
          'permission': permission,
        }) ??
        false;
  }

  Future<void> startRuntime() async {
    if (kIsWeb) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'MobileUseAgent phone control is available only on Android.',
      );
    }
    await _channel.invokeMethod<void>('startRuntime');
  }

  Future<void> stopRuntime() async {
    if (kIsWeb) return;
    await _channel.invokeMethod<void>('stopRuntime');
  }

  Future<bool> updateRuntimeTaskState(String state, String detail) async {
    if (kIsWeb) return false;
    return await _channel.invokeMethod<bool>('updateRuntimeTaskState', {
          'state': state,
          'detail': detail,
        }) ??
        false;
  }

  Future<bool> testRuntime() async {
    if (kIsWeb) return false;
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'testRuntime',
    );
    return result?['ok'] == true;
  }

  Future<LocalModelSelection?> selectLocalModel() async {
    if (kIsWeb) return null;
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'selectLocalModel',
    );
    return result == null ? null : LocalModelSelection.fromMap(result);
  }

  Future<LocalModelSelection> prepareLocalModel() async {
    if (kIsWeb) {
      return LocalModelSelection.fromMap(const {
        'runtimeStatus': 'Local Android model setup is unavailable on web.',
      });
    }
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'prepareLocalModel',
    );
    return LocalModelSelection.fromMap(result ?? const {});
  }

  Future<void> removeLocalModel() async {
    if (kIsWeb) return;
    await _channel.invokeMethod<void>('removeLocalModel');
  }

  Future<Map<String, dynamic>> readScreen() async {
    if (kIsWeb) {
      return const {
        'error': 'Android semantic screen observation is unavailable on web.',
      };
    }
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'readScreen',
    );
    return Map<String, dynamic>.from(result ?? const {});
  }

  Future<bool> executeAction(
    String action,
    Map<String, dynamic> arguments,
  ) async {
    if (kIsWeb && action != 'wait') return false;
    switch (action) {
      case 'launch_app':
        return await _channel.invokeMethod<bool>('launchApp', arguments) ??
            false;
      case 'click_text':
        return await _channel.invokeMethod<bool>('clickText', arguments) ??
            false;
      case 'set_text':
        return await _channel.invokeMethod<bool>('setFocusedText', arguments) ??
            false;
      case 'tap':
      case 'swipe':
      case 'back':
      case 'home':
        return await _channel.invokeMethod<bool>(action, arguments) ?? false;
      case 'wait':
        await Future<void>.delayed(
          Duration(
            milliseconds: ((arguments['milliseconds'] as num?)?.toInt() ?? 500)
                .clamp(100, 3000),
          ),
        );
        return true;
      default:
        throw ArgumentError.value(
          action,
          'action',
          'Action is not allowlisted',
        );
    }
  }
}
