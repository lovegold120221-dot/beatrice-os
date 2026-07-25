import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class OpenCodeService {
  static const _termuxChannel = MethodChannel('beatrice/termux');
  String baseUrl;
  String password;

  OpenCodeService({this.baseUrl = 'http://127.0.0.1:4096', this.password = ''});

  Map<String, String> get _headers => {
    if (password.isNotEmpty)
      'Authorization':
          'Basic ${base64Encode(utf8.encode('opencode:$password'))}',
  };

  Future<List<String>> listModels() async {
    final response = await http
        .get(
          Uri.parse(
            '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/config/providers',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final providers = body['providers'] as List? ?? [];
    final models = <String>[];
    for (final provider in providers.whereType<Map>()) {
      final providerId = provider['id']?.toString() ?? '';
      final entries = provider['models'];
      if (entries is Map) {
        for (final modelId in entries.keys) {
          models.add(providerId.isEmpty ? '$modelId' : '$providerId/$modelId');
        }
      }
    }
    return models;
  }

  Future<void> startLocalServer() async {
    await _termuxChannel.invokeMethod<void>('startOpenCode');
  }
}
