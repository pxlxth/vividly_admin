import 'package:flutter/material.dart';

import '../../services/dashboard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AdminDashboardContent extends StatefulWidget {
  const AdminDashboardContent({super.key});

  @override
  State<AdminDashboardContent> createState() =>
      _AdminDashboardContentState();
}

class _AdminDashboardContentState
    extends State<AdminDashboardContent> {
  final DashboardService _dashboardService = DashboardService();

  late Future<List<int>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _loadDashboardData();
  }

  Future<List<int>> _loadDashboardData() async {
    final topics = await _dashboardService.getTopicsCount();
    final lessons = await _dashboardService.getLessonsCount();
    final users = await _dashboardService.getUsersCount();

    return [
      topics,
      lessons,
      users,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.darkBrown,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Bienvenido al panel de administración de Vividly.',
            style: AppTextStyles.body.copyWith(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 40),

          FutureBuilder<List<int>>(
            future: _dashboardData,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar los datos.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.darkBrown,
                  ),
                );
              }

              final data = snapshot.data ?? [0, 0, 0];

              return Row(
                children: [
                  _DashboardCard(
                    title: 'Tópicos',
                    value: data[0].toString(),
                    icon: Icons.category_outlined,
                  ),

                  const SizedBox(width: 20),

                  _DashboardCard(
                    title: 'Lecciones',
                    value: data[1].toString(),
                    icon: Icons.menu_book_outlined,
                  ),

                  const SizedBox(width: 20),

                  _DashboardCard(
                    title: 'Usuarios',
                    value: data[2].toString(),
                    icon: Icons.people_outline,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: AppColors.green,
            ),

            const SizedBox(width: 18),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.darkBrown,
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