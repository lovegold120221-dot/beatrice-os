import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ollama_service.dart';

/// App-owned, bounded public-web adapter. It is invoked only after the user
/// enables Web for a Chat turn and Ollama requests `web_lookup`.
class WebLookupService {
  final http.Client _client;

  WebLookupService({http.Client? client}) : _client = client ?? http.Client();

  Future<WebLookupResult> lookup(String query) async {
    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrlimit': '3',
      'prop': 'extracts|info',
      'exintro': '1',
      'explaintext': '1',
      'exsentences': '3',
      'inprop': 'url',
      'format': 'json',
      'origin': '*',
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Web lookup failed with HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    final queryData = decoded is Map ? decoded['query'] : null;
    final pages = queryData is Map ? queryData['pages'] : null;
    if (pages is! Map || pages.isEmpty) {
      return WebLookupResult(
        query: query,
        summary: 'No attributed encyclopedia results were found.',
        sourceUrls: const [],
      );
    }
    final entries = pages.values.whereType<Map>().take(3).toList();
    final summary = entries
        .map((page) {
          final title = page['title']?.toString() ?? 'Result';
          final extract = page['extract']?.toString().trim() ?? '';
          return '$title: $extract';
        })
        .join('\n');
    final urls = entries
        .map((page) => page['fullurl']?.toString() ?? '')
        .where((url) => url.startsWith('https://'))
        .toList();
    return WebLookupResult(query: query, summary: summary, sourceUrls: urls);
  }
}
