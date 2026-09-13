import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/excel_import.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/admin_sidebar.dart';
import 'lesson_review_screen.dart';
import '../../services/content_import_service.dart';

class ImportContentScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ImportContentScreen({super.key, this.onBack});

  @override
  State<ImportContentScreen> createState() => _ImportContentScreenState();
}

class _ImportContentScreenState extends State<ImportContentScreen> {
  bool _loading = false;
  String? _fileName;
  String? _errorMessage;

  final ExcelImportService _excelImportService = ExcelImportService();
  final ContentImportService _contentImportService = ContentImportService();
  List<ExcelLessonData> _parsedLessons = [];
  List<Map<String, dynamic>> _lessons = [];
  List<bool> _selectedLessons = [];

  Future<void> _importSelectedLessons() async {
    final selectedLessons = <ExcelLessonData>[];

    for (int i = 0; i < _parsedLessons.length; i++) {
      if (_selectedLessons[i]) {
        selectedLessons.add(_parsedLessons[i]);
      }
    }

    if (selectedLessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos una lección para importar.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    int imported = 0;
    int duplicates = 0;
    int errors = 0;

    final errorMessages = <String>[];

    for (final lesson in selectedLessons) {
      final result = await _contentImportService.importLesson(lesson);

      if (result.imported) {
        imported++;
      } else if (result.duplicate) {
        duplicates++;
      } else {
        errors++;
        errorMessages.add('${lesson.titleEs}: ${result.message}');
      }
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    await showDialog(
      context: context,
      builder: (context) {
        if (duplicates == selectedLessons.length) {
          return AlertDialog(
            title: const Text('Lecciones ya existentes'),
            content: Text(
              'Las $duplicates lecciones seleccionadas ya están registradas. '
              'No se subieron a la base de datos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(
            errors > 0
                ? 'Importación completada con advertencias'
                : 'Importación finalizada',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Importadas: $imported'),
              const SizedBox(height: 6),
              Text('Duplicadas: $duplicates'),
              const SizedBox(height: 6),
              Text('Con error: $errors'),
              if (errorMessages.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Errores:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...errorMessages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $message'),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickExcel() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _lessons = [];
      _fileName = null;
      _parsedLessons = [];
      _selectedLessons = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final file = result.files.single;

      if (file.bytes == null) {
        throw Exception('No se pudo leer el archivo seleccionado.');
      }

      final bytes = file.bytes!;
      final workbook = excel.Excel.decodeBytes(bytes);

      String? mainSheetName;

      for (final sheetName in workbook.tables.keys) {
        if (sheetName.toLowerCase() == 'main') {
          mainSheetName = sheetName;
          break;
        }
      }

      if (mainSheetName == null) {
        throw Exception(
          'No se encontró la pestaña "main" en el archivo Excel.',
        );
      }

      final sheet = workbook.tables[mainSheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('La pestaña "main" está vacía.');
      }

      final headers = sheet.rows.first.map((cell) {
        return cell?.value?.toString().trim() ?? '';
      }).toList();

      final validHeaders = <String>[];

      for (final header in headers) {
        if (header.isNotEmpty) {
          validHeaders.add(header);
        }
      }

      final lessons = <Map<String, dynamic>>[];

      for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];

        bool isEmpty = true;

        for (final cell in row) {
          final value = cell?.value?.toString().trim() ?? '';

          if (value.isNotEmpty) {
            isEmpty = false;
            break;
          }
        }

        if (isEmpty) {
          continue;
        }

        final lessonData = <String, dynamic>{};

        for (int i = 0; i < validHeaders.length; i++) {
          if (i >= row.length) {
            lessonData[validHeaders[i]] = null;
            continue;
          }

          lessonData[validHeaders[i]] = row[i]?.value;
        }

        lessons.add(lessonData);
      }

      final parsedLessons = _excelImportService.parseLessons(lessons);

      setState(() {
        _fileName = file.name;
        _lessons = lessons;
        _parsedLessons = parsedLessons;

        _selectedLessons = List.generate(
          parsedLessons.length,
          (index) => parsedLessons[index].isValid,
        );

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                    'Importar contenido',
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.darkBrown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                'Importa lecciones desde un archivo Excel',
                style: AppTextStyles.body.copyWith(color: Colors.black54),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickExcel,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      'Seleccionar Excel',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    onPressed: _loading ? null : () {},
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(
                      'Importar multimedia',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  if (_parsedLessons.isNotEmpty) ...[
                    const SizedBox(width: 12),

                    ElevatedButton.icon(
                      onPressed: _loading ? null : _importSelectedLessons,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        'Importar seleccionadas',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 20),

                  if (_fileName != null)
                    Text(
                      _fileName!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.darkBrown,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 25),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.body.copyWith(color: Colors.red),
                  ),
                ),

              if (!_loading && _lessons.isNotEmpty) ...[
                const SizedBox(height: 10),

                Row(
                  children: [
                    Text(
                      '${_parsedLessons.length} lecciones analizadas',

                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.darkBrown,
                      ),
                    ),

                    const SizedBox(width: 20),

                    _StatusBadge(
                      label:
                          '${_parsedLessons.where((lesson) => lesson.isValid).length} válidas',
                      color: AppColors.green,
                    ),

                    const SizedBox(width: 10),

                    _StatusBadge(
                      label:
                          '${_parsedLessons.where((lesson) => !lesson.isValid).length} con errores',
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _parsedLessons.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final lesson = _parsedLessons[index];
                        final hasErrors = !lesson.isValid;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LessonReviewScreen(
                                    lessons: _parsedLessons,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _selectedLessons[index],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedLessons[index] =
                                            value ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  CircleAvatar(
                                    backgroundColor: hasErrors
                                        ? Colors.red.withValues(alpha: 0.12)
                                        : AppColors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                    child: hasErrors
                                        ? const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.red,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: AppTextStyles.body.copyWith(
                                              color: AppColors.darkBrown,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ],
                              ),

                              title: Text(
                                lesson.titleEs.isEmpty
                                    ? '(Sin título)'
                                    : lesson.titleEs,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 5),

                                  Text(
                                    '${lesson.topicEs}\n'
                                    '${lesson.titleEs}\n'
                                    '${lesson.subtitleEs}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.small.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),

                                  if (hasErrors) ...[
                                    const SizedBox(height: 8),

                                    ...lesson.errors.map(
                                      (error) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
                                        child: Text(
                                          '⚠ $error',
                                          style: AppTextStyles.small.copyWith(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              trailing: Icon(
                                hasErrors
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: hasErrors ? Colors.red : AppColors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              if (!_loading && _lessons.isEmpty && _errorMessage == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Selecciona un archivo Excel para comenzar.',
                      style: AppTextStyles.body.copyWith(color: Colors.black54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.small.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
