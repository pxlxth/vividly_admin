import 'package:flutter/material.dart';

import '../../widgets/admin_sidebar.dart';

import 'topics/topics_screen.dart';
import 'topics/topic_lessons_screen.dart';
import 'lessons/lesson_screen.dart';
import 'dashboard/admin_dashboard_content.dart';

class DashboardScreen extends StatefulWidget {
  final String initialSection;
  final Widget? initialContent;

  const DashboardScreen({
    super.key,
    this.initialSection = 'dashboard',
    this.initialContent,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  String? _selectedTopicId;
  String? _selectedTopicName;

  Widget? _topicLessonsScreen;

  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();

    if (widget.initialSection == 'topics') {
      _selectedIndex = 1;
    } else if (widget.initialSection == 'lessons') {
      _selectedIndex = 2;
    } else {
      _selectedIndex = 0;
    }

    _screens = [
      const AdminDashboardContent(),
      null,
      null,
    ];

    if (widget.initialSection == 'topics') {
      _screens[1] = _createTopicsScreen();
    }

    if (widget.initialSection == 'lessons') {
      _screens[2] = const LessonScreen();
    }

    if (widget.initialContent != null) {
      _screens[_selectedIndex] = widget.initialContent;
    }
  }


  Widget _createTopicsScreen() {
    return TopicsScreen(
      onTopicSelected: (topicId, topicName) {
        setState(() {
          _selectedTopicId = topicId;
          _selectedTopicName = topicName;

          _topicLessonsScreen = TopicLessonsScreen(
            topicId: topicId,
            topicName: topicName,
            onBack: () {
              setState(() {
                _selectedTopicId = null;
                _selectedTopicName = null;
                _topicLessonsScreen = null;
              });
            },
          );
        });
      },
    );
  }

  Widget _getTopicsContent() {
    if (_selectedTopicId == null) {
      return _screens[1] ??= _createTopicsScreen();
    }

    return _topicLessonsScreen!;
  }

  String get _selectedSection {
    switch (_selectedIndex) {
      case 1:
        return 'topics';

      case 2:
        return 'lessons';

      case 0:
      default:
        return 'dashboard';
    }
  }

  void _selectSection(String section) {
    setState(() {
      switch (section) {
        case 'dashboard':
          _selectedIndex = 0;
          break;

        case 'topics':
          _selectedIndex = 1;

          _screens[1] ??= _createTopicsScreen();
          break;

        case 'lessons':
          _selectedIndex = 2;

          _screens[2] ??= const LessonScreen();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AdminSidebar(
              selectedSection: _selectedSection,
              onSectionSelected: _selectSection,
            ),

            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _screens[0]!,

                  _getTopicsContent(),

                  _screens[2] ?? const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}