import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/excel_import.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/admin_sidebar.dart';
import 'lesson_review_screen.dart';
import '../../services/content_import_service.dart';
import 'dart:typed_data';
import '../../services/multimedia_import_service.dart';
import '../../services/multimedia_import_draft_service.dart';

  

class ImportContentScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ImportContentScreen({super.key, this.onBack});

  @override
  State<ImportContentScreen> createState() => _ImportContentScreenState();
}

class _MultimediaZipData {
    final Uint8List bytes;
    final String name;
    final List<MultimediaLessonPreview> previews;

    _MultimediaZipData({
      required this.bytes,
      required this.name,
      required this.previews,
    });
  }

class _ImportContentScreenState extends State<ImportContentScreen> {
  bool _loading = false;
  String? _fileName;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ExcelImportService _excelImportService = ExcelImportService();
  final ContentImportService _contentImportService = ContentImportService();
  List<ExcelLessonData> _parsedLessons = [];
  List<Map<String, dynamic>> _lessons = [];
  List<bool> _selectedLessons = [];
  final MultimediaImportService _multimediaImportService =
    MultimediaImportService();

  final List<_MultimediaZipData> _multimediaZips = [];

  List<MultimediaLessonPreview> get _multimediaPreviews {
    return _multimediaZips
        .expand((zip) => zip.previews)
        .toList();
  }
   MultimediaLessonPreview? _getMultimediaForLesson(
  ExcelLessonData lesson,
) {
  String normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAllMapped(
          RegExp(r'[áéíóúü]'),
          (match) {
            const replacements = {
              'á': 'a',
              'é': 'e',
              'í': 'i',
              'ó': 'o',
              'ú': 'u',
              'ü': 'u',
            };

            return replacements[match.group(0)] ??
                match.group(0)!;
          },
        )
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  final titleEs = normalize(lesson.titleEs);
  final titleEn = normalize(lesson.titleEn);

  for (final zip in _multimediaZips) {
    for (final preview in zip.previews) {
      var folder = normalize(preview.folderName);

      folder = folder
          .replaceAll('media', '')
          .replaceAll('multimedia', '');

      if (folder == titleEs ||
          folder == titleEn ||
          folder.contains(titleEs) ||
          folder.contains(titleEn) ||
          titleEs.contains(folder) ||
          titleEn.contains(folder)) {
        return preview;
      }

      if (titleEs.contains('alejandro') &&
          titleEn.contains('alexander') &&
          folder.contains('alexander')) {
        return preview;
      }
    }
  }

  return null;
}

Future<void> _pickMultimediaZip() async {
  try {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
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
      throw Exception('No se pudo leer el archivo ZIP.');
    }

    final previews = await _multimediaImportService.analyzeZip(
      file.bytes!,
    );

    setState(() {
      _multimediaZips.add(
        _MultimediaZipData(
          bytes: file.bytes!,
          name: file.name,
          previews: previews,
        ),
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

  Future<void> _importSelectedLessons() async {
    final selectedLessons = <ExcelLessonData>[];
    final selectedIndexes = <int>[];

    for (int i = 0; i < _parsedLessons.length; i++) {
      if (_selectedLessons[i]) {
        selectedLessons.add(_parsedLessons[i]);
        selectedIndexes.add(i);
      }
    }

  if (_fileName == null || _multimediaZips.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Debes seleccionar el archivo Excel y al menos un ZIP de multimedia.',
        ),
      ),
    );
    return;
  }

  if (selectedLessons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Selecciona al menos una lección para importar.',
        ),
      ),
    );
    return;
  }

  String publicationMode = 'all_published';

  final individualPublished = <int, bool>{
    for (final index in selectedIndexes) index: true,
  };

  final shouldContinue = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Publicación de las lecciones'),
            content: SizedBox(
              width: 500,
              height: MediaQuery.of(context).size.height * 0.60,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Cómo deseas publicar las lecciones seleccionadas?',
                    ),

                    const SizedBox(height: 20),

                    RadioListTile<String>(
                      value: 'all_published',
                      groupValue: publicationMode,
                      activeColor: AppColors.primary,
                      title: const Text('Publicar todas'),
                      subtitle: const Text(
                        'Todas quedarán visibles para los usuarios.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          publicationMode = value!;
                        });
                      },
                    ),

                    RadioListTile<String>(
                      value: 'none_published',
                      groupValue: publicationMode,
                      activeColor: AppColors.primary,
                      title: const Text('No publicar ninguna'),
                      subtitle: const Text(
                        'Se subirán pero quedarán ocultas.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          publicationMode = value!;
                        });
                      },
                    ),

                    RadioListTile<String>(
                      value: 'individual',
                      groupValue: publicationMode,
                      activeColor: AppColors.primary,
                      title: const Text('Elegir individualmente'),
                      subtitle: const Text(
                        'Selecciona cuáles estarán publicadas.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          publicationMode = value!;
                        });
                      },
                    ),

                    if (publicationMode == 'individual') ...[
                      const Divider(height: 25),

                      const Text(
                        'Selecciona las lecciones que estarán publicadas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      ...selectedIndexes.map((index) {
                        return CheckboxListTile(
                          value: individualPublished[index] ?? true,
                          activeColor: AppColors.primary,
                          title: Text(
                            _parsedLessons[index].titleEs,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              individualPublished[index] =
                                  value ?? false;
                            });
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('CONTINUAR'),
              ),
            ],
          );
        },
      );
    },
  );

  if (shouldContinue != true) {
    return;
  }

  if (!mounted) return;

  setState(() {
    _loading = true;
    _errorMessage = null;
  });

  int importedCount = 0;
  int duplicateCount = 0;
  int errorCount = 0;
  final errorMessages = <String>[];

  try {
    for (int i = 0; i < selectedLessons.length; i++) {
      final lesson = selectedLessons[i];
      final originalIndex = selectedIndexes[i];

      bool isPublished;

      if (publicationMode == 'all_published') {
        isPublished = true;
      } else if (publicationMode == 'none_published') {
        isPublished = false;
      } else {
        isPublished =
            individualPublished[originalIndex] ?? false;
      }

      final contentResult =
          await _contentImportService.importLesson(
        lesson,
        isPublished: isPublished,
      );

      if (contentResult.duplicate) {
        duplicateCount++;
        continue;
      }

      if (!contentResult.imported ||
          contentResult.lessonId == null) {
        errorCount++;
        errorMessages.add(
          '${lesson.titleEs}: ${contentResult.message}',
        );
        continue;
      }

      final multimediaPreview =
          _getMultimediaForLesson(lesson);

      final draft =
          MultimediaImportDraftService.instance.getLessonDraft(
        _normalizeLessonId(lesson.titleEs),
      );

  if (multimediaPreview != null) {
    _MultimediaZipData? multimediaZip;

    for (final zip in _multimediaZips) {
      if (zip.previews.contains(multimediaPreview)) {
        multimediaZip = zip;
        break;
      }
    }

    if (multimediaZip != null) {
      final draftFiles = <String, Uint8List>{};

      if (draft != null) {
        for (final entry in draft.files.entries) {
          draftFiles[entry.key] = entry.value.bytes;
        }
      }

      await _multimediaImportService.uploadLessonMultimedia(
        zipBytes: multimediaZip.bytes,
        folderName: multimediaPreview.folderName,
        lessonId: contentResult.lessonId!,
        draftFiles: draftFiles,
      );
    }
  }

      importedCount++;
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (errorCount == 0) {
      MultimediaImportDraftService.instance.clear();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Importación finalizada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Importadas: $importedCount'),
              const SizedBox(height: 6),
              Text('Duplicadas: $duplicateCount'),
              const SizedBox(height: 6),
              Text('Con problemas: $errorCount'),

              if (errorMessages.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Problemas:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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
              onPressed: () {
              Navigator.pop(context);
              widget.onBack?.call();
            },
              child: const Text('ACEPTAR'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');
    });
  }
}

String _normalizeLessonId(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAllMapped(
        RegExp(r'[áéíóúü]'),
        (match) {
          const replacements = {
            'á': 'a',
            'é': 'e',
            'í': 'i',
            'ó': 'o',
            'ú': 'u',
            'ü': 'u',
          };

          return replacements[match.group(0)] ??
              match.group(0)!;
        },
      )
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
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
      parsedLessons.sort(
        (a, b) => _normalizeLessonId(a.titleEs)
            .compareTo(_normalizeLessonId(b.titleEs)),
      );

      setState(() {
        _fileName = file.name;
        _lessons = lessons;
        _parsedLessons = parsedLessons;

        _selectedLessons = List.generate(
          parsedLessons.length,
          (index) => false,
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<int> get _filteredLessonIndexes {
    if (_searchQuery.trim().isEmpty) {
      return List.generate(_parsedLessons.length, (index) => index);
    }

    final query = _normalizeLessonId(_searchQuery);

    return List.generate(_parsedLessons.length, (index) => index)
        .where((index) {
          final lesson = _parsedLessons[index];

          final titleEs = _normalizeLessonId(lesson.titleEs);
          final titleEn = _normalizeLessonId(lesson.titleEn);

          return titleEs.contains(query) || titleEn.contains(query);
        })
        .toList();
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

            
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // PASO 1
               Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickExcel,
                    icon: const Icon(Icons.insert_drive_file_outlined),
                    label: const Text('Paso 1 · Seleccionar Excel'),
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
                  if (_fileName != null) ...[
                   const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          child: Text(
                            _fileName!,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.darkBrown,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _fileName = null;
                              _lessons = [];
                              _parsedLessons = [];
                              _selectedLessons = [];
                            });
                          },
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                          ),
                          tooltip: 'Eliminar Excel',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              // PASO 2
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading || _parsedLessons.isEmpty
                        ? null
                        : _pickMultimediaZip,
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Paso 2 · Importar multimedia'),
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
                 if (_multimediaZips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._multimediaZips.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final zip = entry.value;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Text(
                              zip.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.darkBrown,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _multimediaZips.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                            ),
                            tooltip: 'Eliminar ZIP',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                ],
              ),

                // PASO 3
                if (_parsedLessons.isNotEmpty && _multimediaPreviews.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _importSelectedLessons,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Paso 3 · Subir seleccionadas'),
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

                // NOMBRE DEL ARCHIVO
              
              ],
            ),            if (_parsedLessons.isNotEmpty) ...[
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],



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

                if (_multimediaPreviews.isNotEmpty) ...[                  
                ],

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

                                       const SizedBox(width: 10),
                    _StatusBadge(
                      label: '${_parsedLessons.where((lesson) {
                        final multimediaPreview = _getMultimediaForLesson(lesson);

                        final multimediaWarningCount = multimediaPreview == null
                            ? 1
                            : multimediaPreview.warnings.length;
                        return lesson.warnings.isNotEmpty ||
                            multimediaWarningCount > 0;
                      }).length} con advertencias',
                      color: Colors.orange,
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
                      itemCount: _filteredLessonIndexes.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final lessonIndex = _filteredLessonIndexes[index];
                        final lesson = _parsedLessons[lessonIndex];
                        //final hasErrors = !lesson.isValid;
                        final multimediaPreview = _getMultimediaForLesson(lesson);

                        final multimediaWarningCount = multimediaPreview == null
                            ? 1
                            : multimediaPreview.warnings.length;                        
                            final warningCount =
                              lesson.warnings.length + multimediaWarningCount;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LessonReviewScreen(
                                    lessons: _parsedLessons,
                                    initialIndex: lessonIndex,
                                    multimediaPreviews: _multimediaPreviews,
                                    multimediaZipBytes: _multimediaZips
                                        .map((zip) => zip.bytes)
                                        .toList(),
                                  ),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _selectedLessons[lessonIndex],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedLessons[lessonIndex] =
                                            value ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  CircleAvatar(
                                    backgroundColor: warningCount > 0
                                        ? Colors.orange.withValues(alpha: 0.12)
                                        : AppColors.green.withValues(alpha: 0.15),
                                    child: warningCount > 0
                                        ? const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange,
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

                                  if (lesson.warnings.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...lesson.warnings.map(
                                      (warning) => Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          '⚠ $warning',
                                          style: AppTextStyles.small.copyWith(
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (warningCount > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        warningCount == 1
                                            ? '1 advertencia'
                                            : '$warningCount advertencias',
                                        style: AppTextStyles.small.copyWith(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                 Icon(
                                    warningCount > 0
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    color: warningCount > 0
                                        ? Colors.orange
                                        : AppColors.green,
                                  ),
                                ],
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
