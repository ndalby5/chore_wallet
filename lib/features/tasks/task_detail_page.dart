import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;

  const TaskDetailPage({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  bool _isLoading = true;
  bool _isUpdating = false;

  String? _errorMessage;
  Map<String, dynamic>? _task;

  String _assignedByName = 'Unknown';
  String _assignedToName = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    try {
      final taskRows = await Supabase.instance.client
          .from('tasks')
          .select(
            'id, assigned_by, assigned_to, title, description, '
            'reward_pence, due_at, status, created_at, '
            'completed_at, approved_at, cancelled_at',
          )
          .eq('id', widget.taskId)
          .limit(1);

      final tasks = List<Map<String, dynamic>>.from(taskRows);

      if (tasks.isEmpty) {
        throw Exception('Task not found.');
      }

      final task = tasks.first;

      final assignedById = task['assigned_by']?.toString();
      final assignedToId = task['assigned_to']?.toString();

      final profileIds = <String>[
        if (assignedById != null) assignedById,
        if (assignedToId != null) assignedToId,
      ];

      final profileRows = profileIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await Supabase.instance.client
                  .from('profiles')
                  .select('id, name')
                  .inFilter('id', profileIds),
            );

      String assignedByName = 'Unknown';
      String assignedToName = 'Unknown';

      for (final profile in profileRows) {
        final profileId = profile['id']?.toString();
        final name = profile['name']?.toString() ?? 'Unknown';

        if (profileId == assignedById) {
          assignedByName = name;
        }

        if (profileId == assignedToId) {
          assignedToName = name;
        }
      }

      if (!mounted) return;

      setState(() {
        _task = task;
        _assignedByName = assignedByName;
        _assignedToName = assignedToName;
        _errorMessage = null;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _completeTask() async {
    await _runTaskAction(
      functionName: 'complete_task',
      successMessage: 'Task marked as complete.',
    );
  }

  Future<void> _approveTask() async {
    await _runTaskAction(
      functionName: 'approve_task',
      successMessage: 'Task approved.',
    );
  }

  Future<void> _runTaskAction({
    required String functionName,
    required String successMessage,
  }) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await Supabase.instance.client.rpc(
        functionName,
        params: {
          'task_id': widget.taskId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
        ),
      );

      await _loadTask();
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
          content: Text('Could not update the task.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteTask() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: const Text(
            'This task will be cancelled and removed from your active tasks.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep task'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete task'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await _deleteTask();
  }

  Future<void> _deleteTask() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'cancel_task',
        params: {
          'task_id': widget.taskId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted.'),
        ),
      );

      Navigator.pop(context, true);
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
          content: Text('Could not delete the task.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  int _readPence(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMoney(dynamic value) {
    final pence = _readPence(value);

    return '£${(pence / 100).toStringAsFixed(2)}';
  }

  String _formatDueDate(dynamic value) {
    if (value == null) {
      return 'No due date';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return 'No due date';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dueDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference = dueDay.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Tomorrow';
    }

    if (difference < 0) {
      return 'Overdue';
    }

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

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

  Color _statusColour(String status) {
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

  bool get _currentUserIsAssignee {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return _task?['assigned_to']?.toString() ==
        currentUserId;
  }

  bool get _currentUserIsAssigner {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return _task?['assigned_by']?.toString() ==
        currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Task Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTask,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null || _task == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline,
            size: 52,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Could not load this task.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _loadTask,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final task = _task!;
    final status =
        task['status']?.toString() ?? 'pending';

    final description =
        task['description']?.toString().trim() ?? '';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        50,
      ),
      children: [
        Text(
          task['title']?.toString() ?? 'Task',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        _buildStatusCard(status),
        const SizedBox(height: 18),
        _buildInformationCard(
          icon: Icons.person_outline,
          label: 'Assigned by',
          value: _assignedByName,
        ),
        const SizedBox(height: 12),
        _buildInformationCard(
          icon: Icons.person_pin_outlined,
          label: 'Assigned to',
          value: _assignedToName,
        ),
        const SizedBox(height: 12),
        _buildInformationCard(
          icon: Icons.payments_outlined,
          label: 'Reward',
          value: _formatMoney(task['reward_pence']),
        ),
        const SizedBox(height: 12),
        _buildInformationCard(
          icon: Icons.calendar_today_outlined,
          label: 'Due',
          value: _formatDueDate(task['due_at']),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 30),
        _buildAction(status),
        if (status == 'pending' &&
            _currentUserIsAssigner) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed:
                  _isUpdating ? null : _confirmDeleteTask,
              icon: const Icon(Icons.delete_outline),
              label: const Text(
                'Delete Task',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusCard(String status) {
    final colour = _statusColour(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colour.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colour,
          ),
          const SizedBox(width: 12),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: colour,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(String status) {
    if (status == 'pending' &&
        _currentUserIsAssignee) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed:
              _isUpdating ? null : _completeTask,
          icon: const Icon(Icons.check),
          label: _isUpdating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Complete Task',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
    }

    if (status == 'completed' &&
        _currentUserIsAssigner) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed:
              _isUpdating ? null : _approveTask,
          icon: const Icon(
            Icons.thumb_up_outlined,
          ),
          label: _isUpdating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Approve Task',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Text(
        _statusLabel(status),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _statusColour(status),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
}