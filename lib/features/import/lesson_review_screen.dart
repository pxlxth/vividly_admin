import 'package:flutter/material.dart';

import '../../services/excel_import.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/admin_sidebar.dart';

class LessonReviewScreen extends StatefulWidget {
  final List<ExcelLessonData> lessons;
  final int initialIndex;

  const LessonReviewScreen({
    super.key,
    required this.lessons,
    required this.initialIndex,
  });

  @override
  State<LessonReviewScreen> createState() => _LessonReviewScreenState();
}

class _LessonReviewScreenState extends State<LessonReviewScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

                            _buildInitialQuiz(lesson),

                            const SizedBox(height: 30),

                            _buildFlashcards(lesson),

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.titleEs.isEmpty
                ? '(Sin título)'
                : lesson.titleEs,
            style: AppTextStyles.h2.copyWith(
              color: AppColors.darkBrown,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            lesson.titleEn.isEmpty
                ? '(Sin título en inglés)'
                : lesson.titleEn,
            style: AppTextStyles.body.copyWith(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 20),

         _infoRow('Tópico', lesson.topicEs, lesson.topicEn),
          _infoRow('Subtítulo', lesson.subtitleEs, lesson.subtitleEn),
          _infoRow('Testigo', lesson.witnessNameEs, lesson.witnessNameEn),

          if (lesson.errors.isNotEmpty) ...[
            const SizedBox(height: 20),
            _statusBox(
              icon: Icons.error_outline,
              title: 'Errores',
              messages: lesson.errors,
              color: Colors.red,
            ),
          ],

          if (lesson.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _statusBox(
              icon: Icons.warning_amber_rounded,
              title: 'Advertencias',
              messages: lesson.warnings,
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

 Widget _infoRow(
    String label,
    String valueEs,
    String valueEn,
  ) {
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
              style: AppTextStyles.body.copyWith(
                color: Colors.black54,
              ),
            ),
          if (valueEn.trim().isNotEmpty)
            Text(
              '🇺🇸 $valueEn',
              style: AppTextStyles.body.copyWith(
                color: Colors.black54,
              ),
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
              Icon(
                icon,
                color: color,
              ),
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
                style: AppTextStyles.small.copyWith(
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildInitialQuiz(ExcelLessonData lesson) {
  return _buildSection(
    title: 'Test inicial',
    icon: Icons.quiz_outlined,
    child: lesson.initialQuizEs.isEmpty
        ? _emptyMessage(
            'No hay preguntas del test inicial.',
          )
        : Column(
            children: List.generate(
              lesson.initialQuizEs.length,
              (index) {
                final quizEs = lesson.initialQuizEs[index];

                final QuizData? quizEn =
                    index < lesson.initialQuizEn.length
                        ? lesson.initialQuizEn[index]
                        : null;

                return _buildQuizQuestion(
                  index + 1,
                  quizEs,
                  quizEn,
                );
              },
            ),
          ),
  );
}

Widget _buildFlashcards(ExcelLessonData lesson) {
  return _buildSection(
    title: 'Flashcards',
    icon: Icons.style_outlined,
    child: lesson.flashcardsEs.isEmpty
        ? _emptyMessage('No hay flashcards.')
        : Column(
            children: List.generate(
              lesson.flashcardsEs.length,
              (index) {
                final flashcardEs =
                    lesson.flashcardsEs[index];

                final FlashcardData? flashcardEn =
                    index < lesson.flashcardsEn.length
                        ? lesson.flashcardsEn[index]
                        : null;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flashcard ${index + 1}',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 10),

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
                        style: AppTextStyles.body.copyWith(
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
                          style: AppTextStyles.body.copyWith(
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
  );
}

Widget _buildFinalQuiz(ExcelLessonData lesson) {
  return _buildSection(
    title: 'Test final',
    icon: Icons.fact_check_outlined,
    child: lesson.finalQuizEs.isEmpty
        ? _emptyMessage(
            'No hay un test final válido para esta lección.',
          )
        : Column(
            children: List.generate(
              lesson.finalQuizEs.length,
              (index) {
                final quizEs = lesson.finalQuizEs[index];

                final QuizData? quizEn =
                    index < lesson.finalQuizEn.length
                        ? lesson.finalQuizEn[index]
                        : null;

                return _buildQuizQuestion(
                  index + 1,
                  quizEs,
                  quizEn,
                );
              },
            ),
          ),
  );
}

Widget _buildQuizQuestion(
  int number,
  QuizData quizEs,
  QuizData? quizEn,
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

        ...List.generate(
          quizEs.answers.length,
          (index) {
            final isCorrect = index == 0;

            final answerEn =
                quizEn != null &&
                        index < quizEn.answers.length
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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
          },
        ),
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
        style: AppTextStyles.body.copyWith(
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == widget.lessons.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 16,
      ),
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

          ElevatedButton.icon(
            onPressed: isLast ? null : _nextLesson,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Siguiente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}