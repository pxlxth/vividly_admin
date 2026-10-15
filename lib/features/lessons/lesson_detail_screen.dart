import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/lesson.dart';
import '../../models/flashcard.dart';
import '../../services/flashcard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/topic.dart';
import '../../services/topic_service.dart';
import '../../services/lesson_service.dart';

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

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final FlashcardService _flashcardService = FlashcardService();
  final TopicService _topicService = TopicService();
  final Map<String, int> _videoRefreshKeys = {};
  Map<String, dynamic>? _infographicData;
  List<Flashcard> _flashcards = [];
  final Map<int, int> _flashcardRefreshKeys = {};
  final Map<String, int> _infographicRefreshKeys = {};

  List<Map<String, dynamic>> _initialQuizQuestions = [];
  List<Map<String, dynamic>> _finalQuizQuestions = [];

  bool _loadingInfographic = true;
  bool _loadingFlashcards = true;
  bool _loadingInitialQuiz = true;
  bool _loadingFinalQuiz = true;
  late String _titleEs;
  late String _titleEn;
  late String _subtitleEs;
  late String _subtitleEn;
  late String _witnessNameEs;
  late String _witnessNameEn;
  String _topicNameEs = '';
  late String _topicId;
 
@override
void initState() {
  super.initState();

  _titleEs = widget.lesson.titleEs;
  _titleEn = widget.lesson.titleEn;
  _subtitleEs = widget.lesson.subtitleEs ?? '';
  _subtitleEn = widget.lesson.subtitleEn ?? '';
  _witnessNameEs = widget.lesson.witnessNameEs ?? '';
  _witnessNameEn = widget.lesson.witnessNameEn ?? '';

  _loadInfographic();
  _loadFlashcards();
  _loadQuiz('initial');
  _loadQuiz('final');
  _topicId = widget.lesson.topicId;
  _loadTopicName();
}

  Future<void> _loadTopicName() async {
    try {
      final topic = await Supabase.instance.client
          .from('topics')
          .select('name_es')
          .eq('id', _topicId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _topicNameEs = topic?['name_es']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('Error cargando tópico: $e');
    }
  }

Future<void> _replaceFlashcardImage(
  Flashcard flashcard,
  int index,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg'],
    withData: true,
  );

  if (result == null || result.files.single.bytes == null) {
    return;
  }

  final bytes = result.files.single.bytes!;

  try {
    final supabase = Supabase.instance.client;

    final oldPath = flashcard.imageUrl;

    if (oldPath == null || oldPath.isEmpty) {
      return;
    }

    String storagePath = oldPath;

    if (storagePath.startsWith('http')) {
      const marker =
          '/storage/v1/object/public/lesson-images/';

      final position = storagePath.indexOf(marker);

      if (position != -1) {
        storagePath =
            storagePath.substring(position + marker.length);
      }
    }

    await supabase.storage
        .from('lesson-images')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    if (!mounted) return;

setState(() {
  _flashcardRefreshKeys[index] =
      DateTime.now().millisecondsSinceEpoch;
});

await _loadFlashcards();
  } catch (_) {
  
  }
}

Future<void> _replaceInfographicImage(
  String language,
  String? imagePath,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg'],
    withData: true,
  );

  if (result == null || result.files.single.bytes == null) {
    return;
  }

  final bytes = result.files.single.bytes!;

  try {
    final supabase = Supabase.instance.client;

    String storagePath;

    if (imagePath != null && imagePath.isNotEmpty) {
      storagePath = imagePath;

      if (storagePath.startsWith('http')) {
        const marker =
            '/storage/v1/object/public/lesson-images/';

        final position = storagePath.indexOf(marker);

        if (position != -1) {
          storagePath =
              storagePath.substring(position + marker.length);
        }
      }
    } else {
      final fileName = language == 'Español'
          ? 'infographic_es.png'
          : 'infographic_en.png';

      storagePath =
          '${widget.lesson.id}/$fileName';
    }

    await supabase.storage
        .from('lesson-images')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    final imageUrl = supabase.storage
        .from('lesson-images')
        .getPublicUrl(storagePath);

    final column = language == 'Español'
        ? 'image_url_es'
        : 'image_url_en';

    await supabase
        .from('lesson_infographics')
        .update({
      column: imageUrl,
    })
        .eq('lesson_id', widget.lesson.id);

    if (!mounted) return;

    setState(() {
      _infographicRefreshKeys['$language-image'] =
          DateTime.now().millisecondsSinceEpoch;
    });

    await _loadInfographic();
  } catch (_) {
    // No mostramos mensajes.
  }
}

