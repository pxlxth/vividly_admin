import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MultimediaLessonPreview {
  final String folderName;
  final List<String> files;
  final List<String> warnings;

  MultimediaLessonPreview({
    required this.folderName,
    required this.files,
    this.warnings = const [],
  });

  int get totalFiles => files.length;
}

class MultimediaImportDraft {
  final String importId;
  final String lessonId;
  final String folderName;

  final Map<String, Uint8List> files;

  MultimediaImportDraft({
    required this.importId,
    required this.lessonId,
    required this.folderName,
    required this.files,
  });

  bool hasFile(String fileName) {
    return files.containsKey(fileName);
  }

  Uint8List? getFile(String fileName) {
    return files[fileName];
  }

  void addFile(String fileName, Uint8List bytes) {
    files[fileName] = bytes;
  }

  void removeFile(String fileName) {
    files.remove(fileName);
  }
}

class MultimediaImportService {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<String> _getMultimediaWarnings(List<String> files) {
    final normalizedFiles = files
        .map((file) => file.trim().toLowerCase())
        .toSet();

    final warnings = <String>[];

    bool hasFile(String fileName) {
      return normalizedFiles.contains(fileName.toLowerCase());
    }

    final hasIntroEs =
        hasFile('intro_es.mp4') || hasFile('introductory video spanish.mp4');
    final hasIntroEn =
        hasFile('intro_en.mp4') || hasFile('introductory video english.mp4');
    if (!hasIntroEs) {
      warnings.add('Falta el video de introducción en español.');
    }
    if (!hasIntroEn) {
      warnings.add('Falta el video de introducción en inglés.');
    }
    if (!hasFile('protagonist_es.mp4')) {
      warnings.add('Falta el video del protagonista en español.');
    }

    if (!hasFile('protagonist_en.mp4')) {
      warnings.add('Falta el video del protagonista en inglés.');
    }
    if (!hasFile('witness_es.mp4')) {
      warnings.add('Falta el video del testigo en español.');
    }
    if (!hasFile('witness_en.mp4')) {
      warnings.add('Falta el video del testigo en inglés.');
    }
    if (!hasFile('infographic_es.png')) {
      warnings.add('Falta la infografía en español.');
    }
    if (!hasFile('infographic_en.png')) {
      warnings.add('Falta la infografía en inglés.');
    }
    final hasAudioEs =
        hasFile('infographic_audio_es.wav') ||
        hasFile('infographic_audio_es.mp3');

    final hasAudioEn =
        hasFile('infographic_audio_en.wav') ||
        hasFile('infographic_audio_en.mp3');

    if (!hasAudioEs) {
      warnings.add('Falta el audio de la infografía en español.');
    }

    if (!hasAudioEn) {
      warnings.add('Falta el audio de la infografía en inglés.');
    }
    for (int i = 1; i <= 3; i++) {
      if (!hasFile('flashcard$i.png')) {
        warnings.add('Falta flashcard$i.png.');
      }
    }

    return warnings;
  }

  Future<List<MultimediaLessonPreview>> analyzeZip(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final List<MultimediaLessonPreview> previews = [];

    final innerZipFiles = archive.files.where((file) {
      if (!file.isFile) return false;

      final name = file.name.toLowerCase();

      if (name.startsWith('__macosx/')) return false;

      return name.endsWith('.zip');
    }).toList();

    if (innerZipFiles.isNotEmpty) {
      for (final innerZip in innerZipFiles) {
        try {
          final innerArchive = ZipDecoder().decodeBytes(
            Uint8List.fromList(innerZip.content),
          );

          final files = innerArchive.files.where((file) {
            if (!file.isFile) return false;

            final parts = file.name
                .split('/')
                .where((part) => part.isNotEmpty)
                .toList();

            if (parts.isEmpty) return false;

            if (parts.first == '__MACOSX') return false;

            return true;
          }).toList();

          if (files.isEmpty) continue;

          final Map<String, List<String>> folders = {};

          for (final file in files) {
            final parts = file.name
                .split('/')
                .where((part) => part.isNotEmpty)
                .toList();

            if (parts.length < 2) continue;

            final folder = parts.length >= 3
                ? parts[parts.length - 2]
                : parts[0];

            final fileName = parts.last;

            folders.putIfAbsent(folder, () => []);
            folders[folder]!.add(fileName);
          }

          for (final entry in folders.entries) {
            final warnings = _getMultimediaWarnings(entry.value);

            previews.add(
              MultimediaLessonPreview(
                folderName: entry.key,
                files: entry.value,
                warnings: warnings,
              ),
            );
          }
        } catch (e) {
          continue;
        }
      }

      return previews;
    }

    final Map<String, List<String>> folders = {};

    for (final file in archive.files) {
      if (!file.isFile) continue;

      final parts = file.name
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.isEmpty) continue;

      if (parts.first == '__MACOSX') continue;

      if (parts.length < 2) continue;

      final folder = parts.length >= 3 ? parts[parts.length - 2] : parts[0];

      final fileName = parts.last;

      folders.putIfAbsent(folder, () => []);
      folders[folder]!.add(fileName);
    }

