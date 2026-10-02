import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/listing_draft.dart';

class GeminiVisionService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Gemini 3.5 Flash เป็น Stable model และรองรับ GenerateContent
  static const String _model = 'gemini-3.5-flash';

  Future<ListingDraft> analyzeProductImage(
    File imageFile, {
    String prompt =
        'ช่วยวิเคราะห์ภาพสินค้านี้สำหรับลงประกาศขายในตลาดมหาวิทยาลัย '
        'โดยแนะนำชื่อสินค้า (title), หมวดหมู่ (category), '
        'และคำอธิบายสินค้า (description) เป็นภาษาไทย',
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY');
    }

    // 1. อ่านไฟล์ภาพเป็นไบต์ -> Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // กำหนด MIME type ตามนามสกุลไฟล์
    String mimeType = 'image/jpeg';
    final path = imageFile.path.toLowerCase();

    if (path.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (path.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (path.endsWith('.heic')) {
      mimeType = 'image/heic';
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey',
    );

    // 2. สร้าง Request
    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {'mimeType': mimeType, 'data': base64Image},
            },
            {'text': prompt},
          ],
        },
      ],

      // กำหนด Safety filter
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_LOW_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_LOW_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_LOW_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_LOW_AND_ABOVE',
        },
      ],

      // กำหนดผลลัพธ์เป็น JSON
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {
              'type': 'STRING',
              'description': 'ชื่อสินค้าที่กระชับและน่าสนใจ',
            },
            'category': {'type': 'STRING', 'description': 'หมวดหมู่ของสินค้า'},
            'description': {
              'type': 'STRING',
              'description': 'รายละเอียด จุดเด่น และสภาพของสินค้า',
            },
          },
          'required': ['title', 'category', 'description'],
        },
      },
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 45));

    debugPrint('Gemini HTTP Status: ${response.statusCode}');

    // 3. ตรวจ HTTP Error
    if (response.statusCode != 200) {
      debugPrint('Gemini Error Response: ${response.body}');

      if (response.statusCode == 429) {
        throw Exception(
          'Gemini API 429: เกินโควตาหรือจำนวนคำขอ กรุณารอสักครู่แล้วลองใหม่',
        );
      }

      if (response.statusCode == 404) {
        throw Exception('Gemini API 404: ไม่พบโมเดล $_model');
      }

      throw Exception(
        'Gemini API Error: ${response.statusCode} - '
        '${response.reasonPhrase ?? ""}',
      );
    }

    // 4. แกะ Response จาก Gemini
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // 5. ตรวจ Prompt Safety
    final promptFeedback = data['promptFeedback'];

    if (promptFeedback is Map<String, dynamic>) {
      final blockReason = promptFeedback['blockReason'];

      debugPrint('Gemini Prompt Block Reason: $blockReason');

      if (blockReason != null) {
        throw Exception(
          'SAFETY: Gemini บล็อก Prompt '
          '(blockReason: $blockReason)',
        );
      }
    } else {
      debugPrint('Gemini Prompt Block Reason: null');
    }

    // 6. ตรวจ candidates
    final candidates = data['candidates'];

    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini ไม่ได้ส่ง candidates กลับมา');
    }

    final candidate = candidates[0] as Map<String, dynamic>;

    // 7. ตรวจ finishReason
    final finishReason = candidate['finishReason'];

    debugPrint('Gemini Finish Reason: $finishReason');

    // 8. ตรวจ Safety Ratings
    final safetyRatings = candidate['safetyRatings'];

    debugPrint(
      'Gemini Safety Ratings: '
      '${jsonEncode(safetyRatings)}',
    );

    if (finishReason == 'SAFETY' ||
        finishReason == 'PROHIBITED_CONTENT' ||
        finishReason == 'BLOCKLIST') {
      throw Exception(
        'SAFETY: Gemini บล็อกการตอบกลับ '
        '(finishReason: $finishReason)',
      );
    }

    // 9. ถ้าไม่ถูกบล็อก จึงอ่าน content
    final content = candidate['content'];

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

    // 10. แปลง JSON ที่ Gemini ส่งกลับมา
    final draftJson = jsonDecode(text) as Map<String, dynamic>;

    return ListingDraft.fromJson(draftJson);
  }
}
