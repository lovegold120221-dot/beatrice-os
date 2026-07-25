import 'dart:convert';
import 'package:http/http.dart' as http;

class FluxService {
  final String? hfToken;

  FluxService(this.hfToken);

  static const _model = 'black-forest-labs/FLUX.1-dev';

  static const _aspectDimensions = {
    '1:1': [1024, 1024],
    '16:9': [1344, 768],
    '9:16': [768, 1344],
    '4:3': [1152, 896],
    '3:4': [896, 1152],
    '3:2': [1216, 832],
    '2:3': [832, 1216],
    '4:5': [896, 1120],
    '5:4': [1120, 896],
    '21:9': [1344, 576],
    '9:21': [576, 1344],
  };

  List<int> _getDimensions(String aspectRatio, String size) {
    final base = _aspectDimensions[aspectRatio] ?? _aspectDimensions['1:1']!;
    final scale = size == '1K'
        ? 1.0
        : size == '2K'
        ? 1.3
        : 1.6;
    return [(base[0] * scale).round(), (base[1] * scale).round()];
  }

  Future<String?> generateImage(
    String prompt, {
    String size = '1K',
    String aspectRatio = '1:1',
  }) async {
    if (hfToken == null || hfToken!.isEmpty) {
      throw Exception('Hugging Face token not configured');
    }

    final dims = _getDimensions(aspectRatio, size);

    final response = await http.post(
      Uri.parse('https://api-inference.huggingface.co/models/$_model'),
      headers: {
        'Authorization': 'Bearer $hfToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'inputs': prompt,
        'width': dims[0],
        'height': dims[1],
        'num_inference_steps': 28,
        'guidance_scale': 3.5,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Flux API error: ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    final base64 = base64Encode(bytes);
    return 'data:image/png;base64,$base64';
  }
}
