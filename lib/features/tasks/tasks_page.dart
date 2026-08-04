import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _assignedByMe = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('tasks')
          .select()
          .or(
            'assigned_to.eq.${currentUser.id},'
            'assigned_by.eq.${currentUser.id}',
          )
          .order('created_at', ascending: false);

      final tasks = List<Map<String, dynamic>>.from(rows);

      if (!mounted) return;

      setState(() {
        _myTasks = tasks
            .where(
              (task) =>
                  task['assigned_to']?.toString() == currentUser.id,
            )
            .toList();

        _assignedByMe = tasks
            .where(
              (task) =>
                  task['assigned_by']?.toString() == currentUser.id,
            )
            .toList();

        _isLoading = false;
        _errorMessage = null;
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
          content: Text('Task marked as complete.'),
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
          content: Text('Could not complete the task.'),
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
          content: Text('Could not approve the task.'),
        ),
      );
    }
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
        : int.tryParse(rewardPence?.toString() ?? '') ?? 0;

    final pounds = pence / 100;

    return '£${pounds.toStringAsFixed(2)}';
  }

  String _formatDueDate(dynamic dueAt) {
    if (dueAt == null) {
      return 'No due date';
    }

    final date = DateTime.tryParse(dueAt.toString());

    if (date == null) {
      return 'No due date';
    }

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
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
        physics: const AlwaysScrollableScrollPhysics(),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        const Text(
          'My Tasks',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_myTasks.isEmpty)
          _buildEmptyCard(
            'No tasks assigned to you.',
          )
        else
          ..._myTasks.map(_buildMyTaskCard),
        const SizedBox(height: 30),
        const Text(
          'Assigned by me',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_assignedByMe.isEmpty)
          _buildEmptyCard(
            'You have not assigned any tasks.',
          )
        else
          ..._assignedByMe.map(_buildAssignedTaskCard),
      ],
    );
  }

  Widget _buildMyTaskCard(Map<String, dynamic> task) {
    final status = task['status']?.toString() ?? 'pending';
    final taskId = task['id']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title']?.toString() ?? 'Task',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatReward(task['reward_pence']),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDueDate(task['due_at']),
            style: const TextStyle(
              color: AppColors.subtitle,
            ),
          ),
          const SizedBox(height: 14),
          if (status == 'pending' && taskId != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _completeTask(taskId),
                child: const Text('Complete Task'),
              ),
            )
          else
            Text(
              _statusLabel(status),
              style: TextStyle(
                color: _statusColor(status),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignedTaskCard(Map<String, dynamic> task) {
    final status = task['status']?.toString() ?? 'pending';
    final taskId = task['id']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title']?.toString() ?? 'Task',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDueDate(task['due_at']),
                  style: const TextStyle(
                    color: AppColors.subtitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatReward(task['reward_pence']),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (status == 'completed' && taskId != null)
                FilledButton(
                  onPressed: () => _approveTask(taskId),
                  child: const Text('Approve'),
                )
              else
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
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