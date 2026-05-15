import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';
  static const _system =
      'You are Cardiva AI, a helpful health assistant embedded in a wearable '
      'health monitoring app. Provide clear, friendly, and concise responses '
      'about health data. Always recommend consulting a doctor for serious '
      'concerns. Never diagnose. Add brief disclaimers when appropriate.';

  static Future<String> ask(String prompt, {int maxTokens = 512}) async {
    final key = dotenv.env['GROQ_API_KEY'] ?? '';
    if (key.isEmpty) return 'Groq API key is not configured.';

    try {
      final resp = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': _system},
                {'role': 'user', 'content': prompt},
              ],
              'max_tokens': maxTokens,
              'temperature': 0.5,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['choices'][0]['message']['content'] as String?)?.trim() ??
            'No response received.';
      }
      return 'AI unavailable (HTTP ${resp.statusCode}).';
    } catch (e) {
      return 'Could not reach Cardiva AI. Check your connection.';
    }
  }
}
