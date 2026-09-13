import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MultimediaImportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> importZip({
    required Uint8List zipBytes,
    required String zipName,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // Buscar la carpeta/lección dentro del ZIP
    final files = archive.files.where((file) => file.isFile).toList();

    if (files.isEmpty) {
      throw Exception('El ZIP no contiene archivos.');
    }

    // Buscar Calígula en la BD
    final lessonResponse = await _supabase
        .from('lessons')
        .select('id, title_es')
        .ilike('title_es', '%caligula%')
        .maybeSingle();

    if (lessonResponse == null) {
      throw Exception('No se encontró la lección Calígula.');
    }

    final lessonId = lessonResponse['id'] as String;

    String? introEs;
    String? introEn;
    String? protagonistEs;
    String? protagonistEn;
    String? witnessEs;
    String? witnessEn;
    String? infographicEs;
    String? infographicEn;
    String? audioEs;
    String? audioEn;

    for (final file in files) {
      final fileName = file.name.split('/').last.toLowerCase();

      final Uint8List bytes = Uint8List.fromList(file.content);

      String? storagePath;

      if (fileName == 'intro_es.mp4') {
        storagePath = 'caligula/intro_es.mp4';
      } else if (fileName == 'intro_en.mp4') {
        storagePath = 'caligula/intro_en.mp4';
      } else if (fileName == 'protagonist_es.mp4') {
        storagePath = 'caligula/protagonist_es.mp4';
      } else if (fileName == 'protagonist_en.mp4') {
        storagePath = 'caligula/protagonist_en.mp4';
      } else if (fileName == 'witness_es.mp4') {
        storagePath = 'caligula/witness_es.mp4';
      } else if (fileName == 'witness_en.mp4') {
        storagePath = 'caligula/witness_en.mp4';
      } else if (fileName == 'infographic_es.png') {
        storagePath = 'caligula/infographic_es.png';
      } else if (fileName == 'infographic_en.png') {
        storagePath = 'caligula/infographic_en.png';
      } else if (fileName == 'infographic_audio_es.wav') {
        storagePath = 'caligula/infographic_audio_es.wav';
      } else if (fileName == 'infographic_audio_en.wav') {
        storagePath = 'caligula/infographic_audio_en.wav';
      }

      if (storagePath == null) continue;

      await _supabase.storage.from('lesson-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _supabase.storage
          .from('lesson-media')
          .getPublicUrl(storagePath);

      if (fileName == 'intro_es.mp4') introEs = url;
      if (fileName == 'intro_en.mp4') introEn = url;
      if (fileName == 'protagonist_es.mp4') protagonistEs = url;
      if (fileName == 'protagonist_en.mp4') protagonistEn = url;
      if (fileName == 'witness_es.mp4') witnessEs = url;
      if (fileName == 'witness_en.mp4') witnessEn = url;
      if (fileName == 'infographic_es.png') infographicEs = url;
      if (fileName == 'infographic_en.png') infographicEn = url;
      if (fileName == 'infographic_audio_es.wav') audioEs = url;
      if (fileName == 'infographic_audio_en.wav') audioEn = url;
    }

    await _supabase
        .from('lessons')
        .update({
          'intro_video_url_es': introEs,
          'intro_video_url_en': introEn,
          'protagonist_base_video_url_es': protagonistEs,
          'protagonist_base_video_url_en': protagonistEn,
          'witness_base_video_url_es': witnessEs,
          'witness_base_video_url_en': witnessEn,
        })
        .eq('id', lessonId);

    await _supabase.from('lesson_infographics').upsert({
      'lesson_id': lessonId,
      'image_url_es': infographicEs,
      'image_url_en': infographicEn,
      'audio_url_es': audioEs,
      'audio_url_en': audioEn,
    }, onConflict: 'lesson_id');

    return 'Multimedia de Calígula importada correctamente.';
  }
}