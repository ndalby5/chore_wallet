import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/balance_summary.dart';
import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';
import '../tasks/task_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BalanceService _balanceService = BalanceService();

  bool _isLoading = true;
  String? _errorMessage;

  String _firstName = 'there';
  BalanceSummary _balanceSummary = const BalanceSummary.empty();

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _awaitingApproval = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadHomePage();
  }

  Future<void> _loadHomePage() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', currentUser.id)
          .limit(1);

      final profiles =
          List<Map<String, dynamic>>.from(profileRows);

      String firstName = 'there';

      if (profiles.isNotEmpty) {
        final name =
            profiles.first['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          firstName = name.split(' ').first;
        }
      }

      final taskRows = await Supabase.instance.client
          .from('tasks')
          .select(
            'id, assigned_by, assigned_to, title, '
            'reward_pence, due_at, status, created_at',
          )
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

      final myTasks = tasks
          .where(
            (task) =>
                task['assigned_to']?.toString() ==
                    currentUser.id &&
                task['status']?.toString() == 'pending',
          )
          .take(3)
          .toList();

      final awaitingApproval = tasks
          .where(
            (task) =>
                task['assigned_by']?.toString() ==
                    currentUser.id &&
                task['status']?.toString() == 'completed',
          )
          .take(3)
          .toList();

      final transactionRows = await Supabase.instance.client
          .from('transactions')
          .select(
            'id, user_id, friend_id, amount_pence, '
            'type, note, created_at',
          )
          .or(
            'user_id.eq.${currentUser.id},'
            'friend_id.eq.${currentUser.id}',
          )
          .order(
            'created_at',
            ascending: false,
          )
          .limit(4);

      final balanceSummary =
          await _balanceService.getBalanceSummary();

      if (!mounted) return;

      setState(() {
        _firstName = firstName;
        _balanceSummary = balanceSummary;
        _myTasks = myTasks;
        _awaitingApproval = awaitingApproval;
        _recentActivity =
            List<Map<String, dynamic>>.from(transactionRows);

        _errorMessage = null;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on BalanceServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load your dashboard.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHomePage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadHomePage();
  }

  Future<void> _openTaskDetails(String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          taskId: taskId,
        ),
      ),
    );

    if (!mounted) return;

    await _refreshHomePage();
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  int _readPence(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMoney(int pence) {
    return '£${(pence.abs() / 100).toStringAsFixed(2)}';
  }

  String _formatOverallBalance(int pence) {
    if (pence > 0) {
      return '+${_formatMoney(pence)}';
    }

    if (pence < 0) {
      return '-${_formatMoney(pence)}';
    }

    return '£0.00';
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
      return 'Due today';
    }

    if (difference == 1) {
      return 'Due tomorrow';
    }

    if (difference < 0) {
      return 'Overdue';
    }

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return 'Due $day/$month/${localDate.year}';
  }

  String _formatActivityDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return '';
    }

    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  bool _activityBenefitsCurrentUser(
    Map<String, dynamic> transaction,
  ) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return transaction['user_id']?.toString() ==
        currentUserId;
  }

  String _activityAmount(
    Map<String, dynamic> transaction,
  ) {
    final pence = _readPence(
      transaction['amount_pence'],
    );

    if (_activityBenefitsCurrentUser(transaction)) {
      return '+${_formatMoney(pence)}';
    }

    return '-${_formatMoney(pence)}';
  }

  Color _activityColour(
    Map<String, dynamic> transaction,
  ) {
    if (_activityBenefitsCurrentUser(transaction)) {
      return AppColors.success;
    }

    return AppColors.danger;
  }

  String _activityTitle(
    Map<String, dynamic> transaction,
  ) {
    final note = transaction['note']?.toString().trim();

    if (note != null && note.isNotEmpty) {
      return note;
    }

    switch (transaction['type']?.toString()) {
      case 'payment':
        return 'Payment';
      case 'adjustment':
        return 'Balance adjustment';
      default:
        return 'Task reward';
    }
  }

  IconData _activityIcon(
    Map<String, dynamic> transaction,
  ) {
    switch (transaction['type']?.toString()) {
      case 'payment':
        return Icons.payments_outlined;
      case 'adjustment':
        return Icons.tune_outlined;
      default:
        return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHomePage,
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

    if (_errorMessage != null) {
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
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _refreshHomePage,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        120,
      ),
      children: [
        Text(
          '${_greeting()}, $_firstName 👋',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Here’s what’s happening today.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.subtitle,
          ),
        ),
        const SizedBox(height: 24),
        _buildBalanceCard(),
        const SizedBox(height: 30),
        _buildSectionHeading('My Tasks'),
        const SizedBox(height: 12),
        if (_myTasks.isEmpty)
          _buildEmptyCard(
            'You have no tasks to complete.',
          )
        else
          ..._myTasks.map(_buildMyTaskCard),
        const SizedBox(height: 30),
        _buildSectionHeading('Assigned by me'),
        const SizedBox(height: 12),
        if (_awaitingApproval.isEmpty)
          _buildEmptyCard(
            'Nothing is waiting for approval.',
          )
        else
          ..._awaitingApproval.map(
            _buildAwaitingApprovalCard,
          ),
        const SizedBox(height: 30),
        _buildSectionHeading('Recent Activity'),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          _buildEmptyCard(
            'Your recent rewards and payments will appear here.',
          )
        else
          _buildActivityCard(),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final overall =
        _balanceSummary.overallBalancePence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatOverallBalance(overall),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBalanceBreakdown(
                  'You are owed',
                  _balanceSummary.owedToYouPence,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: Colors.white24,
              ),
              Expanded(
                child: _buildBalanceBreakdown(
                  'You owe',
                  _balanceSummary.youOwePence,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBreakdown(
    String label,
    int pence,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _formatMoney(pence),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMyTaskCard(
    Map<String, dynamic> task,
  ) {
    final taskId = task['id']?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: taskId == null
          ? null
          : () => _openTaskDetails(taskId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFF0ECFF),
              child: Icon(
                Icons.task_alt_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ?? 'Task',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDueDate(task['due_at']),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatMoney(
                _readPence(task['reward_pence']),
              ),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildAwaitingApprovalCard(
    Map<String, dynamic> task,
  ) {
    final taskId = task['id']?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: taskId == null
          ? null
          : () => _openTaskDetails(taskId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFF3DD),
              child: Icon(
                Icons.hourglass_top_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ?? 'Task',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Awaiting approval',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatMoney(
                _readPence(task['reward_pence']),
              ),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: List.generate(
          _recentActivity.length,
          (index) {
            final transaction =
                _recentActivity[index];

            return Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      _activityIcon(transaction),
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    _activityTitle(transaction),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _formatActivityDate(
                      transaction['created_at'],
                    ),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                  trailing: Text(
                    _activityAmount(transaction),
                    style: TextStyle(
                      color: _activityColour(transaction),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (index < _recentActivity.length - 1)
                  const Divider(
                    height: 1,
                    indent: 72,
                  ),
              ],
            );
          },
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