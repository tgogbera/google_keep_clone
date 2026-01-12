import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/models/note.dart';

part 'note_state.dart';

class NoteCubit extends Cubit<NoteState> {
  final NoteRepository _noteRepository;

  NoteCubit({required NoteRepository noteRepository})
    : _noteRepository = noteRepository,
      super(const NoteInitial()) {
    fetchNotes();
  }

  Future<void> createNote(String title, String content) async {
    try {
      await _noteRepository.createNote(title, content);
      emit(NoteCreated());
    } catch (e) {
      emit(NoteError(e.toString()));
    }
  }

  Future<void> fetchNotes() async {
    emit(const NoteLoading());
    try {
      final notes = await _noteRepository.getNotes();
      // For simplicity, emitting the first note as success
      if (notes.isNotEmpty) {
        emit(NotesLoaded(notes: notes));
      } else {
        emit(const EmpntyNotes());
      }
    } catch (e) {
      emit(NoteError(e.toString()));
    }
  }

  Future<void> updateNote(String id, String title, String content) async {
    try {
      await _noteRepository.updateNote(id, title, content);
      emit(NoteUpdated());
    } catch (e) {
      emit(NoteError(e.toString()));
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _noteRepository.deleteNote(id);
      emit(NoteDeleted());
    } catch (e) {
      emit(NoteError(e.toString()));
    }
  }
}
