part of 'note_cubit.dart';

abstract class NoteState extends Equatable {
  const NoteState();

  @override
  List<Object?> get props => [];
}

class NoteInitial extends NoteState {
  const NoteInitial();
}

class NoteLoading extends NoteState {
  const NoteLoading();
}

class NoteCreated extends NoteState {
  const NoteCreated();
}

class NoteUpdated extends NoteState {
  const NoteUpdated();
}

class NotesLoaded extends NoteState {
  final List<Note> notes;

  const NotesLoaded({required this.notes});

  @override
  List<Object?> get props => [notes];
}

class NoteDeleted extends NoteState {
  const NoteDeleted();
}

class EmpntyNotes extends NoteState {
  const EmpntyNotes();
}




class NoteError extends NoteState {
  final String message;

  const NoteError(this.message);

  @override
  List<Object?> get props => [message];
}
