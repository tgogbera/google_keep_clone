import 'package:dio/dio.dart';
import '../models/note.dart';

class NoteRepository {
  final Dio _dio;

  NoteRepository({required Dio dio}) : _dio = dio;

  Future<Note> createNote(String title, String content) async {
    try {
      final response = await _dio.post(
        '/notes',
        data: {
          'title': title,
          'content': content,
        },
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
