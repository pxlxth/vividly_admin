import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/topic.dart';

class TopicService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Topic>> getTopics() async {
    try {
      final response = await Supabase.instance.client
          .from('topics')
          .select('id, name_es, name_en, slug, display_order, created_at')
          .order('display_order');

      return response
          .map<Topic>((json) => Topic.fromJson(json))
          .toList();
    } catch (e) {
      print('Error obteniendo tópicos: $e');
      return [];
    }
  }

  Future<List<Topic>> searchTopics(
    String query, {
    String filter = 'az',
    Map<String, int> lessonCounts = const {},
  }) async {
    try {
      var request = _supabase
          .from('topics')
          .select('id, name_es, name_en, slug, display_order, created_at');

      if (query.trim().isNotEmpty) {
        request = request.or(
          'name_es.ilike.%${query.trim()}%,name_en.ilike.%${query.trim()}%',
        );
      }

      final response = await request;

      final topics = (response as List)
          .map((json) => Topic.fromJson(json))
          .toList();

    switch (filter) {
      case 'za':
        topics.sort((a, b) =>
            b.nameEs.toLowerCase().compareTo(a.nameEs.toLowerCase()));
        break;

      case 'recientes':
        topics.sort((a, b) =>
            (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0)));
        break;

      case 'antiguos':
        topics.sort((a, b) =>
            (a.createdAt ?? DateTime(0))
                .compareTo(b.createdAt ?? DateTime(0)));
        break;

      case 'mas_lecciones':
        topics.sort((a, b) =>
            (lessonCounts[b.id] ?? 0)
                .compareTo(lessonCounts[a.id] ?? 0));
        break;

      case 'menos_lecciones':
        topics.sort((a, b) =>
            (lessonCounts[a.id] ?? 0)
                .compareTo(lessonCounts[b.id] ?? 0));
        break;

      case 'az':
      default:
        topics.sort((a, b) =>
            a.nameEs.toLowerCase().compareTo(b.nameEs.toLowerCase()));
        break;
    }

      return topics;
    } catch (e) {
      print('Error buscando/filtrando tópicos: $e');
      return [];
    }
  }

  Future<void> updateTopic({
    required String id,
    required String nameEs,
    required String nameEn,
  }) async {
    await _supabase
        .from('topics')
        .update({
          'name_es': nameEs,
          'name_en': nameEn,
        })
        .eq('id', id);
  }

  Future<List<Topic>> filterTopics(String filter) async {
    try {
      final response = await _supabase
          .from('topics')
          .select('id, name_es, name_en, slug, display_order, created_at');

      final topics = response
          .map<Topic>((json) => Topic.fromJson(json))
          .toList();

      switch (filter) {
        case 'fecha':
          topics.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;

            return b.createdAt!.compareTo(a.createdAt!);
          });
          break;

        case 'az':
          topics.sort(
            (a, b) => a.nameEs.toLowerCase().compareTo(
                  b.nameEs.toLowerCase(),
                ),
          );
          break;

        case 'za':
          topics.sort(
            (a, b) => b.nameEs.toLowerCase().compareTo(
                  a.nameEs.toLowerCase(),
                ),
          );
          break;
      }

      return topics;
    } catch (e) {
      print('Error filtrando tópicos: $e');
      return [];
    }
  }


  Future<Map<String, int>> getLessonCountsByTopic() async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('topic_id');

      final Map<String, int> counts = {};

      for (final row in response as List) {
        final topicId = row['topic_id'] as String?;

        if (topicId != null) {
          counts[topicId] = (counts[topicId] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      print('Error contando lecciones por tópico: $e');
      return {};
    }
  }


  Future<Topic> createTopic({
    required String nameEs,
    required String nameEn,
    required String slug,
  }) async {
    final response = await _supabase
        .from('topics')
        .insert({
          'name_es': nameEs,
          'name_en': nameEn,
          'slug': slug,
        })
        .select('id, name_es, name_en, slug, display_order, created_at')
        .single();

    return Topic.fromJson(response);
  }
}