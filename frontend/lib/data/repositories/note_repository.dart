import 'package:dio/dio.dart';
import '../../core/config/api_config.dart';
import '../models/note.dart';

class NoteRepository {
  final Dio _dio;

  NoteRepository({Dio? dio}) : _dio = dio ?? Dio();

  Future<Note> createNote(String token, String title, String content) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/notes',
        data: {
          'title': title,
          'content': content,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return Note.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['error'] as String? ?? 
            'Failed to create note';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }
}
