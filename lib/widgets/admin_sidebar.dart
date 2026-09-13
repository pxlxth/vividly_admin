import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AdminSidebar extends StatelessWidget {
  final String selectedSection;
  final ValueChanged<String> onSectionSelected;

  const AdminSidebar({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vividly',
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Admin',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // Dashboard
          _HoverMenuItem(
            title: 'Dashboard',
            isSelected: selectedSection == 'dashboard',
            onTap: () {
              onSectionSelected('dashboard');
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 1,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),

          // Tópicos
          _HoverMenuItem(
            title: 'Tópicos',
            isSelected: selectedSection == 'topics',
            onTap: () {
              onSectionSelected('topics');
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 1,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),

          // Lecciones
          _HoverMenuItem(
            title: 'Lecciones',
            isSelected: selectedSection == 'lessons',
            onTap: () {
              onSectionSelected('lessons');
            },
          ),
        ],
      ),
    );
  }
}

class _HoverMenuItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoverMenuItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<_HoverMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;

    if (widget.isSelected) {
      backgroundColor = AppColors.primary;
    } else if (_isHovered) {
      backgroundColor = AppColors.peach;
    } else {
      backgroundColor = AppColors.green;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 24,
          ),
          color: backgroundColor,
          child: Text(
            widget.title,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}