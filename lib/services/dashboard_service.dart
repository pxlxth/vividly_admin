import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<int> getTopicsCount() async {
    final response = await _supabase
        .from('topics')
        .select('id');

    return response.length;
  }

//only for active lessons
Future<int> getLessonsCount() async {
  final response = await _supabase
      .from('lessons')
      .select('id')
      .eq('is_published', true);
  return response.length;
}

  Future<int> getUsersCount() async {
    final response = await _supabase
        .from('public_profiles')
        .select('id');

    return response.length;
  }
}