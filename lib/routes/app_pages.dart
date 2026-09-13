import 'package:flutter/material.dart';

import 'app_routes.dart';
import '../features/dashboard_screen.dart';
import '../features/topics/topic_lessons_screen.dart';

class AppPages {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.admin: (context) => const DashboardScreen(),

        AppRoutes.adminTopics: (context) => const DashboardScreen(
              initialSection: 'topics',
            ),

        AppRoutes.adminLessons: (context) => const DashboardScreen(
              initialSection: 'lessons',
            ),
      };

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
  ) {
    if (settings.name == AppRoutes.adminTopicLessons) {
      final args = settings.arguments as Map<String, String>;

      return MaterialPageRoute(
        builder: (context) => DashboardScreen(
          initialSection: 'topics',
          initialContent: TopicLessonsScreen(
            topicId: args['topicId']!,
            topicName: args['topicName']!,
          ),
        ),
      );
    }

    return null;
  }
}