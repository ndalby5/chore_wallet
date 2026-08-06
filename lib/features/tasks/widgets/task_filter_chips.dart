import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

enum TaskStatusFilter {
  all,
  pending,
  awaitingApproval,
  approved,
  cancelled,
  declined,
}

class TaskFilterChips extends StatelessWidget {
  final bool showingHistory;
  final TaskStatusFilter selectedFilter;
  final ValueChanged<TaskStatusFilter> onChanged;

  const TaskFilterChips({
    super.key,
    required this.showingHistory,
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = showingHistory
        ? const [
            TaskStatusFilter.all,
            TaskStatusFilter.approved,
            TaskStatusFilter.cancelled,
            TaskStatusFilter.declined,
          ]
        : const [
            TaskStatusFilter.all,
            TaskStatusFilter.pending,
            TaskStatusFilter.awaitingApproval,
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0;
              index < filters.length;
              index++) ...[
            _TaskFilterChip(
              label: _label(filters[index]),
              isSelected:
                  selectedFilter == filters[index],
              onTap: () => onChanged(filters[index]),
            ),
            if (index < filters.length - 1)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _label(TaskStatusFilter filter) {
    switch (filter) {
      case TaskStatusFilter.pending:
        return 'Pending';

      case TaskStatusFilter.awaitingApproval:
        return 'Awaiting approval';

      case TaskStatusFilter.approved:
        return 'Approved';

      case TaskStatusFilter.cancelled:
        return 'Cancelled';

      case TaskStatusFilter.declined:
        return 'Declined';

      case TaskStatusFilter.all:
        return 'All';
    }
  }
}

class _TaskFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaskFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 160,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFFEAE8F2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppColors.subtitle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}