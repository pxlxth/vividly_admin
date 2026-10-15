import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/excel_import.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/admin_sidebar.dart';
import '../../services/multimedia_import_service.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:video_player/video_player.dart';
import 'dart:html' as html;
import 'package:audioplayers/audioplayers.dart';
import '../../services/multimedia_import_draft_service.dart';
import 'package:file_picker/file_picker.dart';

class LessonReviewResult {
  final List<ExcelLessonData> lessons;
  final List<MultimediaLessonDraft> drafts;

  LessonReviewResult({
    required this.lessons,
    required this.drafts,
  });
}

class LessonReviewScreen extends StatefulWidget {
  final List<ExcelLessonData> lessons;
  final int initialIndex;
  final List<MultimediaLessonPreview> multimediaPreviews;
  final List<Uint8List> multimediaZipBytes;

  const LessonReviewScreen({
    super.key,
    required this.lessons,
    required this.initialIndex,
    required this.multimediaPreviews,
    required this.multimediaZipBytes,
  });

  @override
  State<LessonReviewScreen> createState() => _LessonReviewScreenState();
}

class _LessonReviewScreenState extends State<LessonReviewScreen> {
  late int _currentIndex;
  final _draftService = MultimediaImportDraftService.instance;
  final Map<String, List<QuizData>> _addedFinalQuizEs = {};
  final Map<String, List<QuizData>> _addedFinalQuizEn = {};
  final Map<String, Map<int, QuizData>> _editedInitialQuizEs = {};
  final Map<String, Map<int, QuizData>> _editedInitialQuizEn = {};

