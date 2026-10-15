import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../services/lesson_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'lesson_detail_screen.dart';
import '../import/import_content_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final TextEditingController _searchController =
      TextEditingController();
  final LessonService _lessonService = LessonService();
  late Future<List<Lesson>> _lessonsFuture;
  String _selectedFilter = 'fecha';
  final ScrollController _verticalController =
      ScrollController();
  static const double tableWidth = 1025;
  Lesson? _selectedLesson;
  bool _showImportScreen = false;

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _loadLessons();
  }

  Future<List<Lesson>> _loadLessons() async {
    return await _lessonService.searchLessons(
      _searchController.text.trim(),
      filter: _selectedFilter,
    );
  }

  Future<void> _searchLessons() async {
    setState(() {
      _lessonsFuture = _loadLessons();
    });
  }

  void _changeFilter(String value) {
    setState(() {
      _selectedFilter = value;
      _lessonsFuture = _loadLessons();
    });
  }

  Future<void> _changePublishedStatus(
  Lesson lesson,
  bool isPublished,
) async {
  try {
    await Supabase.instance.client
        .from('lessons')
        .update({
          'is_published': isPublished,
        })
        .eq('id', lesson.id);

    setState(() {
      _lessonsFuture = _loadLessons();
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo cambiar el estado de la lección.'),
      ),
    );
  }
}

  @override
  void dispose() {
    _searchController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      if (_showImportScreen) {
      return ImportContentScreen(
        onBack: () {
          setState(() {
            _showImportScreen = false;
            _lessonsFuture = _loadLessons();
          });
        },
      );
}
      if (_selectedLesson != null) {
    return LessonDetailScreen(
      lesson: _selectedLesson!,
      onBack: () {
        setState(() {
          _selectedLesson = null;
        });
      },
    );
  }
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lecciones',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.darkBrown,
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: tableWidth,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Añadir contenido',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.darkBrown,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                ListTile(
                                  leading: Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.green,
                                  ),
                                  title: Text(
                                    'Añadir lección manualmente',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.darkBrown,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);

                                  },
                                ),

                                ListTile(
                                  leading: Icon(
                                    Icons.upload_file_outlined,
                                    color: AppColors.green,
                                  ),
                                  title: Text(
                                    'Importar desde Excel',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.darkBrown,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Importar lecciones desde un archivo Excel',
                                    style: AppTextStyles.small.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    
                                    setState(() {
                                      _showImportScreen = true;
                                    });
                                  },
                                ),

                                const SizedBox(height: 10),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Añadir lección',
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

                Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Filtrar',
                      icon: const Icon(
                        Icons.filter_list,
                      ),
                      onSelected: _changeFilter,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'fecha',
                          child: Text('Fecha'),
                        ),
                        PopupMenuItem(
                          value: 'az',
                          child: Text('A-Z'),
                        ),
                        PopupMenuItem(
                          value: 'za',
                          child: Text('Z-A'),
                        ),
                      ],
                    ),

                    const SizedBox(width: 10),

                    SizedBox(
                      width: 280,
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) {
                          _searchLessons();
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.search,
                            ),
                            onPressed: _searchLessons,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: FutureBuilder<List<Lesson>>(
              future: _lessonsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No se pudieron cargar las lecciones.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.darkBrown,
                      ),
                    ),
                  );
                }

                final lessons = snapshot.data ?? [];

                if (lessons.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay lecciones disponibles.',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    SizedBox(
                      width: tableWidth,
                      child: DataTable(
                        columnSpacing: 0,
                        horizontalMargin: 0,
                        headingRowHeight: 55,
                        dataRowMinHeight: 0,
                        dataRowMaxHeight: 0,
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.green.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        columns: [
                          _buildHeader('Título ES', 210),
                          _buildHeader('Título EN', 210),
                          _buildHeader('Subtítulo ES', 300),
                          _buildHeader('Estado', 140, centered: true),
                          _buildHeader('Acciones', 165, centered: true),
                        ],
                        rows: const [],
                      ),
                    ),

                    Expanded(
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          child: SizedBox(
                            width: tableWidth,
                            child: DataTable(
                              columnSpacing: 0,
                              horizontalMargin: 0,
                              headingRowHeight: 0,
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 70,
                              columns: const [
                                DataColumn(
                                  label: SizedBox(width: 210),
                                ),
                                DataColumn(
                                  label: SizedBox(width: 210),
                                ),
                                DataColumn(
                                  label: SizedBox(width: 300),
                                ),
                                DataColumn(
                                  label: SizedBox(width: 140),
                                ),
                                DataColumn(
                                  label: SizedBox(width: 165),
                                ),
                              ],
                              rows: lessons.map((lesson) {
                                  return DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 210,
                                        child: Text(
                                          lesson.titleEs,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body.copyWith(
                                            color: AppColors.darkBrown,
                                          ),
                                        ),
                                      ),
                                    ),

                                    DataCell(
                                      SizedBox(
                                        width: 210,
                                        child: Text(
                                          lesson.titleEn,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body.copyWith(
                                            color: AppColors.darkBrown,
                                          ),
                                        ),
                                      ),
                                    ),

                                    DataCell(
                                      SizedBox(
                                        width: 300,
                                        child: Text(
                                          lesson.subtitleEs ?? '-',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body.copyWith(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),

                                DataCell(
                                  SizedBox(
                                    width: 140,
                                    child: Center(
                                      child: PopupMenuButton<bool>(
                                        tooltip: 'Cambiar estado',
                                        onSelected: (value) {
                                          _changePublishedStatus(lesson, value);
                                        },
                                        itemBuilder: (context) => [
                                          if (lesson.isPublished == true)
                                            const PopupMenuItem<bool>(
                                              value: false,
                                              child: Text('No publicado'),
                                            )
                                          else
                                            const PopupMenuItem<bool>(
                                              value: true,
                                              child: Text('Publicado'),
                                            ),
                                        ],
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.green.withValues(alpha: 0.20),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            lesson.isPublished == true
                                                ? 'Publicado'
                                                : 'No publicado',
                                            style: AppTextStyles.body.copyWith(
                                              color: AppColors.darkBrown,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                    DataCell(
                                      SizedBox(
                                        width: 165,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                              ),
                                              tooltip: 'Ver',
                                              onPressed: () {
                                                setState(() {
                                                  _selectedLesson = lesson;
                                                });
                                              },
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildHeader(
    String title,
    double width, {
    bool centered = false,
  }) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Align(
          alignment: centered
              ? Alignment.center
              : Alignment.centerLeft,
          child: Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}