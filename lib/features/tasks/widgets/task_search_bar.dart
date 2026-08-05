import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class TaskSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool showingHistory;

  const TaskSearchBar({
    super.key,
    required this.controller,
    required this.showingHistory,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: showingHistory
            ? 'Search task history'
            : 'Search active tasks',
        prefixIcon: const Icon(
          Icons.search,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: controller.clear,
                icon: const Icon(
                  Icons.close,
                ),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFEAE8F2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}