import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class TaskTabs extends StatelessWidget {
  final bool showingHistory;
  final int activeCount;
  final int historyCount;
  final VoidCallback onShowActive;
  final VoidCallback onShowHistory;

  const TaskTabs({
    super.key,
    required this.showingHistory,
    required this.activeCount,
    required this.historyCount,
    required this.onShowActive,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TaskTabButton(
              label: 'Active ($activeCount)',
              isSelected: !showingHistory,
              onTap: onShowActive,
            ),
          ),
          Expanded(
            child: _TaskTabButton(
              label: 'History ($historyCount)',
              isSelected: showingHistory,
              onTap: onShowHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaskTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppColors.subtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}