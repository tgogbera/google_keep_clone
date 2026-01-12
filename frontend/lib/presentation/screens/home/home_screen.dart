import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/presentation/cubit/auth/auth_cubit.dart';
import 'package:go_router/go_router.dart';
import '../../cubit/note/note_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showCreateNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<NoteCubit>(),
        child: BlocListener<NoteCubit, NoteState>(
          listener: (context, state) {
            if (state is NoteCreated) {
              Navigator.of(dialogContext).pop();
            } else if (state is NoteError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
            }
          },
          child: AlertDialog(
            title: const Text('Create Note'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              BlocBuilder<NoteCubit, NoteState>(
                builder: (context, state) {
                  final isLoading = state is NoteLoading;
                  return ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            if (formKey.currentState!.validate()) {
                              context.read<NoteCubit>().createNote(
                                titleController.text.trim(),
                                contentController.text.trim(),
                              );
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          PopupMenuButton(
            icon: CircleAvatar(),
            itemBuilder: (context) => <PopupMenuEntry>[
              PopupMenuItem(enabled: false, child: Text('Signed in!')),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: () {
                  context.read<AuthCubit>().logout();
                  context.go('/login');
                },
                child: const Row(
                  children: [Icon(Icons.logout), SizedBox(width: 8), Text('Logout')],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              BlocConsumer<NoteCubit, NoteState>(
                listener: (context, state) {
                  if (state is NoteCreated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note created successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.read<NoteCubit>().fetchNotes();
                  }
                  if (state is NoteUpdated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.read<NoteCubit>().fetchNotes();
                  }

                  if (state is NoteDeleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note deleted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.read<NoteCubit>().fetchNotes();
                  }
                },
                builder: (context, state) {
                  if (state is NoteInitial || state is NoteLoading) {
                    return Center(child: const CircularProgressIndicator());
                  }

                  if (state is NotesLoaded) {
                    final notes = state.notes;
                    if (notes.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No notes available. Tap the + button to create your first note.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      );
                    }

                    return Expanded(
                      child: ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return Card(child: ListTile(title: Text(note.title)));
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateNoteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
