import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Default values can be replaced by the developer or configured in-app.
  static String cloudName = 'dafkbzlrs'; 
  static String uploadPreset = 'vasl_unsigned_preset';

  /// Uploads a local file directly to Cloudinary using an unsigned upload preset.
  /// If using default placeholder credentials, it mocks the upload with a 1.5s delay
  /// and returns a high-quality random profile image URL for testing.
  static Future<String> uploadImage(File file) async {
    if (cloudName == 'vasl-cloud' || uploadPreset == 'vasl-preset') {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 1500));
      // Return a high-quality fallback avatar image from i.pravatar.cc
      final randomId = DateTime.now().millisecondsSinceEpoch % 70;
      return 'https://i.pravatar.cc/300?img=$randomId';
    }

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(responseBody);
        return data['secure_url'] ?? '';
      } else {
        throw Exception('Server returned status code: ${response.statusCode}\nResponse: $responseBody');
      }
    } catch (e) {
      throw Exception('Failed to connect to Cloudinary: $e');
    }
  }
}