  final Map<String, Map<int, QuizData>> _editedFinalQuizEs = {};
  final Map<String, Map<int, QuizData>> _editedFinalQuizEn = {};
  ExcelLessonData _buildLessonForImport(ExcelLessonData lesson) {
    final lessonId = _normalize(lesson.titleEs);
    final initialQuizEs = List<QuizData>.generate(
      lesson.initialQuizEs.length,
      (index) =>
          _editedInitialQuizEs[lessonId]?[index] ??
          lesson.initialQuizEs[index],
    );

    final initialQuizEn = List<QuizData>.generate(
      lesson.initialQuizEn.length,
      (index) =>
          _editedInitialQuizEn[lessonId]?[index] ??
          lesson.initialQuizEn[index],
    );

    final finalQuizEs = <QuizData>[];

    for (int index = 0; index < lesson.finalQuizEs.length; index++) {
      finalQuizEs.add(
        _editedFinalQuizEs[lessonId]?[index] ??
            lesson.finalQuizEs[index],
      );
    }

    final finalQuizEn = <QuizData>[];

    for (int index = 0; index < lesson.finalQuizEn.length; index++) {
      finalQuizEn.add(
        _editedFinalQuizEn[lessonId]?[index] ??
            lesson.finalQuizEn[index],
      );
    }

    finalQuizEs.addAll(
      _addedFinalQuizEs[lessonId] ?? [],
    );

    finalQuizEn.addAll(
      _addedFinalQuizEn[lessonId] ?? [],
    );

    return ExcelLessonData(
      topicEs: lesson.topicEs,
      topicEn: lesson.topicEn,
      titleEs: lesson.titleEs,
      titleEn: lesson.titleEn,
      subtitleEs: lesson.subtitleEs,
      subtitleEn: lesson.subtitleEn,
      witnessNameEs: lesson.witnessNameEs,
      witnessNameEn: lesson.witnessNameEn,
      initialQuizEs: initialQuizEs,
      initialQuizEn: initialQuizEn,
      finalQuizEs: finalQuizEs,
      finalQuizEn: finalQuizEn,
      flashcardsEs: lesson.flashcardsEs,
      flashcardsEn: lesson.flashcardsEn,
      warnings: lesson.warnings,
    );
  }
 Archive? _decodedArchive;
  final Map<String, Map<String, ArchiveFile>> _lessonFileIndexes = {};
 
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    for (final lesson in widget.lessons) {
      final multimedia = _getMultimediaForLesson(lesson);

     _draftService.createLessonDraft(
        lessonId: _normalize(lesson.titleEs),
        folderName: multimedia?.folderName ?? '',
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String _formatVideoDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('_media', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Archive? _getDecodedArchive() {
    if (_decodedArchive != null) {
      return _decodedArchive;
    }

    if (widget.multimediaZipBytes.isEmpty) {
      return null;
    }

    final mergedArchive = Archive();

    for (final zipBytes in widget.multimediaZipBytes) {
      if (zipBytes.isEmpty) {
        continue;
      }

      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        mergedArchive.addFile(file);
      }
    }

    _decodedArchive = mergedArchive;

    return _decodedArchive;
  }

ArchiveFile? _findMultimediaFile(
  Archive archive,
  String folderName,
  String fileName,
) {
  final lessonKey = _normalize(folderName);

  final existingIndex = _lessonFileIndexes[lessonKey];

  if (existingIndex != null) {
    return existingIndex[fileName.toLowerCase()];
  }

  final index = _buildMultimediaFileIndex(
    archive,
    folderName,
  );

  _lessonFileIndexes[lessonKey] = index;

  return index[fileName.toLowerCase()];
}

  Map<String, ArchiveFile> _buildMultimediaFileIndex(
  Archive archive,
  String folderName,
) {
  final index = <String, ArchiveFile>{};

  final targetFolder = _normalize(folderName);

  // Archivos directos del ZIP principal.
  for (final file in archive.files) {
    if (!file.isFile) continue;

    final parts = file.name
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2) continue;

    final currentFolder = _normalize(
      parts[parts.length - 2],
    );

    if (currentFolder != targetFolder) continue;

    final fileName = parts.last.toLowerCase();

    index[fileName] = file;
  }

  // Buscar SOLO el ZIP interno de esta lección.
  for (final outerFile in archive.files) {
    if (!outerFile.isFile) continue;

    if (!outerFile.name.toLowerCase().endsWith('.zip')) {
      continue;
    }

    final zipName = outerFile.name
        .split('/')
        .where((part) => part.isNotEmpty)
        .last
        .replaceAll(
          RegExp(r'\.zip$', caseSensitive: false),
          '',
        );

    final normalizedZipName = _normalize(zipName);

    if (normalizedZipName != targetFolder) {
      continue;
    }

    try {
      final innerArchive = ZipDecoder().decodeBytes(
        Uint8List.fromList(outerFile.content),
      );

      for (final innerFile in innerArchive.files) {
        if (!innerFile.isFile) continue;

        final fileName = innerFile.name
            .split('/')
            .where((part) => part.isNotEmpty)
            .last
            .toLowerCase();

        index[fileName] = innerFile;
      }
    } catch (_) {
      // ZIP interno inválido.
    }

    break;
  }

  return index;
}

  MultimediaLessonPreview? _getMultimediaForLesson(ExcelLessonData lesson) {
    final spanishName = _normalize(lesson.titleEs);
    final englishName = _normalize(lesson.titleEn);

    for (final preview in widget.multimediaPreviews) {
      final folderName = _normalize(preview.folderName);

      if ((spanishName.isNotEmpty &&
              (folderName.contains(spanishName) ||
                  spanishName.contains(folderName))) ||
          (englishName.isNotEmpty &&
              (folderName.contains(englishName) ||
                  englishName.contains(folderName)))) {
        return preview;
      }
    }

    return null;
  }

  Future<void> _addMissingMultimedia(
    ExcelLessonData lesson,
    String fileName,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        fileName.toLowerCase().endsWith('.mp4')
            ? 'mp4'
            : fileName.toLowerCase().endsWith('.wav')
                ? 'wav'
                : fileName.toLowerCase().endsWith('.mp3')
                    ? 'mp3'
                    : 'png',
      ],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    final selectedFile = result.files.single;

    final expectedExtension =
        fileName.split('.').last.toLowerCase();

    final selectedExtension =
        selectedFile.name.split('.').last.toLowerCase();

    if (expectedExtension != selectedExtension) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El archivo debe tener formato .$expectedExtension.',
          ),
        ),
      );

      return;
    }

    _draftService.addOrReplaceFile(
      lessonId: _normalize(lesson.titleEs),
      fileName: fileName,
      bytes: selectedFile.bytes!,
      fromOriginalZip: false,
    );

    if (!mounted) return;

    setState(() {});
  }

  String _getExpectedVideoFileName(
  String title,
  String language,
) {
  final isSpanish = language == 'Español';

  if (title == 'Video introductorio') {
    return isSpanish
        ? 'intro_es.mp4'
        : 'intro_en.mp4';
  }

  if (title == 'Introductory video') {
    return 'intro_en.mp4';
  }

  if (title == 'Protagonista' || title == 'Protagonist') {
    return isSpanish
        ? 'protagonist_es.mp4'
        : 'protagonist_en.mp4';
  }

  if (title == 'Testigo' || title == 'Witness') {
    return isSpanish
        ? 'witness_es.mp4'
        : 'witness_en.mp4';
  }

  return '';
}

  Future<void> _addMissingMultimediaByLessonId(
    String lessonId,
    String fileName,
  ) async {
    if (fileName.isEmpty) return;

    final extension = fileName.split('.').last.toLowerCase();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [extension],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    final selectedFile = result.files.single;

    final selectedExtension =
        selectedFile.name.split('.').last.toLowerCase();

    if (selectedExtension != extension) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El archivo debe tener formato .$extension.',
          ),
        ),
      );

      return;
    }

    _draftService.addOrReplaceFile(
      lessonId: lessonId,
      fileName: fileName,
      bytes: selectedFile.bytes!,
      fromOriginalZip: false,
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _replaceMultimedia(
    String lessonId,
    String fileName,
  ) async {
    final extension = fileName.split('.').last.toLowerCase();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [extension],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    final selectedFile = result.files.single;

    final selectedExtension =
        selectedFile.name.split('.').last.toLowerCase();

    if (selectedExtension != extension) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El archivo debe tener formato .$extension.',
          ),
        ),
      );

      return;
    }

    _draftService.addOrReplaceFile(
      lessonId: lessonId,
      fileName: fileName,
      bytes: selectedFile.bytes!,
      fromOriginalZip: false,
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _addMissingAudio(
    String lessonId,
    String expectedFileName,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    final selectedFile = result.files.single;
    final selectedExtension =
        selectedFile.name.split('.').last.toLowerCase();

    if (selectedExtension != 'wav' && selectedExtension != 'mp3') {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El audio debe estar en formato .wav o .mp3.'),
        ),
      );

      return;
    }

    final finalFileName =
        expectedFileName.replaceFirst(
          RegExp(r'\.(wav|mp3)$', caseSensitive: false),
          '.$selectedExtension',
        );

    _draftService.addOrReplaceFile(
      lessonId: lessonId,
      fileName: finalFileName,
      bytes: selectedFile.bytes!,
      fromOriginalZip: false,
    );

    if (!mounted) return;

    setState(() {});
  }

  void _previousLesson() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _nextLesson() {
    if (_currentIndex < widget.lessons.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lessons[_currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AdminSidebar(
              selectedSection: 'lessons',
              onSectionSelected: (section) {
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: 'Volver',
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Revisar lección',
                                  style: AppTextStyles.h1.copyWith(
                                    color: AppColors.darkBrown,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Lección ${_currentIndex + 1} de ${widget.lessons.length}',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.black54,
                              ),
                            ),

                            const SizedBox(height: 30),
                            _buildLessonHeader(lesson),
                            const SizedBox(height: 30),
                            _buildVideoSection(lesson),
                            const SizedBox(height: 30),
                            _buildFlashcards(lesson),
                            const SizedBox(height: 30),
                            _buildInfographicSection(lesson),
                            const SizedBox(height: 30),
                            _buildInitialQuiz(lesson),
                            const SizedBox(height: 30),
                            _buildFinalQuiz(lesson),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),

                    _buildNavigation(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonHeader(ExcelLessonData lesson) {
    final multimedia = _getMultimediaForLesson(lesson);
    final multimediaWarnings = multimedia == null
    ? ['No se encontró multimedia asociada a esta lección.']
    : multimedia.warnings;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.titleEs.isEmpty ? '(Sin título)' : lesson.titleEs,
            style: AppTextStyles.h2.copyWith(color: AppColors.darkBrown),
          ),

          const SizedBox(height: 8),

          Text(
            lesson.titleEn.isEmpty ? '(Sin título en inglés)' : lesson.titleEn,
            style: AppTextStyles.body.copyWith(color: Colors.black54),
          ),

          const SizedBox(height: 20),

          _infoRow('Tópico', lesson.topicEs, lesson.topicEn),
          _infoRow('Subtítulo', lesson.subtitleEs, lesson.subtitleEn),
          _infoRow('Testigo', lesson.witnessNameEs, lesson.witnessNameEn),

          if (lesson.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _statusBox(
              icon: Icons.warning_amber_rounded,
              title: 'Advertencias',
              messages: lesson.warnings,
              color: Colors.orange,
            ),
          ],
          if (multimediaWarnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _statusBox(
              icon: Icons.video_library_outlined,
              title: 'Advertencias de multimedia',
              messages: multimediaWarnings,
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String valueEs, String valueEn) {
    if (valueEs.trim().isEmpty && valueEn.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          if (valueEs.trim().isNotEmpty)
            Text(
              '🇪🇸 $valueEs',
              style: AppTextStyles.body.copyWith(color: Colors.black54),
            ),
          if (valueEn.trim().isNotEmpty)
            Text(
              '🇺🇸 $valueEn',
              style: AppTextStyles.body.copyWith(color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _statusBox({
    required IconData icon,
    required String title,
    required List<String> messages,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $message',
                style: AppTextStyles.small.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard({
    required String title,
    required String language,
    required String? fileName,
    required String folderName,
    required String lessonId,
  }) {
    final available = fileName != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: available
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: available
              ? () {
                  _previewZipFile(
                    folderName,
                    fileName!,
                    lessonId: lessonId,
                  );
                }
              : null,
             child: SizedBox(
              width: 190,
              height: 110,
              child: _ZipVideoThumbnail(
                videoBytes: fileName == null
                    ? null
                    : _getZipFileBytes(
                        folderName,
                        fileName,
                        lessonId: lessonId,
                      ),
                folderName: folderName,
                fileName: fileName,
              ),
            ),
            ),
          ),

          const SizedBox(width: 16),

          // INFORMACIÓN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(color: AppColors.darkBrown),
                ),

                const SizedBox(height: 8),

                if (available) ...[
                Text(
                  fileName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small.copyWith(
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () {
                    _replaceMultimedia(
                      lessonId,
                      fileName!,
                    );
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Reemplazar'),
                ),
              ]
                else ...[
                  Text(
                    'Archivo no encontrado',
                    style: AppTextStyles.small.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () {
                      _addMissingMultimediaByLessonId(
                        lessonId,
                        _getExpectedVideoFileName(title, language),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildVideoSection(ExcelLessonData lesson) {
      final multimedia = _getMultimediaForLesson(lesson);

    String? findFile(String expectedName) {
    final lessonId = _normalize(lesson.titleEs);

    // 1. Primero buscamos una modificación temporal del draft.
    final draftFiles = _draftService.getFileNames(lessonId);

    for (final file in draftFiles) {
      if (file.toLowerCase() == expectedName.toLowerCase()) {
        return file;
      }
    }

    // 2. Si existe multimedia original, buscamos ahí.
    if (multimedia != null) {
      for (final file in multimedia.files) {
        if (file.toLowerCase() == expectedName.toLowerCase()) {
          return file;
        }
      }
    }

    // 3. Si no existe, devolvemos null para mostrar "Añadir".
    return null;
  }

   final introEs =
    findFile('intro_es.mp4') ??
    findFile('Introductory video spanish.mp4');

    final introEn =
    findFile('intro_en.mp4') ??
    findFile('Introductory video english.mp4');

    final protagonistEs = findFile('protagonist_es.mp4');
    final protagonistEn = findFile('protagonist_en.mp4');

    final witnessEs = findFile('witness_es.mp4');
    final witnessEn = findFile('witness_en.mp4');

    return _buildSection(
      title: 'Video',
      icon: Icons.play_circle_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildVideoLanguageColumn(
              language: 'Español',
              flag: '🇪🇸',
              videos: [
                {'title': 'Video introductorio', 'file': introEs},
                {'title': 'Protagonista', 'file': protagonistEs},
                {'title': 'Testigo', 'file': witnessEs},
              ],
              folderName: multimedia?.folderName ?? '',
              lessonId: _normalize(lesson.titleEs),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: _buildVideoLanguageColumn(
              language: 'English',
              flag: '🇺🇸',
              videos: [
                {'title': 'Introductory video', 'file': introEn},
                {'title': 'Protagonist', 'file': protagonistEn},
                {'title': 'Witness', 'file': witnessEn},
              ],
              folderName: multimedia?.folderName ?? '',
              lessonId: _normalize(lesson.titleEs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLanguageColumn({
    required String language,
    required String flag,
    required List<Map<String, dynamic>> videos,
    required String folderName,
    required String lessonId,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ENCABEZADO DEL IDIOMA
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(
                language,
                style: AppTextStyles.h2.copyWith(color: AppColors.darkBrown),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // VIDEOS
          ...videos.map((video) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildVideoCard(
                title: video['title'] as String,
                language: language,
                fileName: video['file'] as String?,
                folderName: folderName,
                lessonId: lessonId,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMultimediaFileRow(String folderName, String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    final isImage =
        extension == 'png' || extension == 'jpg' || extension == 'jpeg';

    final isVideo = extension == 'mp4';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isImage
                ? Icons.image_outlined
                : isVideo
                ? Icons.play_circle_outline
                : Icons.audio_file_outlined,
            color: AppColors.green,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              style: AppTextStyles.body.copyWith(color: AppColors.darkBrown),
            ),
          ),
          if (isImage || isVideo)
            TextButton.icon(
              onPressed: () => _previewZipFile(
                folderName,
                fileName!,
                //lessonId: lessonId,
              ),
              icon: Icon(
                isImage ? Icons.visibility_outlined : Icons.play_arrow,
              ),
              label: Text(isImage ? 'Ver' : 'Reproducir'),
            )
          else
            TextButton.icon(
              onPressed: () => _previewZipAudio(folderName, fileName),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Escuchar'),
            ),
        ],
      ),
    );
  }

  Future<void> _previewZipFile(
    String folderName,
    String fileName, {
    String? lessonId,
  }) async {
    final bytes = _getZipFileBytes(folderName, fileName, lessonId: lessonId);

    if (bytes.isEmpty) {
      throw Exception('No se encontró "$fileName" en "$folderName".');
    }

    final extension = fileName.split('.').last.toLowerCase();

    if (extension == 'png' || extension == 'jpg' || extension == 'jpeg') {
      _showImagePreview(bytes, fileName);
      return;
    }

    if (extension == 'mp4') {
      _showVideoPreview(bytes, fileName);
    }
  }

  Future<void> _previewZipAudio(String folderName, String fileName) async {
    final zipBytes = widget.multimediaZipBytes;

    if (zipBytes == null) return;

   final archive = _getDecodedArchive();

    if (archive == null) return;

    final file = _findMultimediaFile(
      archive,
      folderName,
      fileName,
    );

    if (file == null) {
      return;
    }

    final bytes = Uint8List.fromList(file.content);

    final mimeType = fileName.toLowerCase().endsWith('.mp3')
        ? 'audio/mpeg'
        : 'audio/wav';

    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final player = AudioPlayer();

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              fileName,
              style: AppTextStyles.h2.copyWith(color: AppColors.darkBrown),
            ),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<Duration>(
                    stream: player.onDurationChanged,
                    builder: (context, durationSnapshot) {
                      final duration = durationSnapshot.data ?? Duration.zero;

                      return StreamBuilder<Duration>(
                        stream: player.onPositionChanged,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;

                          final max = duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1.0;

                          final value = position.inMilliseconds
                              .toDouble()
                              .clamp(0.0, max);

                          return Column(
                            children: [
                              Slider(
                                value: value,
                                min: 0,
                                max: max,
                                activeColor: AppColors.green,
                                inactiveColor: AppColors.green.withValues(
                                  alpha: 0.2,
                                ),
                                onChanged: duration == Duration.zero
                                    ? null
                                    : (newValue) {
                                        player.seek(
                                          Duration(
                                            milliseconds: newValue.toInt(),
                                          ),
                                        );
                                      },
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: AppTextStyles.small.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: AppTextStyles.small.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              StreamBuilder<PlayerState>(
                                stream: player.onPlayerStateChanged,
                                builder: (context, stateSnapshot) {
                                  final isPlaying =
                                      stateSnapshot.data == PlayerState.playing;

                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.green,
                                    ),
                                    child: IconButton(
                                      iconSize: 32,
                                      color: Colors.white,
                                      icon: Icon(
                                        isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                      onPressed: () async {
                                        if (isPlaying) {
                                          await player.pause();
                                        } else {
                                          await player.play(UrlSource(url));
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      await player.stop();
      await player.dispose();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _showImagePreview(Uint8List bytes, String fileName) {
    showDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.85,
              maxHeight: screenSize.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Flexible(child: Image.memory(bytes, fit: BoxFit.contain)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVideoPreview(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes], 'video/mp4');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        html.Url.revokeObjectUrl(url);
        return;
      }

      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 850,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.darkBrown,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxWidth = constraints.maxWidth;
                            final maxHeight =
                                MediaQuery.of(context).size.height * 0.55;

                            final videoWidth = maxWidth;
                            final videoHeight =
                                videoWidth / controller.value.aspectRatio;

                            final height = videoHeight > maxHeight
                                ? maxHeight
                                : videoHeight;

                            return SizedBox(
                              width: videoWidth,
                              height: height,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: controller.value.size.width,
                                  height: controller.value.size.height,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          final duration = value.duration;
                          final position = value.position;

                          final max = duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1.0;

                          final current = position.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble();

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.green,
                                  inactiveTrackColor: AppColors.green
                                      .withValues(alpha: 0.18),
                                  thumbColor: AppColors.green,
                                  overlayColor: AppColors.green.withValues(
                                    alpha: 0.10,
                                  ),
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                ),
                                child: Slider(
                                  min: 0,
                                  max: max,
                                  value: current,
                                  onChanged: duration.inMilliseconds > 0
                                      ? (newValue) {
                                          controller.seekTo(
                                            Duration(
                                              milliseconds: newValue.toInt(),
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              ),

                              // TIEMPO ACTUAL / DURACIÓN
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatVideoDuration(position),
                                    style: AppTextStyles.small.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    _formatVideoDuration(duration),
                                    style: AppTextStyles.small.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          return Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 30,
                              color: Colors.white,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              onPressed: () {
                                if (value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
      html.Url.revokeObjectUrl(url);
    }
  }

  Widget _multimediaRow(String name, dynamic url) {
    final available = url != null && url.toString().trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.radio_button_unchecked,
            color: available ? AppColors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            available ? 'Disponible' : 'No disponible',
            style: AppTextStyles.small.copyWith(
              color: available ? AppColors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfographicSection(ExcelLessonData lesson) {
    final multimedia = _getMultimediaForLesson(lesson);
    final lessonId = _normalize(lesson.titleEs);

    String? findFile(String language, String type) {
      // 1. Buscar primero archivos añadidos temporalmente.
      final draftFiles = _draftService.getFileNames(lessonId);

      for (final file in draftFiles) {
        final name = file.toLowerCase();

        if (type == 'audio') {
          if (language == 'es' &&
              (name == 'infographic_audio_es.wav' ||
                  name == 'infographic_audio_es.mp3')) {
            return file;
          }

          if (language == 'en' &&
              (name == 'infographic_audio_en.wav' ||
                  name == 'infographic_audio_en.mp3')) {
            return file;
          }
        }

        if (type == 'image') {
          if (language == 'es' && name == 'infographic_es.png') {
            return file;
          }

          if (language == 'en' && name == 'infographic_en.png') {
            return file;
          }
        }
      }

      // 2. Buscar en el ZIP original solamente si existe multimedia.
      if (multimedia != null) {
        for (final file in multimedia.files) {
          final name = file.toLowerCase();

          if (type == 'image') {
            if (language == 'es' && name == 'infographic_es.png') {
              return file;
            }

            if (language == 'en' && name == 'infographic_en.png') {
              return file;
            }
          }

          if (type == 'audio') {
            if (language == 'es' &&
                (name == 'infographic_audio_es.wav' ||
                    name == 'infographic_audio_es.mp3')) {
              return file;
            }

            if (language == 'en' &&
                (name == 'infographic_audio_en.wav' ||
                    name == 'infographic_audio_en.mp3')) {
              return file;
            }
          }
        }
      }

      return null;
    }

    final infographicEs = findFile('es', 'image');
    final infographicEn = findFile('en', 'image');

    final audioEs = findFile('es', 'audio');
    final audioEn = findFile('en', 'audio');

    return _buildSection(
      title: 'Infografía',
      icon: Icons.image_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildInfographicLanguageCard(
              language: 'Español',
              infographicFile: infographicEs,
              audioFile: audioEs,
              folderName: multimedia?.folderName ?? '',
              lessonId: lessonId,
              lesson: lesson,
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: _buildInfographicLanguageCard(
              language: 'English',
              infographicFile: infographicEn,
              audioFile: audioEn,
              folderName: multimedia?.folderName ?? '',
              lessonId: lessonId,
              lesson: lesson,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfographicLanguageCard({
    required String language,
    required String? infographicFile,
    required String? audioFile,
    required String folderName,
    required String lessonId,
    required ExcelLessonData lesson,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                language == 'Español' ? '🇪🇸' : '🇺🇸',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                language,
                style: AppTextStyles.h3.copyWith(color: AppColors.darkBrown),
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (infographicFile != null)
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildZipImage(folderName, infographicFile,lessonId,),
                ),
              ),
            )
            else
              Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_not_supported_outlined,
                      size: 42,
                      color: Colors.orange,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      language == 'Español'
                          ? 'Falta infographic_es.png'
                          : 'Falta infographic_en.png',
                      style: AppTextStyles.small.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: () {
                        final fileName = language == 'Español'
                            ? 'infographic_es.png'
                            : 'infographic_en.png';

                        _addMissingMultimedia(
                          lesson,
                          fileName,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                  ],
                ),
              ),

          const SizedBox(height: 12),

          if (infographicFile != null) ...[
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _previewZipFile(
                      folderName,
                      infographicFile,
                      lessonId: lessonId,
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver completa'),
                ),

                const SizedBox(width: 10),

                OutlinedButton.icon(
                  onPressed: () {
                    _replaceMultimedia(
                      lessonId,
                      infographicFile,
                    );
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Reemplazar'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 15),

         if (audioFile != null) ...[
              _InlineAudioPlayer(
                audioBytes: _getZipFileBytes(
                  folderName,
                  audioFile,
                  lessonId: lessonId,
                ),
                fileName: audioFile,
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: () {
                  _addMissingAudio(
                    lessonId,
                    audioFile,
                  );
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Reemplazar audio'),
              ),
            ]
            
          else ...[
            Text(
              'Audio no disponible',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () {
                final expectedAudioName =
                    language == 'Español'
                        ? 'infographic_audio_es.wav'
                        : 'infographic_audio_en.wav';

                _addMissingAudio(
                  lessonId,
                  expectedAudioName,
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Añadir audio'),
            ),
          ],
        ],
      ),
    );
  }

  Uint8List _getOriginalZipFileBytes(String folderName, String fileName) {
   final archive = _getDecodedArchive();

  if (archive == null) {
    return Uint8List(0);
  }

    final file = _findMultimediaFile(archive, folderName, fileName);

    if (file == null) {
      return Uint8List(0);
    }

    return Uint8List.fromList(file.content);
  }

  Uint8List _getZipFileBytes(
    String folderName,
    String fileName, {
    String? lessonId,
  }) {
    if (lessonId != null) {
      final draftFile = _draftService.getFile(
        lessonId: lessonId,
        fileName: fileName,
      );

      if (draftFile != null) {
        return draftFile;
      }
    }

    return _getOriginalZipFileBytes(folderName, fileName);
  }

  Widget _buildZipImage(
    String folderName,
    String fileName,
    String lessonId,
  ) {
    final bytes = _getZipFileBytes(
      folderName,
      fileName,
      lessonId: lessonId,
    );

    if (bytes.isEmpty) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 42,
        ),
      );
    }

    return Image.memory(
      bytes,
      fit: BoxFit.contain,
    );
  }

Widget _buildInitialQuiz(ExcelLessonData lesson) {
  final lessonId = _normalize(lesson.titleEs);

  return _buildSection(
    title: 'Test inicial',
    icon: Icons.quiz_outlined,
    child: lesson.initialQuizEs.isEmpty
        ? _emptyMessage('No hay preguntas del test inicial.')
        : Column(
            children: List.generate(
              lesson.initialQuizEs.length,
              (index) {
                final originalEs = lesson.initialQuizEs[index];
                final originalEn =
                    index < lesson.initialQuizEn.length
                        ? lesson.initialQuizEn[index]
                        : null;

                final quizEs =
                    _editedInitialQuizEs[lessonId]?[index] ?? originalEs;

                final quizEn =
                    _editedInitialQuizEn[lessonId]?[index] ?? originalEn;

                return _buildQuizQuestion(
                  index + 1,
                  quizEs,
                  quizEn,
                  lesson,
                  false,
                  index,
                );
              },
            ),
          ),
  );
}

  Widget _buildFlashcards(ExcelLessonData lesson) {
   if (lesson.flashcardsEs.isEmpty) {
    return _buildSection(
      title: 'Flashcards',
      icon: Icons.style_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 24) / 3;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(3, (index) {
              final expectedName = 'flashcard${index + 1}.png';

              final draftFile = _draftService.getFile(
                lessonId: _normalize(lesson.titleEs),
                fileName: expectedName,
              );

              final hasFile =
                  draftFile != null && draftFile.isNotEmpty;

              return SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flashcard ${index + 1}',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                        child: hasFile
                            ? Image.memory(
                                _getZipFileBytes(
                                  '',
                                  expectedName,
                                  lessonId: _normalize(lesson.titleEs),
                                ),
                                fit: BoxFit.contain,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        hasFile
                            ? 'Imagen añadida'
                            : 'No hay imagen',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.darkBrown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (!hasFile)
                        Text(
                          'No se encontró esta flashcard.',
                          style: AppTextStyles.small.copyWith(
                            color: Colors.black54,
                          ),
                        ),

                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: () {
                          if (hasFile) {
                            _replaceMultimedia(
                              _normalize(lesson.titleEs),
                              expectedName,
                            );
                          } else {
                            _addMissingMultimedia(
                              lesson,
                              expectedName,
                            );
                          }
                        },
                        icon: Icon(
                          hasFile
                              ? Icons.swap_horiz
                              : Icons.add,
                        ),
                        label: Text(
                          hasFile
                              ? 'Reemplazar'
                              : 'Añadir',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

    return _buildSection(
      title: 'Flashcards',
      icon: Icons.style_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 24) / 3;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(lesson.flashcardsEs.length, (index) {
              final flashcardEs = lesson.flashcardsEs[index];

              final FlashcardData? flashcardEn =
                  index < lesson.flashcardsEn.length
                  ? lesson.flashcardsEn[index]
                  : null;
             final multimedia = _getMultimediaForLesson(lesson);

              final expectedName = 'flashcard${index + 1}.png';

              final draftFile = _draftService.getFile(
                lessonId: _normalize(lesson.titleEs),
                fileName: expectedName,
              );

              String? flashcardImage;

              if (draftFile != null && draftFile.isNotEmpty) {
                flashcardImage = expectedName;
              } else if (multimedia != null) {
                for (final file in multimedia.files) {
                  if (file.toLowerCase() == expectedName) {
                    flashcardImage = file;
                    break;
                  }
                }
              }

              return SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                    child: flashcardImage != null
                    ? Image.memory(
                        _getZipFileBytes(
                          multimedia?.folderName ?? '',
                          flashcardImage,
                          lessonId: _normalize(lesson.titleEs),
                        ),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.contain,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_not_supported_outlined,
                            size: 42,
                            color: Colors.orange,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Falta $expectedName',
                            style: AppTextStyles.small.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 10),

                          OutlinedButton.icon(
                            onPressed: () {
                              _addMissingMultimedia(
                                lesson,
                                expectedName,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                      if (flashcardImage != null) ...[
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: () {
                        _replaceMultimedia(
                          _normalize(lesson.titleEs),
                          expectedName,
                        );
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Reemplazar'),
                    ),
                  ],
                      Text(
                        'Flashcard ${index + 1}',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '🇪🇸 ${flashcardEs.title}',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.darkBrown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        flashcardEs.content,
                        style: AppTextStyles.small.copyWith(
                          color: Colors.black54,
                        ),
                      ),

                      if (flashcardEn != null) ...[
                        const SizedBox(height: 14),

                        Text(
                          '🇺🇸 ${flashcardEn.title}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.darkBrown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          flashcardEn.content,
                          style: AppTextStyles.small.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

Widget _buildFinalQuiz(ExcelLessonData lesson) {
  final lessonId = _normalize(lesson.titleEs);

  final addedEs =
      _addedFinalQuizEs[lessonId] ?? [];

  final addedEn =
      _addedFinalQuizEn[lessonId] ?? [];

  final totalQuestions =
      lesson.finalQuizEs.length + addedEs.length;

  return _buildSection(
    title: 'Test final',
    icon: Icons.fact_check_outlined,
    child: totalQuestions == 0
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.quiz_outlined,
                  size: 42,
                  color: Colors.orange,
                ),

                const SizedBox(height: 10),

                Text(
                  'No hay test final para esta lección.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 14),

                OutlinedButton.icon(
                  onPressed: () {
                    _showAddFinalQuizDialog(lesson);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir pregunta'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              ...List.generate(
                lesson.finalQuizEs.length,
                (index) {
                 final originalEs = lesson.finalQuizEs[index];

                final originalEn =
                    index < lesson.finalQuizEn.length
                        ? lesson.finalQuizEn[index]
                        : null;

                final quizEs =
                    _editedFinalQuizEs[lessonId]?[index] ?? originalEs;

                final quizEn =
                    _editedFinalQuizEn[lessonId]?[index] ?? originalEn;

                  return _buildQuizQuestion(
                    index + 1,
                    quizEs,
                    quizEn,
                    lesson,
                    true,
                    index,
                  );
                },
              ),

              ...List.generate(
                addedEs.length,
                (index) {
                  final quizEs = addedEs[index];

                  final QuizData? quizEn =
                      index < addedEn.length
                          ? addedEn[index]
                          : null;

                  return _buildQuizQuestion(
                    lesson.finalQuizEs.length + index + 1,
                    quizEs,
                    quizEn,
                    lesson,
                    true,
                    lesson.finalQuizEs.length + index,
                  );
                },
              ),

              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: () {
                  _showAddFinalQuizDialog(lesson);
                },
                icon: const Icon(Icons.add),
                label: const Text('Añadir pregunta'),
              ),
            ],
          ),
  );
}

  Future<void> _showAddFinalQuizDialog(
    ExcelLessonData lesson,
  ) async {
    final questionEsController = TextEditingController();
    final questionEnController = TextEditingController();

    final answerEsControllers = List.generate(
      4,
      (_) => TextEditingController(),
    );

    final answerEnControllers = List.generate(
      4,
      (_) => TextEditingController(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Añadir pregunta al test final'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pregunta',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: questionEsController,
                    decoration: const InputDecoration(
                      labelText: 'Pregunta en español',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: questionEnController,
                    decoration: const InputDecoration(
                      labelText: 'Pregunta en inglés',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Respuestas',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'La primera respuesta será la correcta.',
                    style: AppTextStyles.small.copyWith(
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ...List.generate(4, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == 0
                                  ? AppColors.green
                                  : Colors.grey.shade300,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: index == 0
                                    ? Colors.white
                                    : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: TextField(
                              controller: answerEsControllers[index],
                              decoration: InputDecoration(
                                labelText:
                                    'Respuesta ${index + 1} ES',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: TextField(
                              controller: answerEnControllers[index],
                              decoration: InputDecoration(
                                labelText:
                                    'Respuesta ${index + 1} EN',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),

            ElevatedButton(
              onPressed: () {
                final questionEs =
                    questionEsController.text.trim();

                final questionEn =
                    questionEnController.text.trim();

                final answersEs = answerEsControllers
                    .map((controller) => controller.text.trim())
                    .where((answer) => answer.isNotEmpty)
                    .toList();

                final answersEn = answerEnControllers
                    .map((controller) => controller.text.trim())
                    .where((answer) => answer.isNotEmpty)
                    .toList();

                if (questionEs.isEmpty ||
                    questionEn.isEmpty ||
                    answersEs.length < 2 ||
                    answersEn.length < 2) {
                  return;
                }

                _addedFinalQuizEs
                    .putIfAbsent(
                      _normalize(lesson.titleEs),
                      () => [],
                    )
                    .add(
                      QuizData(
                        question: questionEs,
                        answers: answersEs,
                      ),
                    );

                _addedFinalQuizEn
                    .putIfAbsent(
                      _normalize(lesson.titleEs),
                      () => [],
                    )
                    .add(
                      QuizData(
                        question: questionEn,
                        answers: answersEn,
                      ),
                    );

                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Añadir pregunta'),
            ),
          ],
        );
      },
    );

    for (final controller in [
      questionEsController,
      questionEnController,
      ...answerEsControllers,
      ...answerEnControllers,
    ]) {
      controller.dispose();
    }

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _showEditQuizDialog(
    ExcelLessonData lesson,
    QuizData quizEs,
    QuizData? quizEn,
    bool isFinalQuiz,
    int index,
  ) async {
    final questionEsController =
        TextEditingController(text: quizEs.question);

    final questionEnController =
        TextEditingController(text: quizEn?.question ?? '');

    final answersEsControllers = quizEs.answers
        .map((answer) => TextEditingController(text: answer))
        .toList();

    final answersEnControllers = (quizEn?.answers ?? [])
        .map((answer) => TextEditingController(text: answer))
        .toList();

    while (answersEnControllers.length < answersEsControllers.length) {
      answersEnControllers.add(TextEditingController());
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isFinalQuiz
                ? 'Editar pregunta del quiz final'
                : 'Editar pregunta del quiz inicial',
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Español',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: questionEsController,
                    decoration: const InputDecoration(
                      labelText: 'Pregunta',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  ...List.generate(
                    answersEsControllers.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: answersEsControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Respuesta ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'English',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: questionEnController,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  ...List.generate(
                    answersEsControllers.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: answersEnControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Answer ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

      if (result != true) return;

      final editedEs = QuizData(
        question: questionEsController.text.trim(),
        answers: answersEsControllers
            .map((controller) => controller.text.trim())
            .where((answer) => answer.isNotEmpty)
            .toList(),
      );

      final editedEn = QuizData(
        question: questionEnController.text.trim(),
        answers: answersEnControllers
            .map((controller) => controller.text.trim())
            .where((answer) => answer.isNotEmpty)
            .toList(),
      );

      final lessonId = _normalize(lesson.titleEs);

      setState(() {
        if (isFinalQuiz) {
          _editedFinalQuizEs
              .putIfAbsent(lessonId, () => {})[index] = editedEs;

          _editedFinalQuizEn
              .putIfAbsent(lessonId, () => {})[index] = editedEn;
        } else {
          _editedInitialQuizEs
              .putIfAbsent(lessonId, () => {})[index] = editedEs;

          _editedInitialQuizEn
              .putIfAbsent(lessonId, () => {})[index] = editedEn;
        }
      });

    for (final controller in [
      questionEsController,
      questionEnController,
      ...answersEsControllers,
      ...answersEnControllers,
    ]) {
      controller.dispose();
    }
  }

  Widget _buildQuizQuestion(
    int number,
    QuizData quizEs,
    QuizData? quizEn,
    ExcelLessonData lesson,
    bool isFinalQuiz,
    int index,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pregunta $number',
            style: AppTextStyles.small.copyWith(
              color: AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: () {
              _showEditQuizDialog(
                lesson,
                quizEs,
                quizEn,
                isFinalQuiz,
                index,
              );
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),

          const SizedBox(height: 10),

          Text(
            '🇪🇸 ${quizEs.question}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (quizEn != null) ...[
            const SizedBox(height: 6),
            Text(
              '🇺🇸 ${quizEn.question}',
              style: AppTextStyles.body.copyWith(
                color: Colors.black54,
              ),
            ),
          ],

          const SizedBox(height: 14),

          ...List.generate(quizEs.answers.length, (index) {
            final isCorrect = index == 0;

            final answerEn =
                quizEn != null && index < quizEn.answers.length
                    ? quizEn.answers[index]
                    : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 20,
                    color: isCorrect
                        ? AppColors.green
                        : Colors.black38,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🇪🇸 ${quizEs.answers[index]}',
                          style: AppTextStyles.body.copyWith(
                            color: isCorrect
                                ? AppColors.green
                                : Colors.black54,
                            fontWeight: isCorrect
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),

                        if (answerEn != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '🇺🇸 $answerEn',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.green),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.h2.copyWith(color: AppColors.darkBrown),
            ),
          ],
        ),

        const SizedBox(height: 16),

        child,
      ],
    );
  }

  Widget _emptyMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: AppTextStyles.body.copyWith(color: Colors.black54),
      ),
    );
  }

  void _finishReview() {
    final reviewedLessons = widget.lessons
        .map(_buildLessonForImport)
        .toList();

    Navigator.pop(
      context,
      LessonReviewResult(
        lessons: reviewedLessons,
        drafts: _draftService.allDrafts,
      ),
    );
  }

  Widget _buildNavigation() {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == widget.lessons.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: isFirst ? null : _previousLesson,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Anterior'),
          ),

          const Spacer(),

          Text(
            '${_currentIndex + 1} de ${widget.lessons.length}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          if (!isLast)
            ElevatedButton.icon(
              onPressed: _nextLesson,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Siguiente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _finishReview,
              icon: const Icon(Icons.check),
              label: const Text('Finalizar revisión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineAudioPlayer extends StatefulWidget {
  final Uint8List audioBytes;
  final String fileName;

  const _InlineAudioPlayer({required this.audioBytes, required this.fileName});

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final AudioPlayer _player;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();

    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;

      setState(() {
        _duration = duration;
      });
    });

    _player.onPositionChanged.listen((position) {
      if (!mounted) return;

      setState(() {
        _position = position;
      });
    });

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      setState(() {
        _playerState = state;
      });
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        _position = _duration;
        _playerState = PlayerState.completed;
      });
    });
  }

  Future<void> _togglePlay() async {
    if (widget.audioBytes.isEmpty) return;

    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
        return;
      }

      if (_playerState == PlayerState.paused) {
        await _player.resume();
        return;
      }

      await _player.play(BytesSource(widget.audioBytes));
    } catch (e) {
      debugPrint('Error reproduciendo audio: $e');
    }
  }

  Future<void> _seek(double value) async {
    await _player.seek(Duration(milliseconds: value.toInt()));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;

    final value = _position.inMilliseconds.clamp(0, max.toInt()).toDouble();

    final isPlaying = _playerState == PlayerState.playing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _togglePlay,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.darkBrown, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.green,
              inactiveTrackColor: AppColors.green.withOpacity(0.15),
              thumbColor: AppColors.green,
              overlayColor: AppColors.green.withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              min: 0,
              max: max,
              value: value,
              onChanged: _duration.inMilliseconds > 0 ? _seek : null,
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZipVideoThumbnail extends StatefulWidget {
  final Uint8List? videoBytes;
  final String folderName;
  final String? fileName;

  const _ZipVideoThumbnail({
    required this.videoBytes,
    required this.folderName,
    required this.fileName,
  });

  @override
  State<_ZipVideoThumbnail> createState() => _ZipVideoThumbnailState();
}

class _ZipVideoThumbnailState extends State<_ZipVideoThumbnail> {
  VideoPlayerController? _controller;
  String? _url;
  bool _loading = true;
  bool _fileNotFound = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant _ZipVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.folderName != widget.folderName ||
        oldWidget.fileName != widget.fileName ||
        oldWidget.videoBytes != widget.videoBytes) {
      _controller?.dispose();

      if (_url != null) {
        html.Url.revokeObjectUrl(_url!);
      }

      _controller = null;
      _url = null;

      setState(() {
        _loading = true;
        _fileNotFound = false;
      });

      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    if (widget.videoBytes == null ||
        widget.videoBytes!.isEmpty ||
        widget.fileName == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fileNotFound = true;
        });
      }
      return;
    }

    final bytes = widget.videoBytes!;
    final blob = html.Blob([bytes], 'video/mp4');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        html.Url.revokeObjectUrl(url);
        return;
      }

      await controller.seekTo(Duration.zero);

      setState(() {
        _controller = controller;
        _url = url;
        _loading = false;
        _fileNotFound = false;
      });
    } catch (e) {
      controller.dispose();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        setState(() {
          _loading = false;
          _fileNotFound = true;
        });
      }

      debugPrint('Error cargando miniatura: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller?.dispose();

    if (_url != null) {
      html.Url.revokeObjectUrl(_url!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fileNotFound || controller == null
          ? const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 42,
              ),
            )
          : Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                ),

                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(controller!.value.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
    );
  }
}
