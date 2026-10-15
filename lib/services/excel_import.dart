import 'dart:convert';

class ExcelLessonData {
  final String topicEs;
  final String topicEn;
  final String titleEs;
  final String titleEn;
  final String subtitleEs;
  final String subtitleEn;
  final String witnessNameEs;
  final String witnessNameEn;
  final List<QuizData> initialQuizEs;
  final List<QuizData> initialQuizEn;
  final List<QuizData> finalQuizEs;
  final List<QuizData> finalQuizEn;
  final List<FlashcardData> flashcardsEs;
  final List<FlashcardData> flashcardsEn;
  final List<String> warnings;

  ExcelLessonData({
    required this.topicEs,
    required this.topicEn,
    required this.titleEs,
    required this.titleEn,
    required this.subtitleEs,
    required this.subtitleEn,
    required this.witnessNameEs,
    required this.witnessNameEn,
    required this.initialQuizEs,
    required this.initialQuizEn,
    required this.finalQuizEs,
    required this.finalQuizEn,
    required this.flashcardsEs,
    required this.flashcardsEn,
    required this.warnings,
  });
}

class QuizData {
  final String question;
  final List<String> answers;

  QuizData({
    required this.question,
    required this.answers,
  });
}

class FlashcardData {
  final String title;
  final String content;

  FlashcardData({
    required this.title,
    required this.content,
  });
}

class ExcelImportService {
  List<ExcelLessonData> parseLessons(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.asMap().entries.map((entry) {
      final rowNumber = entry.key + 2;
      return _parseLesson(entry.value, rowNumber);
    }).toList();
  }

  ExcelLessonData _parseLesson(
    Map<String, dynamic> row,
    int rowNumber,
  ) {
    final warnings = <String>[];

    final topicEs = _value(row, 'Topic_es');
    final topicEn = _value(row, 'Topic_en');
    final titleEs = _value(row, 'title_es');
    final titleEn = _value(row, 'title_en');
    final subtitleEs = _value(row, 'subtitle_es');
    final subtitleEn = _value(row, 'subtitile_en');
    final witnessNameEs = _value(row, 'witness_name_es');
    final witnessNameEn = _value(row, 'witness_name_en');

    if (topicEs.isEmpty) {
      warnings.add('Falta Topic_es');
    }

    if (topicEn.isEmpty) {
      warnings.add('Falta Topic_en');
    }

    if (titleEs.isEmpty) {
      warnings.add('Falta title_es');
    }

    if (titleEn.isEmpty) {
      warnings.add('Falta title_en');
    }

    final initialQuizEs = <QuizData>[];
    final initialQuizEn = <QuizData>[];

    for (int i = 1; i <= 6; i++) {
      final es = _parseQuiz(
        _value(row, 'Initial_quiz ${i}_es'),
        'Initial_quiz ${i}_es',
        rowNumber,
        warnings,
      );

      final en = _parseQuiz(
        _value(row, 'Initial_quiz ${i}_en'),
        'Initial_quiz ${i}_en',
        rowNumber,
        warnings,
      );

      if (es != null) {
        initialQuizEs.add(es);
      }

      if (en != null) {
        initialQuizEn.add(en);
      }
    }

    final finalQuizEs = _parseQuizArray(
      _value(row, 'final_quiz_es'),
      'final_quiz_es',
      rowNumber,
    );

    final finalQuizEn = _parseQuizArray(
      _value(row, 'final_quiz_en'),
      'final_quiz_en',
      rowNumber,
    );

    final flashcardsEs = <FlashcardData>[];
    final flashcardsEn = <FlashcardData>[];

    for (int i = 1; i <= 3; i++) {
      final es = _parseFlashcard(
        _value(row, 'flashcards${i}_es'),
      );

      final en = _parseFlashcard(
        _value(row, 'flashcards${i}_en'),
      );

      if (es != null) {
        flashcardsEs.add(es);
      }

      if (en != null) {
        flashcardsEn.add(en);
      }
    }

    if (initialQuizEs.length != initialQuizEn.length) {
      warnings.add(
        'El quiz inicial ES/EN no tiene la misma cantidad de preguntas.',
      );
    }

    if (flashcardsEs.length != flashcardsEn.length) {
      warnings.add(
        'Las flashcards ES/EN no tienen la misma cantidad.',
      );
    }

    if (finalQuizEs.isEmpty && finalQuizEn.isEmpty) {
      warnings.add(
        'No tiene quiz final.',
      );
    }

    return ExcelLessonData(
      topicEs: topicEs,
      topicEn: topicEn,
      titleEs: titleEs,
      titleEn: titleEn,
      subtitleEs: subtitleEs,
      subtitleEn: subtitleEn,
      witnessNameEs: witnessNameEs,
      witnessNameEn: witnessNameEn,
      initialQuizEs: initialQuizEs,
      initialQuizEn: initialQuizEn,
      finalQuizEs: finalQuizEs,
      finalQuizEn: finalQuizEn,
      flashcardsEs: flashcardsEs,
      flashcardsEn: flashcardsEn,
      warnings: warnings,
    );
  }

  QuizData? _parseQuiz(
    String value,
    String column,
    int rowNumber,
    List<String> warnings,
  ) {
    if (value.isEmpty) {
      warnings.add(
        'Fila $rowNumber: falta $column',
      );
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is! Map<String, dynamic>) {
        warnings.add(
          'Fila $rowNumber: $column no tiene un JSON válido',
        );
        return null;
      }

      final question = decoded['question'];
      final answers = decoded['answers'];

      if (question is! String || question.trim().isEmpty) {
        warnings.add(
          'Fila $rowNumber: $column no contiene una pregunta válida',
        );
        return null;
      }

      if (answers is! List || answers.length < 2) {
        warnings.add(
          'Fila $rowNumber: $column no contiene suficientes respuestas',
        );
        return null;
      }

      final parsedAnswers = answers
          .map((answer) => answer.toString().trim())
          .where((answer) => answer.isNotEmpty)
          .toList();

      if (parsedAnswers.length < 2) {
        warnings.add(
          'Fila $rowNumber: $column tiene respuestas vacías',
        );
        return null;
      }

      return QuizData(
        question: question.trim(),
        answers: parsedAnswers,
      );
    } catch (_) {
      warnings.add(
        'Fila $rowNumber: $column contiene JSON inválido',
      );
      return null;
    }
  }

  List<QuizData> _parseQuizArray(
    String value,
    String column,
    int rowNumber,
  ) {
    if (value.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is! List) {
        return [];
      }

      final quizzes = <QuizData>[];

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final question = item['question'];
        final answers = item['answers'];

        if (question == null || answers == null) {
          continue;
        }

        if (question is! String ||
            question.trim().isEmpty ||
            answers is! List ||
            answers.length < 2) {
          continue;
        }

        final parsedAnswers = answers
            .map((answer) => answer.toString().trim())
            .where((answer) => answer.isNotEmpty)
            .toList();

        if (parsedAnswers.length < 2) {
          continue;
        }

        quizzes.add(
          QuizData(
            question: question.trim(),
            answers: parsedAnswers,
          ),
        );
      }

      return quizzes;
    } catch (_) {
      return [];
    }
  }

  FlashcardData? _parseFlashcard(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    final parts = value
        .split('\n')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return null;
    }

    final title = parts.first;
    final content =
        parts.length > 1 ? parts.skip(1).join('\n') : '';

    return FlashcardData(
      title: title,
      content: content,
    );
  }

  String _value(
    Map<String, dynamic> row,
    String column,
  ) {
    final value = row[column];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }
}