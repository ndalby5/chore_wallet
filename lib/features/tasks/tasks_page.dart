import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'task_detail_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _isLoading = true;
  bool _showHistory = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _assignedByMe = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final currentUser =
        Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoading = false;
      });

      return;
    }

    try {
      final taskRows = await Supabase.instance.client
          .from('tasks')
          .select()
          .or(
            'assigned_to.eq.${currentUser.id},'
            'assigned_by.eq.${currentUser.id}',
          )
          .order(
            'created_at',
            ascending: false,
          );

      final tasks =
          List<Map<String, dynamic>>.from(taskRows);

      final profileIds = tasks
          .expand<String>((task) {
            final assignedBy =
                task['assigned_by']?.toString();

            final assignedTo =
                task['assigned_to']?.toString();

            return [
              if (assignedBy != null) assignedBy,
              if (assignedTo != null) assignedTo,
            ];
          })
          .toSet()
          .toList();

      List<Map<String, dynamic>> profiles = [];

      if (profileIds.isNotEmpty) {
        final profileRows =
            await Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, avatar_path',
                )
                .inFilter(
                  'id',
                  profileIds,
                );

        profiles =
            List<Map<String, dynamic>>.from(
          profileRows,
        );
      }

      final profilesById = {
        for (final profile in profiles)
          profile['id']?.toString() ?? '': profile,
      };

      final enrichedTasks = tasks.map((task) {
        final assignedById =
            task['assigned_by']?.toString();

        final assignedToId =
            task['assigned_to']?.toString();

        final otherPersonId =
            assignedToId == currentUser.id
                ? assignedById
                : assignedToId;

        final otherProfile =
            profilesById[otherPersonId];

        return <String, dynamic>{
          ...task,
          'other_person_name':
              otherProfile?['name']?.toString() ??
                  'Friend',
          'other_person_avatar_path':
              otherProfile?['avatar_path']
                  ?.toString(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _myTasks = enrichedTasks
            .where(
              (task) =>
                  task['assigned_to']?.toString() ==
                  currentUser.id,
            )
            .toList();

        _assignedByMe = enrichedTasks
            .where(
              (task) =>
                  task['assigned_by']?.toString() ==
                  currentUser.id,
            )
            .toList();

        _errorMessage = null;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load your tasks.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _activeMyTasks {
    return _myTasks.where((task) {
      final status =
          task['status']?.toString() ?? 'pending';

      return status == 'pending' ||
          status == 'completed';
    }).toList();
  }

  List<Map<String, dynamic>>
      get _activeAssignedByMe {
    return _assignedByMe.where((task) {
      final status =
          task['status']?.toString() ?? 'pending';

      return status == 'pending' ||
          status == 'completed';
    }).toList();
  }

  List<Map<String, dynamic>> get _historyTasks {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    final historyStatuses = {
      'approved',
      'cancelled',
      'declined',
    };

    final combinedTasks = <Map<String, dynamic>>[
      ..._myTasks,
      ..._assignedByMe,
    ];

    final seenTaskIds = <String>{};

    return combinedTasks.where((task) {
      final taskId = task['id']?.toString();
      final status = task['status']?.toString();

      if (taskId == null ||
          status == null ||
          !historyStatuses.contains(status)) {
        return false;
      }

      if (seenTaskIds.contains(taskId)) {
        return false;
      }

      seenTaskIds.add(taskId);

      return task['assigned_to']?.toString() ==
              currentUserId ||
          task['assigned_by']?.toString() ==
              currentUserId;
    }).toList();
  }

  Future<void> _completeTask(String taskId) async {
    try {
      await Supabase.instance.client.rpc(
        'complete_task',
        params: {
          'task_id': taskId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Task marked as complete.',
          ),
        ),
      );

      await _loadTasks();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not complete the task.',
          ),
        ),
      );
    }
  }

  Future<void> _approveTask(String taskId) async {
    try {
      await Supabase.instance.client.rpc(
        'approve_task',
        params: {
          'task_id': taskId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task approved.'),
        ),
      );

      await _loadTasks();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not approve the task.',
          ),
        ),
      );
    }
  }

  Future<void> _openTaskDetails(
    String taskId,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          taskId: taskId,
        ),
      ),
    );

    if (!mounted) return;

    await _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadTasks();
  }

  String _formatReward(dynamic rewardPence) {
    final pence = rewardPence is int
        ? rewardPence
        : int.tryParse(
              rewardPence?.toString() ?? '',
            ) ??
            0;

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

  String _statusLabel(String status) {
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

  Color _statusColor(String status) {
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

  IconData _statusIcon(String status) {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Tasks',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTasks,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline,
            size: 52,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _refreshTasks,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        120,
      ),
      children: [
        _buildTaskTabs(),
        const SizedBox(height: 26),
        if (_showHistory)
          _buildHistorySection()
        else
          _buildActiveSection(),
      ],
    );
  }

  Widget _buildTaskTabs() {
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
            child: _buildTaskTab(
              label:
                  'Active (${_activeMyTasks.length + _activeAssignedByMe.length})',
              isSelected: !_showHistory,
              onTap: () {
                setState(() {
                  _showHistory = false;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTaskTab(
              label:
                  'History (${_historyTasks.length})',
              isSelected: _showHistory,
              onTap: () {
                setState(() {
                  _showHistory = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
          borderRadius:
              BorderRadius.circular(14),
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

  Widget _buildActiveSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'My Tasks (${_activeMyTasks.length})',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_activeMyTasks.isEmpty)
          _buildEmptyCard(
            'You have no active tasks.',
          )
        else
          ..._activeMyTasks.map(
            _buildMyTaskCard,
          ),
        const SizedBox(height: 30),
        Text(
          'Assigned by me '
          '(${_activeAssignedByMe.length})',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_activeAssignedByMe.isEmpty)
          _buildEmptyCard(
            'You have no active assigned tasks.',
          )
        else
          ..._activeAssignedByMe.map(
            _buildAssignedTaskCard,
          ),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (_historyTasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(
              Icons.history_outlined,
              size: 44,
              color: AppColors.primary,
            ),
            SizedBox(height: 14),
            Text(
              'No task history yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Approved, cancelled and declined tasks will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtitle,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Task History (${_historyTasks.length})',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ..._historyTasks.map(
          _buildHistoryTaskCard,
        ),
      ],
    );
  }

  Widget _buildMyTaskCard(
    Map<String, dynamic> task,
  ) {
    final status =
        task['status']?.toString() ?? 'pending';

    final taskId = task['id']?.toString();

    final personName =
        task['other_person_name']?.toString() ??
            'Friend';

    final avatarPath =
        task['other_person_avatar_path']
            ?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: taskId == null
          ? null
          : () => _openTaskDetails(taskId),
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
                        task['title']?.toString() ??
                            'Task',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned by $personName',
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
            if (status == 'pending' &&
                taskId != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      _completeTask(taskId),
                  child:
                      const Text('Complete Task'),
                ),
              )
            else
              _buildStatusBadge(status),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedTaskCard(
    Map<String, dynamic> task,
  ) {
    final status =
        task['status']?.toString() ?? 'pending';

    final taskId = task['id']?.toString();

    final personName =
        task['other_person_name']?.toString() ??
            'Friend';

    final avatarPath =
        task['other_person_avatar_path']
            ?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: taskId == null
          ? null
          : () => _openTaskDetails(taskId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
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
                    task['title']?.toString() ??
                        'Task',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assigned to $personName',
                    style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDueDate(
                      task['due_at'],
                    ),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(status),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _formatReward(
                    task['reward_pence'],
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (status == 'completed' &&
                    taskId != null)
                  FilledButton(
                    onPressed: () =>
                        _approveTask(taskId),
                    child: const Text('Approve'),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTaskCard(
    Map<String, dynamic> task,
  ) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    final status =
        task['status']?.toString() ?? 'approved';

    final taskId = task['id']?.toString();

    final personName =
        task['other_person_name']?.toString() ??
            'Friend';

    final avatarPath =
        task['other_person_avatar_path']
            ?.toString();

    final assignedByCurrentUser =
        task['assigned_by']?.toString() ==
            currentUserId;

    final relationshipText = assignedByCurrentUser
        ? 'Assigned to $personName'
        : 'Assigned by $personName';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: taskId == null
          ? null
          : () => _openTaskDetails(taskId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
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
                    task['title']?.toString() ??
                        'Task',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relationshipText,
                    style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDueDate(
                      task['due_at'],
                    ),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(status),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _formatReward(
                    task['reward_pence'],
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.chevron_right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final colour = _statusColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: colour.withValues(
            alpha: 0.12,
          ),
          borderRadius:
              BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusIcon(status),
              size: 15,
              color: colour,
            ),
            const SizedBox(width: 5),
            Text(
              _statusLabel(status),
              style: TextStyle(
                color: colour,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.subtitle,
        ),
      ),
    );
  }
}