Future<void> _replaceInfographicAudio(
  String language,
  String? audioPath,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['mp3', 'wav'],
    withData: true,
  );

  if (result == null || result.files.single.bytes == null) {
    return;
  }

  final bytes = result.files.single.bytes!;
  final extension = result.files.single.extension ?? 'mp3';

  try {
    final supabase = Supabase.instance.client;

    String storagePath;

    if (audioPath != null && audioPath.isNotEmpty) {
      storagePath = audioPath;

      if (storagePath.startsWith('http')) {
        const marker =
            '/storage/v1/object/public/lesson-audios/';

        final position = storagePath.indexOf(marker);

        if (position != -1) {
          storagePath =
              storagePath.substring(position + marker.length);
        }
      }
    } else {
      final fileName = language == 'Español'
          ? 'infographic_audio_es.$extension'
          : 'infographic_audio_en.$extension';

      storagePath =
          '${widget.lesson.id}/$fileName';
    }

    await supabase.storage
        .from('lesson-audios')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    final audioUrl = supabase.storage
        .from('lesson-audios')
        .getPublicUrl(storagePath);

    final column = language == 'Español'
        ? 'audio_url_es'
        : 'audio_url_en';

    await supabase
        .from('lesson_infographics')
        .update({
      column: audioUrl,
    })
        .eq('lesson_id', widget.lesson.id);

    if (!mounted) return;

    await _loadInfographic();
  } catch (_) {
  }
}

Future<void> _editFlashcard(Flashcard flashcard) async {
  final titleEsController = TextEditingController(
    text: flashcard.titleEs,
  );

  final contentEsController = TextEditingController(
    text: flashcard.contentEs,
  );

  final titleEnController = TextEditingController(
    text: flashcard.titleEn ?? '',
  );

  final contentEnController = TextEditingController(
    text: flashcard.contentEn ?? '',
  );

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          'Editar flashcard',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.darkBrown,
          ),
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleEsController,
                  decoration: const InputDecoration(
                    labelText: 'Título ES',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: contentEsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Contenido ES',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: titleEnController,
                  decoration: const InputDecoration(
                    labelText: 'Título EN',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: contentEnController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Contenido EN',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('lesson_flashcards')
                    .update({
                      'title_es': titleEsController.text.trim(),
                      'content_es': contentEsController.text.trim(),
                      'title_en': titleEnController.text.trim(),
                      'content_en': contentEnController.text.trim(),
                    })
                    .eq('id', flashcard.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (_) {
                // No mostramos mensajes.
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );

  titleEsController.dispose();
  contentEsController.dispose();
  titleEnController.dispose();
  contentEnController.dispose();

  if (saved == true) {
    await _loadFlashcards();
  }
}

Future<void> _editQuizQuestion(
  Map<String, dynamic> question,
) async {
  final questionEsController = TextEditingController(
    text: (question['question_es'] ?? '').toString(),
  );

  final questionEnController = TextEditingController(
    text: (question['question_en'] ?? '').toString(),
  );

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          'Editar pregunta',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.darkBrown,
          ),
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionEsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Pregunta en español',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: questionEnController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question in English',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('lesson_quiz_questions')
                    .update({
                      'question_es':
                          questionEsController.text.trim(),
                      'question_en':
                          questionEnController.text.trim(),
                    })
                    .eq('id', question['id']);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (_) {
                // No mostramos mensajes.
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );

  questionEsController.dispose();
  questionEnController.dispose();

  if (saved == true) {
    final quizType = question['_quiz_type'];

    if (quizType != null) {
      await _loadQuiz(quizType.toString());
    } else {
      await _loadQuiz('initial');
      await _loadQuiz('final');
    }
  }
}

Future<void> _deleteQuizQuestion(
  Map<String, dynamic> question,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          'Eliminar pregunta',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.darkBrown,
          ),
        ),
        content: const Text(
          '¿Estás segura de que quieres eliminar esta pregunta y todas sus respuestas?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  try {
    final supabase = Supabase.instance.client;

    final questionId = question['id'];

    await supabase
        .from('lesson_quiz_options')
        .delete()
        .eq('question_id', questionId);

    await supabase
        .from('lesson_quiz_questions')
        .delete()
        .eq('id', questionId);

    final quizType = question['_quiz_type'];

    if (quizType != null) {
      await _loadQuiz(quizType.toString());
    } else {
      await _loadQuiz('initial');
      await _loadQuiz('final');
    }
  } catch (_) {
  }
}

