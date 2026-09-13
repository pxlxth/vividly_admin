import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../models/flashcard.dart';
import '../../services/flashcard_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback? onBack;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    this.onBack,
  });
 @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

  class _FlashcardsDialog extends StatefulWidget {
    final String lessonId;

    const _FlashcardsDialog({
      required this.lessonId,
    });

    @override
    State<_FlashcardsDialog> createState() => _FlashcardsDialogState();
  }

  class _FlashcardsDialogState extends State<_FlashcardsDialog> {
  final FlashcardService _flashcardService = FlashcardService();

  late Future<List<Flashcard>> _flashcardsFuture;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _flashcardsFuture =
        _flashcardService.getFlashcardsByLesson(
      widget.lessonId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 700,
        height: 500,
        child: FutureBuilder<List<Flashcard>>(
          future: _flashcardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No hay flashcards disponibles.',
                ),
              );
            }

            final flashcards = snapshot.data!;
            final flashcard = flashcards[_currentIndex];

            return Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Flashcards',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.darkBrown,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          if (flashcard.imageUrl != null &&
                              flashcard.imageUrl!.isNotEmpty)
                            Image.network(
                              Supabase.instance.client.storage
                                  .from('lesson-images')
                                  .getPublicUrl(flashcard.imageUrl!),
                              height: 180,
                              fit: BoxFit.contain,
                            ),

                          const SizedBox(height: 20),

                          Text(
                            flashcard.titleEs,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.darkBrown,
                            ),
                          ),

                          const SizedBox(height: 15),

                          Text(
                            flashcard.contentEs,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                        ),
                        onPressed: _currentIndex > 0
                            ? () {
                                setState(() {
                                  _currentIndex--;
                                });
                              }
                            : null,
                      ),

                      Text(
                        '${_currentIndex + 1} / ${flashcards.length}',
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                        ),
                        onPressed:
                            _currentIndex <
                                    flashcards.length - 1
                                ? () {
                                    setState(() {
                                      _currentIndex++;
                                    });
                                  }
                                : null,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _storageUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) {
      return '';
    }

    if (path.startsWith('http')) {
      return path;
    }

    return Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(path);
  }

  void _showThumbnail(BuildContext context) {
    final url = _storageUrl(
      'lesson-images',
      widget.lesson.thumbnailUrl,
    );

    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    height: 500,
                    width: 700,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVideo(BuildContext context, String? videoPath) {
    final url = _storageUrl(
      'lesson-videos',
      videoPath,
    );

    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return _VideoDialog(videoUrl: url);
      },
    );
  }

  void _showFlashcards(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _FlashcardsDialog(
        lessonId: widget.lesson.id,
      ),
    );
  }

  void _editFlashcards(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _EditFlashcardsDialog(
        lessonId: widget.lesson.id,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTextStyles.body.copyWith(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _infoRowButton(
    String label,
    String text,
    VoidCallback onPressed,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: onPressed,
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.darkBrown,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lecciones',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.darkBrown,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Text(
              widget.lesson.titleEs,
              style: AppTextStyles.h1.copyWith(
                color: AppColors.darkBrown,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Información de la lección',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.darkBrown,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _infoCard(
                    [
                      _infoRow(
                        'Nombre ES',
                        widget.lesson.titleEs,
                      ),
                      _infoRow(
                        'Nombre EN',
                        widget.lesson.titleEn,
                      ),
                      _infoRow(
                        'Subtítulo ES',
                        widget.lesson.subtitleEs ?? '-',
                      ),
                      _infoRow(
                        'Subtítulo EN',
                        widget.lesson.subtitleEn ?? '-',
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                Expanded(
                  child: _infoCard(
                    [
                      _infoRow(
                        'Estado',
                        widget.lesson.isPublished == true
                            ? 'Publicado'
                            : 'No publicado',
                      ),
                      _infoRow(
                        'Fecha de subida',
                        _formatDate(widget.lesson.createdAt),
                      ),
                      _infoRow(
                        'Nombre del testigo ES',
                        widget.lesson.witnessNameEs ?? '-',
                      ),
                      _infoRow(
                        'Nombre del testigo EN',
                        widget.lesson.witnessNameEn ?? '-',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Text(
              'Recursos multimedia',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.darkBrown,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _infoCard(
                    [
                    if (widget.lesson.thumbnailUrl != null &&
                      widget.lesson.thumbnailUrl!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Portada',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.darkBrown,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () => _showThumbnail(context),
                                child: Text(
                                  'Ver portada',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _infoRow(
                      'Portada',
                      '-',
                    ),
                      if (widget.lesson.introVideoUrlEs != null &&
                        widget.lesson.introVideoUrlEs!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Intro Video ES',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => _showVideo(
                                    context,
                                    widget.lesson.introVideoUrlEs,
                                  ),
                                  child: Text(
                                    'Ver video',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.darkBrown,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _infoRow(
                        'Intro Video ES',
                        '-',
                      ),
                      _infoRow(
                        'Intro Video EN',
                        widget.lesson.introVideoUrlEn ?? '-',
                      ),
                      
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                Expanded(
                  child: _infoCard(
                    [
                      
                     if (widget.lesson.witnessBaseVideoUrlEs != null &&
                      widget.lesson.witnessBaseVideoUrlEs!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Video Testigo ES',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.darkBrown,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () => _showVideo(
                                  context,
                                  widget.lesson.witnessBaseVideoUrlEs,
                                ),
                                child: Text(
                                  'Ver video',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _infoRow(
                      'Video Testigo ES',
                      '-',
                    ),
                     if (widget.lesson.witnessBaseVideoUrlEn != null &&
                        widget.lesson.witnessBaseVideoUrlEn!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Video Testigo EN',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => _showVideo(
                                    context,
                                    widget.lesson.witnessBaseVideoUrlEn,
                                  ),
                                  child: Text(
                                    'Ver video',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.darkBrown,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _infoRow(
                        'Video Testigo EN',
                        '-',
                      ),
                      if (widget.lesson.protagonistBaseVideoUrlEs != null &&
                        widget.lesson.protagonistBaseVideoUrlEs!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Video Protagonista ES',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => _showVideo(
                                    context,
                                    widget.lesson.protagonistBaseVideoUrlEs,
                                  ),
                                  child: Text(
                                    'Ver video',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.darkBrown,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _infoRow(
                        'Video Protagonista ES',
                        '-',
                      ),
                      if (widget.lesson.protagonistBaseVideoUrlEn != null &&
                        widget.lesson.protagonistBaseVideoUrlEn!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Video Protagonista EN',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => _showVideo(
                                    context,
                                    widget.lesson.protagonistBaseVideoUrlEn,
                                  ),
                                  child: Text(
                                    'Ver video',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.darkBrown,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _infoRow(
                        'Video Protagonista EN',
                        '-',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Text(
              'Contenido educativo',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.darkBrown,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _infoCard(
                    [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Flashcards',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => _showFlashcards(context),
                                    child: Text(
                                      'Ver',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.darkBrown,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  InkWell(
                                    onTap: () => _editFlashcards(context),
                                    child: Text(
                                      'Editar',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.darkBrown,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _infoRow(
                        'Infografía',
                        'Ver infografía',
                      ),
                      _infoRow(
                        'Preguntas',
                        'Ver preguntas',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditFlashcardsDialog extends StatefulWidget {
  final String lessonId;

  const _EditFlashcardsDialog({
    required this.lessonId,
  });

  @override
  State<_EditFlashcardsDialog> createState() =>
      _EditFlashcardsDialogState();
}

class _EditFlashcardsDialogState
    extends State<_EditFlashcardsDialog> {
    final FlashcardService _flashcardService = FlashcardService();

    List<Flashcard> _flashcards = [];
    bool _loading = true;

      @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    final flashcards =
        await _flashcardService.getFlashcardsByLesson(
      widget.lessonId,
    );

    if (!mounted) return;

    setState(() {
      _flashcards = flashcards;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar flashcards'),
      content: SizedBox(
      width: 700,
      height: 500,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _flashcards.isEmpty
              ? const Center(
                  child: Text(
                    'No hay flashcards disponibles.',
                  ),
                )
              : ListView.builder(
                  itemCount: _flashcards.length,
                  itemBuilder: (context, index) {
                    final flashcard = _flashcards[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flashcard ${index + 1}',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkBrown,
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: TextEditingController(
                                text: flashcard.titleEs,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Título ES',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: TextEditingController(
                                text: flashcard.contentEs,
                              ),
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Contenido ES',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _VideoDialog extends StatefulWidget {
  final String videoUrl;

  const _VideoDialog({
    required this.videoUrl,
  });

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: _controller.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),

                    IconButton(
                      iconSize: 60,
                      color: Colors.white,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                    ),

                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
            )
          : const SizedBox(
              width: 600,
              height: 350,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}