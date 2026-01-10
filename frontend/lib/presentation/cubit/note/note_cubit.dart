import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/models/note.dart';

part 'note_state.dart';

class NoteCubit extends Cubit<NoteState> {
  final NoteRepository _noteRepository;

  NoteCubit({required NoteRepository noteRepository})
    : _noteRepository = noteRepository,
      super(const NoteInitial());

  Future<void> createNote(String title, String content) async {
    emit(const NoteLoading());
    try {
      final note = await _noteRepository.createNote(title, content);
      emit(NoteSuccess(note: note));
    } catch (e) {
      emit(NoteError(e.toString()));
    }
  }

  void reset() {
    emit(const NoteInitial());
  }
}
