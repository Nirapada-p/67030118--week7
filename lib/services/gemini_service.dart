import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String _model = 'gemini-2.5-flash';

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    // ตรวจสอบ Status Code
    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API Error: ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // ตรวจสอบ candidates ว่ามีข้อมูลหรือไม่
    final candidates = data['candidates'];

    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini ไม่ได้ส่ง candidates กลับมา');
    }

    // ดึงข้อความจาก response
    final content = candidates[0]['content'];

    if (content is! Map<String, dynamic>) {
      throw Exception('ไม่พบ content จาก Gemini');
    }

    final parts = content['parts'];

    if (parts is! List || parts.isEmpty) {
      throw Exception('ไม่พบข้อความจาก Gemini');
    }

    final text = parts[0]['text'];

    if (text is! String || text.isEmpty) {
      throw Exception('Gemini ส่งข้อความว่างกลับมา');
    }

    return text;
  }
}
