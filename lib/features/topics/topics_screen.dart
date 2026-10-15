import 'package:flutter/material.dart';

import '../../models/topic.dart';
import '../../services/topic_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../../routes/app_routes.dart';

class TopicsScreen extends StatefulWidget {
  final void Function(String topicId, String topicName)?
      onTopicSelected;

  const TopicsScreen({
    super.key,
    this.onTopicSelected,
  });

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TopicService _topicService = TopicService();
  late Future<List<Topic>> _topicsFuture;
  String _selectedFilter = 'az';
  String? _editingTopicId;
  final ScrollController _verticalController = ScrollController();
  final TextEditingController _editNameEsController = TextEditingController();
  final TextEditingController _editNameEnController = TextEditingController();
  late Future<Map<String, int>> _lessonCountsFuture;

  @override
  void initState() {
    super.initState();

    _topicsFuture = _topicService.searchTopics(
      '',
      filter: _selectedFilter,
    );
    _lessonCountsFuture = _topicService.getLessonCountsByTopic();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  void _startEditing(Topic topic) {
    setState(() {
      _editingTopicId = topic.id;

      _editNameEsController.text = topic.nameEs;
      _editNameEnController.text = topic.nameEn;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingTopicId = null;

      _editNameEsController.clear();
      _editNameEnController.clear();
    });
  }
  
  Future<void> _addTopic() async {
    final nameEsController = TextEditingController();
    final nameEnController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Añadir tópico',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.darkBrown,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameEsController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre en español',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre en español';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameEnController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre en inglés',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre en inglés';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                try {
                  final nameEs = nameEsController.text.trim();
                  final nameEn = nameEnController.text.trim();

                  final slug = nameEn
                      .toLowerCase()
                      .trim()
                      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                      .replaceAll(RegExp(r'^-+|-+$'), '');

                  await _topicService.createTopic(
                    nameEs: nameEs,
                    nameEn: nameEn,
                    slug: slug,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  debugPrint('ERROR CREANDO TÓPICO: $e');

                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se pudo crear el tópico.',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar tópico'),
            ),
          ],
        );
      },
    );

    nameEsController.dispose();
    nameEnController.dispose();

    if (saved == true && mounted) {
      setState(() {
        _topicsFuture = _topicService.searchTopics(
          _searchController.text.trim(),
          filter: _selectedFilter,
        );
        _lessonCountsFuture =
            _topicService.getLessonCountsByTopic();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tópico creado correctamente.'),
        ),
      );
    }
  }


  Future<void> _searchTopics() async {
    setState(() {
      _topicsFuture = _topicService.searchTopics(
        _searchController.text.trim(),
        filter: _selectedFilter,
      );
    });
  }

  Future<void> _changeFilter(String value) async {
    setState(() {
      _selectedFilter = value;
    });

    final counts = await _lessonCountsFuture;

    final topicsFuture = _topicService.searchTopics(
      _searchController.text.trim(),
      filter: value,
      lessonCounts: counts,
    );

    setState(() {
      _topicsFuture = topicsFuture;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();

    _editNameEsController.dispose();
    _editNameEnController.dispose();

    _verticalController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double tableWidth = 1175;

    return Padding(
      padding: const EdgeInsets.all(40),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(
            'Tópicos',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.darkBrown,
            ),
          ),

         const SizedBox(height: 30),

        SizedBox(
          width: tableWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _addTopic,
                icon: const Icon(Icons.add),
                label: Text(
                  'Añadir tópico',
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
                    icon: const Icon(Icons.filter_list),
                    onSelected: _changeFilter,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'za',
                        child: Text('Z-A'),
                      ),
                      PopupMenuItem(
                        value: 'recientes',
                        child: Text('Más recientes'),
                      ),
                      PopupMenuItem(
                        value: 'antiguos',
                        child: Text('Más antiguos'),
                      ),
                      PopupMenuItem(
                        value: 'mas_lecciones',
                        child: Text('Más lecciones'),
                      ),
                      PopupMenuItem(
                        value: 'menos_lecciones',
                        child: Text('Menos lecciones'),
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
                        _searchTopics();
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchTopics,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
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
            child: FutureBuilder<List<Topic>>(
              future: _topicsFuture,

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No se pudieron cargar los tópicos.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.darkBrown,
                      ),
                    ),
                  );
                }

                final topics = snapshot.data ?? [];

                if (topics.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay tópicos disponibles.',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  );
                }

                return Column(
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
                        headingRowColor:
                            WidgetStateProperty.all(
                          AppColors.green.withValues(alpha: 0.12),
                        ),

                        columns: [
                          

                          DataColumn(
                            label: SizedBox(
                              width: 250,
                             child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Nombre ES',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          
                          DataColumn(
                            label: SizedBox(
                              width: 250,

                              child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  'Nombre EN',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          
                          DataColumn(
                            label: SizedBox(
                              width: 220,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Fecha de subida',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          
                          DataColumn(
                            label: SizedBox(
                              width: 150,
                              child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  'Estado',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        DataColumn(
                          label: SizedBox(
                            width: 150,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Lecciones',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.darkBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                          
                          DataColumn(
                            label: SizedBox(
                              width: 155,
                              child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  'Acciones',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.darkBrown,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
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

                          scrollDirection: Axis.vertical,

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
                                    width: 250,
                                  ),
                                ),

                                DataColumn(
                                  label: SizedBox(
                                    width: 250,
                                  ),
                                ),

                                DataColumn(
                                  label: SizedBox(
                                    width: 220,
                                  ),
                                ),

                                DataColumn(
                                  label: SizedBox(
                                    width: 150,
                                  ),
                                ),

                                DataColumn(
                                  label: SizedBox(width: 150),
                                ),

                                DataColumn(
                                  label: SizedBox(
                                    width: 155,
                                  ),
                                ),
                              ],

                              rows: topics.map((topic) {
                                final bool isEditing =
                                    _editingTopicId == topic.id;

                                return DataRow(
                                  cells: [
                                    
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 250,

                                              child: TextField(
                                                controller:
                                                    _editNameEsController,

                                                decoration:
                                                    const InputDecoration(
                                                  border:
                                                      OutlineInputBorder(),

                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Align(
                                              alignment:
                                                  Alignment.centerLeft,

                                              child: Text(
                                                topic.nameEs,

                                                style: AppTextStyles.body
                                                    .copyWith(
                                                  color:
                                                      AppColors.darkBrown,
                                                ),
                                              ),
                                            ),
                                    ),

                                   
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 250,

                                              child: TextField(
                                                controller:
                                                    _editNameEnController,

                                                decoration:
                                                    const InputDecoration(
                                                  border:
                                                      OutlineInputBorder(),

                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Align(
                                              alignment:
                                                  Alignment.centerLeft,

                                              child: Text(
                                                topic.nameEn,

                                                style: AppTextStyles.body
                                                    .copyWith(
                                                  color:
                                                      AppColors.darkBrown,
                                                ),
                                              ),
                                            ),
                                    ),

                                    
                                    DataCell(
                                      Align(
                                        alignment:
                                            Alignment.centerLeft,

                                        child: Text(
                                          _formatDate(
                                            topic.createdAt,
                                          ),

                                          style: AppTextStyles.body.copyWith(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),

                                    
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Align(
                                          alignment:
                                              Alignment.centerLeft,

                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),

                                            decoration: BoxDecoration(
                                              color: AppColors.green
                                                  .withValues(alpha: 0.20),

                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),

                                            child: Text(
                                              'Habilitado',

                                              softWrap: false,

                                              style: AppTextStyles.body
                                                  .copyWith(
                                                color:
                                                    AppColors.darkBrown,

                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: FutureBuilder<Map<String, int>>(
                                            future: _lessonCountsFuture,
                                            builder: (context, snapshot) {
                                              final counts = snapshot.data ?? {};
                                              return Text(
                                                '${counts[topic.id] ?? 0}',
                                                style: AppTextStyles.body.copyWith(
                                                  color: AppColors.darkBrown,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),

                                    DataCell(
                                      SizedBox(
                                        width: 155,
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,

                                          children: [
                                            if (isEditing) ...[
                                             
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.check,
                                                ),

                                                tooltip: 'Guardar',

                                                onPressed: () async {
                                                  try {
                                                    await _topicService
                                                        .updateTopic(
                                                      id: topic.id,

                                                      nameEs:
                                                          _editNameEsController
                                                              .text
                                                              .trim(),

                                                      nameEn:
                                                          _editNameEnController
                                                              .text
                                                              .trim(),
                                                    );

                                                    setState(() {
                                                      _editingTopicId = null;
                                                    });

                                                    _topicsFuture =
                                                        _topicService
                                                            .searchTopics(
                                                      _searchController.text
                                                          .trim(),

                                                      filter:
                                                          _selectedFilter,
                                                    );

                                                    setState(() {});
                                                  } catch (e) {
                                                    print(
                                                      'Error actualizando tópico: $e',
                                                    );
                                                  }
                                                },
                                              ),

                                             
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                ),

                                                tooltip: 'Cancelar',

                                                onPressed:
                                                    _cancelEditing,
                                              ),
                                            ] else ...[
                                             
                                           IconButton(
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                            ),
                                            tooltip: 'Ver',
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.adminTopicLessons,
                                                arguments: {
                                                  'topicId': topic.id,
                                                  'topicName': topic.nameEs,
                                                },
                                              );
                                            },
                                          ),

                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),

                                                tooltip: 'Editar',

                                                onPressed: () {
                                                  _startEditing(topic);
                                                },
                                              ),
                                            ],
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
    );
  }
}