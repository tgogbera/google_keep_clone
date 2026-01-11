import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/exceptions/api_exceptions.dart';
import '../models/note.dart';

class NoteRepository {
  final ApiClient _apiClient;

  NoteRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Note> createNote(String title, String content) async {
    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/notes',
        data: {'title': title, 'content': content},
      );

      return Note.fromJson(data);
    } on ApiException {
      rethrow; // Let Cubit handle it
    } catch (e) {
      throw UnknownApiException(message: 'Failed to create note: $e');
    }
  }

  Future<List<Note>> getNotes() async {
    final data = await _apiClient.get<List<dynamic>>('/notes');

    return data.map((note) => Note.fromJson(note as Map<String, dynamic>)).toList();
  }

  Future<Note> updateNote(String id, String title, String content) async {
    final data = await _apiClient.put<Map<String, dynamic>>(
      '/notes/$id',
      data: {'title': title, 'content': content},
    );

    return Note.fromJson(data);
  }

  Future<void> deleteNote(String id) async {
    await _apiClient.delete('/notes/$id');
  }
}
