import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flashcard.dart';

class FlashcardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Flashcard>> getFlashcardsByLesson(String lessonId) async {
    try {
      print('BUSCANDO FLASHCARDS PARA LESSON ID: $lessonId');

      final response = await _supabase
          .from('lesson_flashcards')
          .select('''
            id,
            lesson_id,
            title_es,
            content_es,
            image_url,
            display_order,
            created_at,
            title_en,
            content_en
          ''')
          .eq('lesson_id', lessonId)
          .order('display_order', ascending: true);

      print('RESPUESTA FLASHCARDS: $response');

      return (response as List)
          .map((json) => Flashcard.fromJson(json))
          .toList();
    } catch (e) {
      print('ERROR OBTENIENDO FLASHCARDS: $e');
      return [];
    }
  }
}