import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/settings.dart';

class StatusService {
  Future<List<dynamic>> fetchProcessingStatuses() async {
    final settings = await Settings.load();
    final baseUrl = settings.apiUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      return [];
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/status/processing'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      // Ignore network errors to avoid spamming the UI
    }
    return [];
  }
}