    return folders.entries.map((entry) {
      final warnings = _getMultimediaWarnings(entry.value);

      return MultimediaLessonPreview(
        folderName: entry.key,
        files: entry.value,
        warnings: warnings,
      );
    }).toList();
  }

  Future<String> uploadLessonMultimedia({
    required Uint8List zipBytes,
    required String folderName,
    required String lessonId,
    Map<String, Uint8List> draftFiles = const {},
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    Archive? lessonArchive;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      if (!file.name.toLowerCase().endsWith('.zip')) {
        continue;
      }

      try {
        final innerArchive = ZipDecoder().decodeBytes(
          Uint8List.fromList(file.content),
        );

        final hasLessonFolder = innerArchive.files.any((innerFile) {
          if (!innerFile.isFile) return false;

          final parts = innerFile.name
              .split('/')
              .where((part) => part.isNotEmpty)
              .toList();

          if (parts.length < 2) return false;

          return parts[parts.length - 2] == folderName;
        });

        if (hasLessonFolder) {
          lessonArchive = innerArchive;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    // Si encontramos ZIP interno, usamos ese.
    // Si no, usamos directamente el ZIP recibido.
    final filesToUpload = lessonArchive != null
        ? lessonArchive.files
        : archive.files;

    final Map<String, Uint8List> files = {};

    for (final file in filesToUpload) {
      if (!file.isFile) continue;

      final parts = file.name
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.isEmpty) continue;

      final fileName = parts.last;

      if (parts.length >= 2 && parts[parts.length - 2] == folderName) {
        files[fileName] = Uint8List.fromList(file.content);
      }
    }

    // Los archivos modificados/agregados durante la revisión
    // reemplazan a los originales.
    files.addAll(draftFiles);

    if (files.isEmpty) {
      throw Exception('No se encontraron archivos para "$folderName".');
    }

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
    String? thumbnailUrl;

    final lessonResponse = await _supabase
        .from('lessons')
        .select('topic_id, title_es')
        .eq('id', lessonId)
        .single();

    final topicResponse = await _supabase
        .from('topics')
        .select('slug, name_es')
        .eq('id', lessonResponse['topic_id'])
        .single();

    var topicSlug = topicResponse['slug']?.toString();

    if (topicSlug == null || topicSlug.isEmpty) {
      final topicName = topicResponse['name_es']?.toString() ?? '';

      topicSlug = _slugify(topicName);

      if (topicSlug.isEmpty) {
        throw Exception('No se pudo generar el slug del tópico.');
      }

      await _supabase
          .from('topics')
          .update({'slug': topicSlug})
          .eq('id', lessonResponse['topic_id']);
    }

    final lessonSlug = _slugify(lessonResponse['title_es']?.toString() ?? '');

    if (lessonSlug.isEmpty) {
      throw Exception(
        'No se pudo generar el nombre de la carpeta de la lección.',
      );
    }

    for (final entry in files.entries) {
      final fileName = entry.key.toLowerCase();
      if (fileName.startsWith('._') ||
          fileName.startsWith('__macosx/')) {
        continue;
      }
      final bytes = entry.value;
      String? storagePath;
      print(
        'Subiendo $fileName: '
        '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
      if (fileName == 'flashcard1.png' ||
    fileName == 'flashcard2.png' ||
    fileName == 'flashcard3.png') {

  final flashcardNumber =
      fileName.replaceAll('flashcard', '').replaceAll('.png', '');

  final storagePath =
      '$topicSlug/$lessonSlug/Flashcard$flashcardNumber.png';

  const storageBucket = 'lesson-images';

  await _supabase.storage
      .from(storageBucket)
      .uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(
          upsert: true,
        ),
      );

  final url = _supabase.storage
      .from(storageBucket)
      .getPublicUrl(storagePath);

  // Guardar la URL de la imagen en la flashcard correspondiente
  await _supabase
      .from('lesson_flashcards')
      .update({
        'image_url': url,
      })
      .eq('lesson_id', lessonId)
      .eq('display_order', int.parse(flashcardNumber));

  continue;
}

      switch (fileName) {
       
       case 'intro_es.mp4':
        storagePath = '$topicSlug/$lessonSlug/intro_es.mp4';
        break;

      case 'intro_en.mp4':
        storagePath = '$topicSlug/$lessonSlug/intro_en.mp4';
        break;

      case 'introductory video spanish.mp4':
        storagePath = '$topicSlug/$lessonSlug/intro_es.mp4';
        break;

      case 'introductory video english.mp4':
        storagePath = '$topicSlug/$lessonSlug/intro_en.mp4';
        break;

      case 'protagonist_es.mp4':
        storagePath = '$topicSlug/$lessonSlug/protagonist_es.mp4';
        break;

      case 'protagonist_en.mp4':
        storagePath = '$topicSlug/$lessonSlug/protagonist_en.mp4';
        break;

      case 'witness_es.mp4':
        storagePath = '$topicSlug/$lessonSlug/witness_es.mp4';
        break;

      case 'witness_en.mp4':
        storagePath = '$topicSlug/$lessonSlug/witness_en.mp4';
        break;

        case 'infographic_es.png':
          storagePath = '$topicSlug/$lessonSlug/infographic_es.png';
          break;

        case 'infographic_en.png':
          storagePath = '$topicSlug/$lessonSlug/infographic_en.png';
          break;

        case 'infographic_audio_es.wav':
        storagePath =
            '$topicSlug/$lessonSlug/infographic_audio_es.wav';
        break;

      case 'infographic_audio_en.wav':
        storagePath =
            '$topicSlug/$lessonSlug/infographic_audio_en.wav';
        break;

      case 'infographic_audio_es.mp3':
        storagePath =
            '$topicSlug/$lessonSlug/infographic_audio_es.mp3';
        break;

      case 'infographic_audio_en.mp3':
        storagePath =
            '$topicSlug/$lessonSlug/infographic_audio_en.mp3';
        break;
      }

      if (storagePath == null) continue;

      String bucket;

      if (fileName.endsWith('.mp4')) {
        bucket = 'lesson-videos';
      } else if (fileName.endsWith('.wav') || fileName.endsWith('.mp3')) {
        bucket = 'lesson-audios';
      } else if (fileName.endsWith('.png')) {
        bucket = 'lesson-images';
      } else {
        continue;
      }

      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      final url = _supabase.storage.from(bucket).getPublicUrl(storagePath);

      switch (fileName) {
        case 'intro_es.mp4':
        case 'introductory video spanish.mp4':
          introEs = url;
          break;

        case 'intro_en.mp4':
        case 'introductory video english.mp4':
          introEn = url;
          break;

        case 'protagonist_es.mp4':
          protagonistEs = url;
          break;

        case 'protagonist_en.mp4':
          protagonistEn = url;
          break;

        case 'witness_es.mp4':
          witnessEs = url;
          break;

        case 'witness_en.mp4':
          witnessEn = url;
          break;

        case 'infographic_es.png':
          infographicEs = url;
          break;

        case 'infographic_en.png':
          infographicEn = url;
          break;
        case 'infographic_audio_es.wav':
          audioEs = url;
          break;

        case 'infographic_audio_en.wav':
          audioEn = url;
          break;

        case 'infographic_audio_es.mp3':
          audioEs = url;
          break;

        case 'infographic_audio_en.mp3':
          audioEn = url;
          break;
      }
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
          'thumbnail_url': await _getFlashcard1Path(
            lessonId: lessonId,
            folderName: folderName,
          ),
        })
        .eq('id', lessonId);

    await _supabase.from('lesson_infographics').insert({
      'lesson_id': lessonId,
      'image_url_es': infographicEs,
      'image_url_en': infographicEn,
      'audio_url_es': audioEs,
      'audio_url_en': audioEn,
    });

    return 'Multimedia subida correctamente.';
  }

  Future<String?> _getFlashcard1Path({
  required String lessonId,
  required String folderName,
}) async {
  final lessonResponse = await _supabase
      .from('lessons')
      .select('topic_id, title_es')
      .eq('id', lessonId)
      .single();

  final topicResponse = await _supabase
      .from('topics')
      .select('slug, name_es')
      .eq('id', lessonResponse['topic_id'])
      .single();

  var topicSlug = topicResponse['slug']?.toString();

  if (topicSlug == null || topicSlug.isEmpty) {
    topicSlug = _slugify(
      topicResponse['name_es']?.toString() ?? '',
    );
  }

  final lessonSlug = _slugify(
    lessonResponse['title_es']?.toString() ?? '',
  );

  if (topicSlug.isEmpty || lessonSlug.isEmpty) {
    return null;
  }

  return '$topicSlug/$lessonSlug/Flashcard1.png';
}

  String _slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
