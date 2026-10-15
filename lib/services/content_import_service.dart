import 'package:supabase_flutter/supabase_flutter.dart';

import 'excel_import.dart';

class ContentImportResult {
  final String status;
  final String message;
  final String? lessonId;

  ContentImportResult({
    required this.status,
    required this.message,
    this.lessonId,
  });

  bool get imported => status == 'imported';
  bool get duplicate => status == 'duplicate';
}

class ContentImportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ContentImportResult> importLesson(
    ExcelLessonData lesson, {
    required bool isPublished,
  }) async {
    try {
      final response = await _supabase.rpc(
        'import_lesson_content',
        params: {
          'p_topic_es': lesson.topicEs,
          'p_topic_en': lesson.topicEn,
          'p_title_es': lesson.titleEs,
          'p_title_en': lesson.titleEn,
          'p_subtitle_es': lesson.subtitleEs,
          'p_subtitle_en': lesson.subtitleEn,
          'p_witness_name_es': lesson.witnessNameEs,
          'p_witness_name_en': lesson.witnessNameEn,
          'p_is_published': isPublished,
          'p_initial_quiz_es': lesson.initialQuizEs
              .map(
                (quiz) => {
                  'question': quiz.question,
                  'answers': quiz.answers,
                },
              )
              .toList(),

          'p_initial_quiz_en': lesson.initialQuizEn
              .map(
                (quiz) => {
                  'question': quiz.question,
                  'answers': quiz.answers,
                },
              )
              .toList(),

          'p_final_quiz_es': lesson.finalQuizEs
              .map(
                (quiz) => {
                  'question': quiz.question,
                  'answers': quiz.answers,
                },
              )
              .toList(),

          'p_final_quiz_en': lesson.finalQuizEn
              .map(
                (quiz) => {
                  'question': quiz.question,
                  'answers': quiz.answers,
                },
              )
              .toList(),

          'p_flashcards_es': lesson.flashcardsEs
              .map(
                (flashcard) => {
                  'title': flashcard.title,
                  'content': flashcard.content,
                },
              )
              .toList(),

          'p_flashcards_en': lesson.flashcardsEn
              .map(
                (flashcard) => {
                  'title': flashcard.title,
                  'content': flashcard.content,
                },
              )
              .toList(),
        },
      );

      final data = Map<String, dynamic>.from(response);
      return ContentImportResult(
        status: data['status']?.toString() ?? 'error',
        message: data['message']?.toString() ??
            'No se recibió una respuesta válida.',
        lessonId: data['lesson_id']?.toString(),
      );
    } catch (e) {
      return ContentImportResult(
        status: 'error',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}