Future<void> _editQuizOptions(
  Map<String, dynamic> question,
) async {
  final options = List<Map<String, dynamic>>.from(
    question['options'] ?? [],
  );

  if (options.isEmpty) return;

  final controllers = <Map<String, TextEditingController>>[];

  for (final option in options) {
    controllers.add({
      'es': TextEditingController(
        text: (option['option_es'] ?? '').toString(),
      ),
      'en': TextEditingController(
        text: (option['option_en'] ?? '').toString(),
      ),
    });
  }

  int correctIndex = options.indexWhere(
    (option) => option['is_correct'] == true,
  );

  if (correctIndex < 0) {
    correctIndex = 0;
  }

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'Editar respuestas',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.darkBrown,
              ),
            ),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    options.length,
                    (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index == correctIndex
                                ? AppColors.green
                                    .withValues(alpha: 0.4)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Radio<int>(
                                  value: index,
                                  groupValue: correctIndex,
                                  activeColor: AppColors.green,
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setDialogState(() {
                                      correctIndex = value;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    'Respuesta ${index + 1}',
                                    style: AppTextStyles.small.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: index == correctIndex
                                          ? AppColors.green
                                          : AppColors.darkBrown,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controllers[index]['es'],
                              decoration: const InputDecoration(
                                labelText: 'Respuesta en español',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: controllers[index]['en'],
                              decoration: const InputDecoration(
                                labelText: 'Answer in English',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final supabase =
                        Supabase.instance.client;

                    for (int i = 0; i < options.length; i++) {
                      await supabase
                          .from('lesson_quiz_options')
                          .update({
                        'option_es':
                            controllers[i]['es']!.text.trim(),
                        'option_en':
                            controllers[i]['en']!.text.trim(),
                        'is_correct':
                            i == correctIndex,
                      }).eq(
                        'id',
                        options[i]['id'],
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (_) {
                    // No mostramos mensajes.
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
    },
  );

  for (final controller in controllers) {
    controller['es']!.dispose();
    controller['en']!.dispose();
  }

  if (saved == true) {
    final quizType = question['_quiz_type'];

    if (quizType != null) {
      await _loadQuiz(quizType.toString());
    } else {
      await _loadQuiz('initial');
      await _loadQuiz('final');
    }
  }
}

  Future<void> _loadInfographic() async {
    try {
      final response = await Supabase.instance.client
          .from('lesson_infographics')
          .select(
            'image_url_es, image_url_en, audio_url_es, audio_url_en',
          )
          .eq('lesson_id', widget.lesson.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _infographicData =
            response == null ? null : Map<String, dynamic>.from(response);
        _loadingInfographic = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInfographic = false);
    }
  }

  Future<void> _loadFlashcards() async {
    try {
      final flashcards =
          await _flashcardService.getFlashcardsByLesson(widget.lesson.id);

      if (!mounted) return;

      setState(() {
        _flashcards = flashcards;
        _loadingFlashcards = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFlashcards = false);
    }
  }

Future<void> _loadQuiz(String quizType) async {
  try {
    final supabase = Supabase.instance.client;

    final quizResponse = await supabase
        .from('lesson_quizzes')
        .select('id')
        .eq('lesson_id', widget.lesson.id)
        .eq('quiz_type', quizType)
        .maybeSingle();

    if (quizResponse == null) {
      if (!mounted) return;

      setState(() {
        if (quizType == 'initial') {
          _initialQuizQuestions = [];
          _loadingInitialQuiz = false;
        } else {
          _finalQuizQuestions = [];
          _loadingFinalQuiz = false;
        }
      });

      return;
    }

    final quizId = quizResponse['id'];

    final questionsResponse = await supabase
        .from('lesson_quiz_questions')
        .select('*')
        .eq('quiz_id', quizId)
        .order('display_order', ascending: true);

    final List<Map<String, dynamic>> questions = [];

    for (final question in questionsResponse) {
      final optionsResponse = await supabase
          .from('lesson_quiz_options')
          .select('*')
          .eq('question_id', question['id'])
          .order('display_order', ascending: true);

      final questionData = Map<String, dynamic>.from(question);

      questionData['_quiz_type'] = quizType;

      questionData['options'] = optionsResponse
          .map<Map<String, dynamic>>(
            (option) => Map<String, dynamic>.from(option),
          )
          .toList();

      questions.add(questionData);
    }

    if (!mounted) return;

    setState(() {
      if (quizType == 'initial') {
        _initialQuizQuestions = questions;
        _loadingInitialQuiz = false;
      } else {
        _finalQuizQuestions = questions;
        _loadingFinalQuiz = false;
      }
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      if (quizType == 'initial') {
        _initialQuizQuestions = [];
        _loadingInitialQuiz = false;
      } else {
        _finalQuizQuestions = [];
        _loadingFinalQuiz = false;
      }
    });

    debugPrint('Error cargando quiz $quizType: $e');
  }
}

  String _storageUrl(String bucket, String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http')) return path;

    return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
  }

  bool _hasPath(String? path) =>
      path != null && path.trim().isNotEmpty;

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
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
            Icon(
              icon,
              color: AppColors.green,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.darkBrown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.20),
        ),
      ),
      child: Column(children: children),
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

  Widget _actionButton({
    required String text,
    required VoidCallback? onPressed,
    IconData icon = Icons.edit_outlined,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkBrown,
      ),
    );
  }

  Widget _emptyMessage(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 46, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLessonHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _titleEs,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.darkBrown,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.grey,
              ),
              
            onSelected: (value) {
              if (value == 'edit') {
                _editLessonInfo();
              } else if (value == 'topic') {
                _changeLessonTopic();
              }
            },
            
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar información'),
                ),
              ),
              PopupMenuItem(
                value: 'topic',
                child: ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('Cambiar tópico'),
                ),
              ),
            ],
            ),
          ],
        ),
          const SizedBox(height: 8),
          Text(
            _titleEn.isEmpty
                ? '(Sin título en inglés)'
                : _titleEn,
            style: AppTextStyles.body.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _headerInfoRow(
            'Subtítulo',
            _subtitleEs,
            _subtitleEn,
          ),
          _headerInfoRow(
            'Testigo',
            _witnessNameEs,
           _witnessNameEn,
          ),
          _headerInfoRow(
            'Tópico',
            _topicNameEs,
            '',
            showFlags: false,
          ),
          _headerInfoRow(
            'Estado',
            widget.lesson.isPublished == true
                ? 'Publicado'
                : 'No publicado',
            '',
            showFlags: false,
          ),
          _headerInfoRow(
            'Fecha',
            _formatDate(widget.lesson.createdAt),
            '',
            showFlags: false,
          ),
        
        ],
        ),
    );
  }

  Future<void> _changeLessonTopic() async {
    final topicService = TopicService();
    final lessonService = LessonService();

    List<Topic> topics = await topicService.getTopics();

    if (!mounted) return;

    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar los tópicos.'),
        ),
      );
      return;
    }

    topics.sort(
      (a, b) => a.nameEs.toLowerCase().compareTo(
        b.nameEs.toLowerCase(),
      ),
    );

    String? selectedTopicId = _topicId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar tópico'),
              content: SizedBox(
                width: 400,
                child: DropdownButtonFormField<String>(
                  initialValue: topics.any(
                    (topic) => topic.id == selectedTopicId,
                  )
                      ? selectedTopicId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Selecciona un tópico',
                    border: OutlineInputBorder(),
                  ),
                  items: topics.map((topic) {
                    return DropdownMenuItem<String>(
                      value: topic.id,
                      child: Text(
                        '${topic.nameEs} / ${topic.nameEn}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedTopicId = value;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedTopicId == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedTopicId == null) return;
    if (!mounted) return;

    if (selectedTopicId == widget.lesson.topicId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La lección ya pertenece a ese tópico.'),
        ),
      );
      return;
    }

    final success = await lessonService.updateLessonTopic(
      widget.lesson.id,
      selectedTopicId!,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Tópico actualizado correctamente.'
              : 'No se pudo actualizar el tópico.',
        ),
      ),  
    );

    if (success) {
      setState(() {
        _topicId = selectedTopicId!;
      });
      await _loadTopicName();
    }
  }


  Widget _headerInfoRow(
  String label,
  String valueEs,
  String valueEn, {
  bool showFlags = true,
}) {
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
            showFlags ? '🇪🇸 $valueEs' : valueEs,
            style: AppTextStyles.body.copyWith(
              color: Colors.black54,
            ),
          ),
        if (valueEn.trim().isNotEmpty)
          Text(
            showFlags ? '🇺🇸 $valueEn' : valueEn,
            style: AppTextStyles.body.copyWith(
              color: Colors.black54,
            ),
          ),
      ],
    ),
  );
}
  Widget _headerChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.18),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTextStyles.small.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: AppTextStyles.small.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    return _buildSection(
      title: 'Video',
      icon: Icons.play_circle_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildVideoLanguage(
            language: 'Español',
            flag: '🇪🇸',
            videos: [
              _VideoItem(
                title: 'Video introductorio',
                path: widget.lesson.introVideoUrlEs,
              ),
              _VideoItem(
                title: 'Protagonista',
                path: widget.lesson.protagonistBaseVideoUrlEs,
              ),
              _VideoItem(
                title: 'Testigo',
                path: widget.lesson.witnessBaseVideoUrlEs,
              ),
            ],
          ),
          ),
          const SizedBox(width: 20),
          Expanded(
           child: _buildVideoLanguage(
            language: 'English',
            flag: '🇺🇸',
            videos: [
                _VideoItem(
                  title: 'Introductory video',
                  path: widget.lesson.introVideoUrlEn,
                ),
                _VideoItem(
                  title: 'Protagonist',
                  path: widget.lesson.protagonistBaseVideoUrlEn,
                ),
                _VideoItem(
                  title: 'Witness',
                  path: widget.lesson.witnessBaseVideoUrlEn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Future<void> _replaceVideo(_VideoItem video) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['mp4'],
    withData: true,
  );

  if (result == null || result.files.single.bytes == null) {
    return;
  }

  final bytes = result.files.single.bytes!;

  try {
    final supabase = Supabase.instance.client;

    String? storagePath = video.path;

    if (storagePath == null || storagePath.isEmpty) {
      return;
    }

    if (storagePath.startsWith('http')) {
      const marker =
          '/storage/v1/object/public/lesson-videos/';

      final index = storagePath.indexOf(marker);

      if (index != -1) {
        storagePath =
            storagePath.substring(index + marker.length);
      }
    }

    await supabase.storage
        .from('lesson-videos')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    if (!mounted) return;

    setState(() {
      _videoRefreshKeys[video.title] =
          DateTime.now().millisecondsSinceEpoch;
    });
  } catch (e) {
  }
}


  Widget _buildVideoLanguage({
    required String language,
    required String flag,
    required List<_VideoItem> videos,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                flag,
                style: const TextStyle(
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                language,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.darkBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...videos.map(
            (video) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildVideoCard(video),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildVideoCard(_VideoItem video) {
  final available =
      video.path != null && video.path!.trim().isNotEmpty;

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.withValues(alpha: 0.15),
      ),
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
                ? () => _showVideo(context, video.path)
                : null,
            child: SizedBox(
              width: 140,
              height: 90,
              child: _VideoThumbnail(
                key: ValueKey(
                  '${video.title}_${_videoRefreshKeys[video.title] ?? 0}',
                ),
                path: video.path,
                onTap: available
                    ? () => _showVideo(context, video.path)
                    : null,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.darkBrown,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                video.path ?? 'Archivo no encontrado',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small.copyWith(
                  color: available
                      ? Colors.black54
                      : Colors.red,
                ),
              ),

              if (available) ...[
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () {
                    _replaceVideo(video);
                  },
                  icon: const Icon(
                    Icons.swap_horiz,
                    size: 17,
                  ),
                  label: const Text('Reemplazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7655A8),
                    side: const BorderSide(
                      color: Color(0xFF8E82A0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildFlashcards() {
    return _buildSection(
      title: 'Flashcards',
      icon: Icons.style_outlined,
      child: _loadingFlashcards
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          : _flashcards.isEmpty
             ? _emptyMessage(
                'No hay flashcards.',
                Icons.style_outlined,
              )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth =
                        (constraints.maxWidth - 24) / 3;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(
                        _flashcards.length,
                        (index) {
                          return SizedBox(
                            width: cardWidth,
                            child: _buildFlashcardCard(
                              _flashcards[index],
                              index,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildFlashcardCard(
    Flashcard flashcard,
    int index,
  ) {
   final baseImageUrl = _storageUrl(
  'lesson-images',
  flashcard.imageUrl,
);

final imageUrl = baseImageUrl.isEmpty
    ? ''
    : '$baseImageUrl?v=${_flashcardRefreshKeys[index] ?? 0}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Expanded(
                child: Text(
                  'Flashcard ${index + 1}',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.grey,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editFlashcard(flashcard);
                  }

                  if (value == 'replace') {
                    _replaceFlashcardImage(
                      flashcard,
                      index,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar contenido'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'replace',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz),
                      title: Text('Reemplazar imagen'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Imagen
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180,
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
            '🇪🇸 ${flashcard.titleEs}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            flashcard.contentEs,
            style: AppTextStyles.small.copyWith(
              color: Colors.black54,
            ),
          ),

          if (flashcard.titleEn?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),

            Text(
              '🇺🇸 ${flashcard.titleEn}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          if (flashcard.contentEn?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 5),

            Text(
              flashcard.contentEn!,
              style: AppTextStyles.small.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  } 
  

  Widget _buildInfographicSection() {
    if (_loadingInfographic) {
      return _buildSection(
        title: 'Infografía',
        icon: Icons.image_outlined,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return _buildSection(
      title: 'Infografía',
      icon: Icons.image_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildInfographicLanguage(
              language: 'Español',
              flag: '🇪🇸',
              imagePath: _infographicData?['image_url_es'] as String?,
              audioPath: _infographicData?['audio_url_es'] as String?,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildInfographicLanguage(
              language: 'English',
              flag: '🇺🇸',
              imagePath: _infographicData?['image_url_en'] as String?,
              audioPath: _infographicData?['audio_url_en'] as String?,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfographicLanguage({
    required String language,
    required String flag,
    required String? imagePath,
    required String? audioPath,
  }) {
final baseImageUrl = imagePath ?? '';
final imageUrl = baseImageUrl.isEmpty
    ? ''
    : '$baseImageUrl?v=${_infographicRefreshKeys['$language-image'] ?? 0}';

final audioUrl = audioPath ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                flag,
                style: const TextStyle(
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                language,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.darkBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (imageUrl.isNotEmpty)
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Infografía no disponible'),
            ),
          const SizedBox(height: 12),
          if (imageUrl.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showInfographic(imagePath),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver completa'),
              ),
              OutlinedButton.icon(
                onPressed: () => _replaceInfographicImage(
                  language,
                  imagePath,
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Reemplazar imagen'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (audioUrl.isNotEmpty) ...[
          _InlineAudioPlayer(audioUrl: audioUrl),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _replaceInfographicAudio(
              language,
              audioPath,
            ),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Reemplazar audio'),
          ),
        ] else ...[
          Text(
            'Audio no disponible',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _replaceInfographicAudio(
              language,
              audioPath,
            ),
            icon: const Icon(Icons.audio_file_outlined),
            label: const Text('Agregar audio'),
          ),
        ],
        ],
      ),
    );
  }

  Widget _quizSection(String title, IconData icon, String quizType) {
    final isInitial = quizType == 'initial';

    final loading = isInitial
        ? _loadingInitialQuiz
        : _loadingFinalQuiz;

    final questions = isInitial
        ? _initialQuizQuestions
        : _finalQuizQuestions;

    return _buildSection(
      title: title,
      icon: icon,
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          : questions.isEmpty
              ? _emptyMessage(
                  'No hay preguntas para este test.',
                  Icons.quiz_outlined,
                )
              : Column(
                  children: List.generate(
                    questions.length,
                    (index) => _buildQuizQuestion(
                      questions[index],
                      index,
                    ),
                  ),
                ),
    );
  }

Widget _buildQuizQuestion(
  Map<String, dynamic> question,
  int index,
) {
  final questionEs =
      (question['question_es'] ?? '').toString();

  final questionEn =
      (question['question_en'] ?? '').toString();

  final options = List<Map<String, dynamic>>.from(
    question['options'] ?? [],
  );

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: AppColors.green.withValues(alpha: 0.20),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pregunta ${index + 1}',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.grey,
              ),
              onSelected: (value) {
               if (value == 'edit') {
                    _editQuizQuestion(question);
                  }

                  if (value == 'options') {
                    _editQuizOptions(question);
                  }

                  if (value == 'delete') {
                    _deleteQuizQuestion(question);
                  }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar pregunta'),
                  ),
                ),
                PopupMenuItem(
                  value: 'options',
                  child: ListTile(
                    leading: Icon(Icons.list_alt_outlined),
                    title: Text('Editar respuestas'),
                  ),
                ),

                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: Text('Eliminar pregunta'),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        Text(
          '🇪🇸 $questionEs',
          style: AppTextStyles.body.copyWith(
            color: AppColors.darkBrown,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (questionEn.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '🇺🇸 $questionEn',
            style: AppTextStyles.small.copyWith(
              color: Colors.black54,
            ),
          ),
        ],

        const SizedBox(height: 16),

        ...List.generate(
          options.length,
          (optionIndex) {
            final option = options[optionIndex];

            final textEs =
          (option['option_es'] ?? '').toString();

      final textEn =
          (option['option_en'] ?? '').toString();

            final isCorrect =
                option['is_correct'] == true;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.green.withValues(alpha: 0.08)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect
                      ? AppColors.green.withValues(alpha: 0.35)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    color: isCorrect
                        ? AppColors.green
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          textEs,
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (textEn.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            textEn,
                            style: AppTextStyles.small.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

  void _showEditMessage(String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text(
          'La vista y el botón ya están preparados con el mismo estilo '
          'de edición de LessonReviewScreen. La conexión de subida y '
          'persistencia se puede conectar después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showThumbnail() {
    final url = _storageUrl(
      'lesson-images',
      widget.lesson.thumbnailUrl,
    );

    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Image.network(
                url,
                fit: BoxFit.contain,
                width: 700,
                height: 500,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfographic(String? path) {
    final url = _storageUrl('lesson-images', path);
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Image.network(
                url,
                fit: BoxFit.contain,
                height: 650,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideo(BuildContext context, String? path) {
    final url = _storageUrl('lesson-videos', path);
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _VideoDialog(videoUrl: url),
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
    ).then((_) => _loadFlashcards());
  }

  Future<void> _editLessonInfo() async {
  final titleEsController = TextEditingController(
    text: _titleEs,
  );

  final titleEnController = TextEditingController(
    text: _titleEn,
  );

  final subtitleEsController = TextEditingController(
    text: widget.lesson.subtitleEs,
  );

  final subtitleEnController = TextEditingController(
    text: widget.lesson.subtitleEn,
  );

  final witnessEsController = TextEditingController(
    text: widget.lesson.witnessNameEs,
  );

  final witnessEnController = TextEditingController(
    text: widget.lesson.witnessNameEn,
  );

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          'Editar información de la lección',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.darkBrown,
          ),
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleEsController,
                  decoration: const InputDecoration(
                    labelText: 'Título ES',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: titleEnController,
                  decoration: const InputDecoration(
                    labelText: 'Título EN',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: subtitleEsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo ES',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: subtitleEnController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo EN',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: witnessEsController,
                  decoration: const InputDecoration(
                    labelText: 'Testigo ES',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: witnessEnController,
                  decoration: const InputDecoration(
                    labelText: 'Testigo EN',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('lessons')
                    .update({
                      'title_es': titleEsController.text.trim(),
                      'title_en': titleEnController.text.trim(),
                      'subtitle_es':
                          subtitleEsController.text.trim(),
                      'subtitle_en':
                          subtitleEnController.text.trim(),
                      'witness_name_es':
                          witnessEsController.text.trim(),
                      'witness_name_en':
                          witnessEnController.text.trim(),
                    })
                    .eq('id', widget.lesson.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (_) {
                // No mostramos mensajes.
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
  final newTitleEs = titleEsController.text.trim();
  final newTitleEn = titleEnController.text.trim();
  final newSubtitleEs = subtitleEsController.text.trim();
  final newSubtitleEn = subtitleEnController.text.trim();
  final newWitnessEs = witnessEsController.text.trim();
  final newWitnessEn = witnessEnController.text.trim();

  titleEsController.dispose();
  titleEnController.dispose();
  subtitleEsController.dispose();
  subtitleEnController.dispose();
  witnessEsController.dispose();
  witnessEnController.dispose();

  if (saved == true && mounted) {
    setState(() {
      _titleEs = newTitleEs;
      _titleEn = newTitleEn;
      _subtitleEs = newSubtitleEs;
      _subtitleEn = newSubtitleEn;
      _witnessNameEs = newWitnessEs;
      _witnessNameEn = newWitnessEn;
    });
  }
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
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver',
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
            const SizedBox(height: 8),
            Text(
              _titleEs,
              style: AppTextStyles.h1.copyWith(
                color: AppColors.darkBrown,
              ),
            ),
            const SizedBox(height: 30),

            _buildLessonHeader(),
            const SizedBox(height: 30),

            
            _buildSection(
              title: 'Miniatura',
              icon: Icons.image_outlined,
              child: _infoCard([
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 180,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                        child: _hasPath(widget.lesson.thumbnailUrl)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _storageUrl(
                                    'lesson-images',
                                    widget.lesson.thumbnailUrl,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.image_outlined,
                                size: 42,
                                color: Colors.grey,
                              ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _actionButton(
                          text: 'Ver completa',
                          icon: Icons.visibility_outlined,
                          onPressed: _hasPath(
                            widget.lesson.thumbnailUrl,
                          )
                              ? _showThumbnail
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 30),

            _buildVideoSection(),
            const SizedBox(height: 30),

            _buildFlashcards(),
            const SizedBox(height: 30),

            _buildInfographicSection(),
            const SizedBox(height: 30),

            _quizSection(
            'Test inicial',
            Icons.quiz_outlined,
            'initial',
),
            const SizedBox(height: 30),

           _quizSection(
              'Test final',
              Icons.fact_check_outlined,
              'final',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String? path;
  final VoidCallback? onTap;
  //final Key? key;

 const _VideoThumbnail({
  super.key,
  required this.path,
  this.onTap,
});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String _duration = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.path == null ||
        widget.path!.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final url = widget.path!.startsWith('http')
          ? widget.path!
          : Supabase.instance.client.storage
              .from('lesson-videos')
              .getPublicUrl(widget.path!);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      await controller.initialize();

      final duration = controller.value.duration;

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
        _duration = _formatDuration(duration);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes
        .toString()
        .padLeft(2, '0');

    final seconds = (duration.inSeconds % 60)
        .toString()
        .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: AppColors.green.withValues(alpha: 0.06),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null &&
                _controller!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_loading)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.video_library_outlined,
                  size: 42,
                  color: Colors.grey,
                ),
              ),

            // Oscurecimiento
            if (_controller != null &&
                _controller!.value.isInitialized)
              Container(
                color: Colors.black.withValues(alpha: 0.22),
              ),

            // Botón play
            if (_controller != null &&
                _controller!.value.isInitialized)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: AppColors.green,
                    size: 30,
                  ),
                ),
              ),

            // Duración
            if (_duration.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoItem {
  final String title;
  final String? path;

  const _VideoItem({
    required this.title,
    required this.path,
  });
}

class _FlashcardsDialog extends StatefulWidget {
  final String lessonId;

  const _FlashcardsDialog({
    required this.lessonId,
  });

  @override
  State<_FlashcardsDialog> createState() =>
      _FlashcardsDialogState();
}

class _FlashcardsDialogState extends State<_FlashcardsDialog> {
  final FlashcardService _flashcardService = FlashcardService();

  late Future<List<Flashcard>> _future;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _future =
        _flashcardService.getFlashcardsByLesson(widget.lessonId);
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
          future: _future,
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
                child: Text('No hay flashcards disponibles.'),
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
                        onPressed: () =>
                            Navigator.pop(context),
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
                          if (_hasImage(flashcard.imageUrl))
                            Image.network(
                              Supabase.instance.client.storage
                                  .from('lesson-images')
                                  .getPublicUrl(
                                    flashcard.imageUrl!,
                                  ),
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
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _currentIndex > 0
                            ? () => setState(
                                  () => _currentIndex--,
                                )
                            : null,
                      ),
                      Text(
                        '${_currentIndex + 1} / ${flashcards.length}',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed:
                            _currentIndex <
                                    flashcards.length - 1
                                ? () => setState(
                                      () => _currentIndex++,
                                    )
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

  bool _hasImage(String? path) =>
      path != null && path.trim().isNotEmpty;
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
  final FlashcardService _service = FlashcardService();

  List<Flashcard> _flashcards = [];
  final Map<int, int> _flashcardRefreshKeys = {};
  final Map<String, int> _infographicRefreshKeys = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result =
          await _service.getFlashcardsByLesson(widget.lessonId);

      if (!mounted) return;

      setState(() {
        _flashcards = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar flashcards'),
      content: SizedBox(
        width: 760,
        height: 560,
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
                        margin:
                            const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flashcard ${index + 1}',
                                style:
                                    AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: flashcard.titleEs,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Título ES',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue:
                                    flashcard.contentEs,
                                maxLines: 4,
                                decoration:
                                    const InputDecoration(
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

class _InlineAudioPlayer extends StatefulWidget {
  final String audioUrl;

  const _InlineAudioPlayer({
    required this.audioUrl,
  });

  @override
  State<_InlineAudioPlayer> createState() =>
      _InlineAudioPlayerState();
}

class _InlineAudioPlayerState
    extends State<_InlineAudioPlayer> {
  late final AudioPlayer _player;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();

    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _time(Duration duration) {
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;

    final value = _position.inMilliseconds
        .clamp(0, max.toInt())
        .toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _playing
                  ? Icons.pause_circle
                  : Icons.play_circle,
            ),
            color: AppColors.green,
            onPressed: () async {
              if (_playing) {
                await _player.pause();
              } else {
                await _player.play(
                  UrlSource(widget.audioUrl),
                );
              }
            },
          ),
          Text(_time(_position)),
          Expanded(
            child: Slider(
              value: value,
              max: max,
              onChanged: _duration.inMilliseconds == 0
                  ? null
                  : (newValue) async {
                      await _player.seek(
                        Duration(
                          milliseconds: newValue.toInt(),
                        ),
                      );
                    },
            ),
          ),
          Text(_time(_duration)),
        ],
      ),
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
    )..initialize().then((_) {
        if (mounted) setState(() {});
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
                      onPressed: () =>
                          Navigator.of(context).pop(),
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
