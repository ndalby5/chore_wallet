import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class TaskStatusBadge extends StatelessWidget {
  final String status;

  const TaskStatusBadge({
    super.key,
    required this.status,
  });

  String get _label {
    switch (status) {
      case 'completed':
        return 'Awaiting approval';

      case 'approved':
        return 'Approved';

      case 'declined':
        return 'Declined';

      case 'cancelled':
        return 'Cancelled';

      default:
        return 'Pending';
    }
  }

  Color get _colour {
    switch (status) {
      case 'completed':
        return AppColors.warning;

      case 'approved':
        return AppColors.success;

      case 'declined':
      case 'cancelled':
        return AppColors.danger;

      default:
        return AppColors.subtitle;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'completed':
        return Icons.hourglass_top_outlined;

      case 'approved':
        return Icons.check_circle_outline;

      case 'cancelled':
        return Icons.cancel_outlined;

      case 'declined':
        return Icons.block_outlined;

      default:
        return Icons.schedule_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _colour.withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 15,
              color: _colour,
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                color: _colour,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}