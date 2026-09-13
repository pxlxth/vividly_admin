import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../services/lesson_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../lessons/lesson_detail_screen.dart';

class TopicLessonsScreen extends StatefulWidget {
  final String topicId;
  final String topicName;
  final VoidCallback? onBack;

  const TopicLessonsScreen({
    super.key,
    required this.topicId,
    required this.topicName,
    this.onBack,
  });

  @override
  State<TopicLessonsScreen> createState() => _TopicLessonsScreenState();
}

class _TopicLessonsScreenState extends State<TopicLessonsScreen> {
  final LessonService _lessonService = LessonService();

  final TextEditingController _searchController =
      TextEditingController();

  final ScrollController _verticalController =
      ScrollController();

  late Future<List<Lesson>> _lessonsFuture;

  String _selectedFilter = 'fecha';

  @override
  void initState() {
    super.initState();

    _loadLessons();
  }

  void _loadLessons() {
    _lessonsFuture =
        _lessonService.getLessonsByTopic(widget.topicId);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  List<Lesson> _filterLessons(List<Lesson> lessons) {
    final search = _searchController.text.trim().toLowerCase();

    List<Lesson> result = lessons.where((lesson) {
      if (search.isEmpty) return true;

      return lesson.titleEs.toLowerCase().contains(search) ||
          lesson.titleEn.toLowerCase().contains(search);
    }).toList();

    if (_selectedFilter == 'az') {
      result.sort(
        (a, b) => a.titleEs.compareTo(b.titleEs),
      );
    }

    if (_selectedFilter == 'za') {
      result.sort(
        (a, b) => b.titleEs.compareTo(a.titleEs),
      );
    }

    if (_selectedFilter == 'fecha') {
      result.sort((a, b) {
        final dateA = a.createdAt;
        final dateB = b.createdAt;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });
    }

    return result;
  }

  void _searchLessons() {
    setState(() {});
  }

  void _changeFilter(String value) {
    setState(() {
      _selectedFilter = value;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalController.dispose();

    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    const double tableWidth = 1025;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // VOLVER A TÓPICOS
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.darkBrown,
                          tooltip: 'Volver',
                          onPressed: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),

                        const SizedBox(width: 8),

                        GestureDetector(
                          onTap: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: Text(
                            'Tópicos',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.darkBrown,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // NOMBRE DEL TÓPICO
                    Text(
                      widget.topicName,
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.darkBrown,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // BUSCADOR + FILTRO
                    SizedBox(
                      width: tableWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PopupMenuButton<String>(
                            tooltip: 'Filtrar',
                            icon: const Icon(Icons.filter_list),
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
                                  icon: const Icon(Icons.search),
                                  onPressed: _searchLessons,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
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
                    ),

                    const SizedBox(height: 20),

                    // TABLA
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

                          final allLessons = snapshot.data ?? [];

                          final lessons =
                              _filterLessons(allLessons);

                          if (lessons.isEmpty) {
                            return Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? 'No hay lecciones disponibles para este tópico.'
                                    : 'No se encontraron lecciones.',
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // ENCABEZADO DE LA TABLA
                              SizedBox(
                                width: tableWidth,
                                child: DataTable(
                                  columnSpacing: 0,
                                  horizontalMargin: 0,
                                  headingRowHeight: 55,
                                  dataRowMinHeight: 0,
                                  dataRowMaxHeight: 0,
                                  headingRowColor:
                                      WidgetStateProperty.all(
                                    AppColors.green.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: SizedBox(
                                        width: 300,
                                        child: Center(
                                          child: Text(
                                            'Nombre ES',
                                            style: AppTextStyles.body
                                                .copyWith(
                                              color:
                                                  AppColors.darkBrown,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 300,
                                        child: Center(
                                          child: Text(
                                            'Nombre EN',
                                            style: AppTextStyles.body
                                                .copyWith(
                                              color:
                                                  AppColors.darkBrown,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 180,
                                        child: Center(
                                          child: Text(
                                            'Fecha de subida',
                                            style: AppTextStyles.body
                                                .copyWith(
                                              color:
                                                  AppColors.darkBrown,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 140,
                                        child: Center(
                                          child: Text(
                                            'Estado',
                                            style: AppTextStyles.body
                                                .copyWith(
                                              color:
                                                  AppColors.darkBrown,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 125,
                                        child: Center(
                                          child: Text(
                                            'Acciones',
                                            style: AppTextStyles.body
                                                .copyWith(
                                              color:
                                                  AppColors.darkBrown,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: const [],
                                ),
                              ),

                              // CONTENIDO DE LA TABLA
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
                                            label: SizedBox(
                                              width: 300,
                                            ),
                                          ),
                                          DataColumn(
                                            label: SizedBox(
                                              width: 300,
                                            ),
                                          ),
                                          DataColumn(
                                            label: SizedBox(
                                              width: 180,
                                            ),
                                          ),
                                          DataColumn(
                                            label: SizedBox(
                                              width: 140,
                                            ),
                                          ),
                                          DataColumn(
                                            label: SizedBox(
                                              width: 125,
                                            ),
                                          ),
                                        ],
                                        rows: lessons.map((lesson) {
                                          return DataRow(
                                            cells: [
                                              // NOMBRE ES
                                              DataCell(
                                                SizedBox(
                                                  width: 300,
                                                  child: Align(
                                                    alignment:
                                                        Alignment
                                                            .centerLeft,
                                                    child: Text(
                                                      lesson.titleEs,
                                                      style: AppTextStyles
                                                          .body
                                                          .copyWith(
                                                        color: AppColors
                                                            .darkBrown,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // NOMBRE EN
                                              DataCell(
                                                SizedBox(
                                                  width: 300,
                                                  child: Align(
                                                    alignment:
                                                        Alignment
                                                            .centerLeft,
                                                    child: Text(
                                                      lesson.titleEn,
                                                      style: AppTextStyles
                                                          .body
                                                          .copyWith(
                                                        color: AppColors
                                                            .darkBrown,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // FECHA
                                              DataCell(
                                                SizedBox(
                                                  width: 180,
                                                  child: Align(
                                                    alignment:
                                                        Alignment
                                                            .centerLeft,
                                                    child: Text(
                                                      _formatDate(
                                                        lesson.createdAt,
                                                      ),
                                                      style: AppTextStyles
                                                          .body
                                                          .copyWith(
                                                        color: Colors
                                                            .black54,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // ESTADO
                                              DataCell(
                                                SizedBox(
                                                  width: 140,
                                                  child: Align(
                                                    alignment:
                                                        Alignment
                                                            .centerLeft,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: AppColors
                                                            .green
                                                            .withValues(
                                                          alpha: 0.20,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          20,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        lesson.isPublished ==
                                                                true
                                                            ? 'Publicado'
                                                            : 'No publicado',
                                                        softWrap: false,
                                                        style:
                                                            AppTextStyles
                                                                .body
                                                                .copyWith(
                                                          color: AppColors
                                                              .darkBrown,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // ACCIONES
                                              DataCell(
                                                SizedBox(
                                                  width: 125,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .visibility_outlined,
                                                        ),
                                                        tooltip: 'Ver',
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder:
                                                                  (context) =>
                                                                      LessonDetailScreen(
                                                                lesson:
                                                                    lesson,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .edit_outlined,
                                                        ),
                                                        tooltip: 'Editar',
                                                        onPressed: () {},
                                                      ),
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
}