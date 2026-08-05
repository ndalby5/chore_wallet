import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/profile_avatar.dart';
import 'task_status_badge.dart';

class ActiveTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool assignedByCurrentUser;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onApprove;

  const ActiveTaskCard({
    super.key,
    required this.task,
    required this.assignedByCurrentUser,
    required this.onTap,
    this.onComplete,
    this.onApprove,
  });

  int _readPence(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatReward(dynamic rewardPence) {
    final pence = _readPence(rewardPence);

    return '£${(pence / 100).toStringAsFixed(2)}';
  }

  String _formatDueDate(dynamic dueAt) {
    if (dueAt == null) {
      return 'No due date';
    }

    final date = DateTime.tryParse(
      dueAt.toString(),
    );

    if (date == null) {
      return 'No due date';
    }

    final localDate = date.toLocal();

    final day =
        localDate.day.toString().padLeft(2, '0');

    final month =
        localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFEAE8F2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status =
        task['status']?.toString() ?? 'pending';

    final personName =
        task['other_person_name']?.toString() ??
            'Friend';

    final avatarPath =
        task['other_person_avatar_path']
            ?.toString();

    final title =
        task['title']?.toString() ?? 'Task';

    final relationshipText = assignedByCurrentUser
        ? 'Assigned to $personName'
        : 'Assigned by $personName';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  avatarPath: avatarPath,
                  name: personName,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        relationshipText,
                        style: const TextStyle(
                          color:
                              AppColors.subtitle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatReward(
                    task['reward_pence'],
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _formatDueDate(task['due_at']),
              style: const TextStyle(
                color: AppColors.subtitle,
              ),
            ),
            const SizedBox(height: 14),
            if (!assignedByCurrentUser &&
                status == 'pending' &&
                onComplete != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onComplete,
                  child:
                      const Text('Complete Task'),
                ),
              )
            else if (assignedByCurrentUser &&
                status == 'completed' &&
                onApprove != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('Approve'),
                ),
              )
            else
              TaskStatusBadge(
                status: status,
              ),
          ],
        ),
      ),
    );
  }
}