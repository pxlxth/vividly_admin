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
    String filter = 'fecha',
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
        case 'fecha':
          topics.sort((a, b) {
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