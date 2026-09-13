import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson.dart';

class LessonService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Lesson>> getLessonsByTopic(String topicId) async {
    try {
      print('BUSCANDO LECCIONES PARA TOPIC ID: $topicId');

      final response = await _supabase
          .from('lessons')
          .select('''
            id,
            topic_id,
            title_es,
            title_en,
            subtitle_es,
            subtitle_en,
            display_order,
            created_at,
            is_published,
            thumbnail_url,
            intro_video_url_es,
            intro_video_url_en,
            protagonist_base_video_url_es,
            protagonist_base_video_url_en,
            witness_name_es,
            witness_name_en,
            witness_base_video_url_es,
            witness_base_video_url_en,
            published_at
          ''')
          .eq('topic_id', topicId)
          .order('display_order', ascending: true);

      print('RESPUESTA LESSONS: $response');

      return (response as List)
          .map((json) => Lesson.fromJson(json))
          .toList();
    } catch (e) {
      print('ERROR OBTENIENDO LECCIONES: $e');
      return [];
    }
  }

  Future<List<Lesson>> searchLessons(
    String search, {
    String filter = 'fecha',
  }) async {
    try {
      final searchText = search.trim();

      dynamic query = _supabase
          .from('lessons')
          .select('''
            id,
            topic_id,
            title_es,
            title_en,
            subtitle_es,
            subtitle_en,
            display_order,
            created_at,
            is_published,
            thumbnail_url,
            intro_video_url_es,
            intro_video_url_en,
            protagonist_base_video_url_es,
            protagonist_base_video_url_en,
            witness_name_es,
            witness_name_en,
            witness_base_video_url_es,
            witness_base_video_url_en,
            published_at
          ''');

      if (searchText.isNotEmpty) {
        query = query.or(
          'title_es.ilike.%$searchText%,'
          'title_en.ilike.%$searchText%,'
          'subtitle_es.ilike.%$searchText%,'
          'subtitle_en.ilike.%$searchText%',
        );
      }

      if (filter == 'az') {
        query = query.order(
          'title_es',
          ascending: true,
        );
      } else if (filter == 'za') {
        query = query.order(
          'title_es',
          ascending: false,
        );
      } else {
        query = query.order(
          'created_at',
          ascending: false,
        );
      }

      final response = await query;

      return (response as List)
          .map(
            (json) => Lesson.fromJson(json),
          )
          .toList();
    } catch (e) {
      print('ERROR BUSCANDO LECCIONES: $e');
      return [];
    }
  }

  Future<bool> updatePublishedStatus(
    String lessonId,
    bool isPublished,
  ) async {
    try {
      await _supabase
          .from('lessons')
          .update({
            'is_published': isPublished,
          })
          .eq('id', lessonId);

      print(
        'ESTADO ACTUALIZADO: $lessonId → $isPublished',
      );

      return true;
    } catch (e) {
      print(
        'ERROR ACTUALIZANDO ESTADO: $e',
      );

      return false;
    }
  }
}