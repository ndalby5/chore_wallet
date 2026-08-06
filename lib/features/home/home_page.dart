import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/balance_summary.dart';
import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../tasks/task_detail_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onViewTasks;
  final VoidCallback onViewFriends;

  const HomePage({
    super.key,
    required this.onViewTasks,
    required this.onViewFriends,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BalanceService _balanceService = BalanceService();

  bool _isLoading = true;
  String? _errorMessage;

  String _firstName = 'there';
  String _fullName = '';
  String? _avatarPath;

  BalanceSummary _balanceSummary =
      const BalanceSummary.empty();

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _assignedByMeTasks = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadHomePage();
  }

  Future<void> _loadHomePage() async {
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
      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select('name, avatar_path')
          .eq('id', currentUser.id)
          .limit(1);

      final currentUserProfiles =
          List<Map<String, dynamic>>.from(
        profileRows,
      );

      String firstName = 'there';
      String fullName = '';
      String? avatarPath;

      if (currentUserProfiles.isNotEmpty) {
        fullName = currentUserProfiles.first['name']
                ?.toString()
                .trim() ??
            '';

        avatarPath = currentUserProfiles
            .first['avatar_path']
            ?.toString();

        if (fullName.isNotEmpty) {
          firstName = fullName.split(' ').first;
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

      final transactionRows =
          await Supabase.instance.client
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

      final transactions =
          List<Map<String, dynamic>>.from(
        transactionRows,
      );

      final relatedProfileIds = <String>{};

      for (final task in tasks) {
        final assignedById =
            task['assigned_by']?.toString();

        final assignedToId =
            task['assigned_to']?.toString();

        if (assignedById != null &&
            assignedById != currentUser.id) {
          relatedProfileIds.add(assignedById);
        }

        if (assignedToId != null &&
            assignedToId != currentUser.id) {
          relatedProfileIds.add(assignedToId);
        }
      }

      for (final transaction in transactions) {
        final userId =
            transaction['user_id']?.toString();

        final friendId =
            transaction['friend_id']?.toString();

        final otherPersonId = userId == currentUser.id
            ? friendId
            : userId;

        if (otherPersonId != null &&
            otherPersonId != currentUser.id) {
          relatedProfileIds.add(otherPersonId);
        }
      }

      List<Map<String, dynamic>> relatedProfiles = [];

      if (relatedProfileIds.isNotEmpty) {
        final relatedProfileRows =
            await Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, avatar_path',
                )
                .inFilter(
                  'id',
                  relatedProfileIds.toList(),
                );

        relatedProfiles =
            List<Map<String, dynamic>>.from(
          relatedProfileRows,
        );
      }

      final profilesById = {
        for (final profile in relatedProfiles)
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
          'other_person_id': otherPersonId,
          'other_person_name':
              otherProfile?['name']?.toString() ??
                  'Friend',
          'other_person_avatar_path':
              otherProfile?['avatar_path']
                  ?.toString(),
        };
      }).toList();

      final enrichedTransactions =
          transactions.map((transaction) {
        final userId =
            transaction['user_id']?.toString();

        final friendId =
            transaction['friend_id']?.toString();

        final otherPersonId =
            userId == currentUser.id
                ? friendId
                : userId;

        final otherProfile =
            profilesById[otherPersonId];

        return <String, dynamic>{
          ...transaction,
          'other_person_id': otherPersonId,
          'other_person_name':
              otherProfile?['name']?.toString() ??
                  'Friend',
          'other_person_avatar_path':
              otherProfile?['avatar_path']
                  ?.toString(),
        };
      }).toList();

      final myTasks = enrichedTasks
          .where(
            (task) =>
                task['assigned_to']?.toString() ==
                    currentUser.id &&
                task['status']?.toString() ==
                    'pending',
          )
          .take(3)
          .toList();

      final assignedByMeTasks =
          enrichedTasks.where((task) {
        final assignedByCurrentUser =
            task['assigned_by']?.toString() ==
                currentUser.id;

        final status =
            task['status']?.toString() ?? '';

        return assignedByCurrentUser &&
            (status == 'pending' ||
                status == 'completed');
      }).take(3).toList();

      final balanceSummary =
          await _balanceService.getBalanceSummary();

      if (!mounted) return;

      setState(() {
        _firstName = firstName;
        _fullName = fullName;
        _avatarPath = avatarPath;

        _balanceSummary = balanceSummary;
        _myTasks = myTasks;
        _assignedByMeTasks = assignedByMeTasks;
        _recentActivity = enrichedTransactions;

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
        _errorMessage =
            'Could not load your dashboard.';
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

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
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

    final date = DateTime.tryParse(
      value.toString(),
    );

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

    final difference =
        dueDay.difference(today).inDays;

    if (difference == 0) {
      return 'Due today';
    }

    if (difference == 1) {
      return 'Due tomorrow';
    }

    if (difference < 0) {
      return 'Overdue';
    }

    final day =
        localDate.day.toString().padLeft(2, '0');

    final month =
        localDate.month.toString().padLeft(2, '0');

    return 'Due $day/$month/${localDate.year}';
  }

  String _formatActivityDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return '';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final activityDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference =
        today.difference(activityDay).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    if (difference > 1 && difference < 7) {
      return '$difference days ago';
    }

    final day =
        localDate.day.toString().padLeft(2, '0');

    final month =
        localDate.month.toString().padLeft(2, '0');

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

    if (_activityBenefitsCurrentUser(
      transaction,
    )) {
      return '+${_formatMoney(pence)}';
    }

    return '-${_formatMoney(pence)}';
  }

  Color _activityColour(
    Map<String, dynamic> transaction,
  ) {
    if (_activityBenefitsCurrentUser(
      transaction,
    )) {
      return AppColors.success;
    }

    return AppColors.danger;
  }

  String _activityTitle(
    Map<String, dynamic> transaction,
  ) {
    final note =
        transaction['note']?.toString().trim();

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

  String _activitySubtitle(
    Map<String, dynamic> transaction,
  ) {
    final personName =
        transaction['other_person_name']
                ?.toString() ??
            'Friend';

    final date = _formatActivityDate(
      transaction['created_at'],
    );

    if (date.isEmpty) {
      return personName;
    }

    return '$personName · $date';
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
        physics:
            const AlwaysScrollableScrollPhysics(),
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
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        120,
      ),
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            ProfileAvatar(
              avatarPath: _avatarPath,
              name: _fullName,
              radius: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()}, $_firstName 👋',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Here’s what’s happening today.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.subtitle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildBalanceCard(),

        const SizedBox(height: 30),

        _buildSectionHeading(
          title: 'My Tasks',
          onPressed: widget.onViewTasks,
        ),
        const SizedBox(height: 12),

        if (_myTasks.isEmpty)
          _buildEmptyCard(
            'You have no tasks to complete.',
          )
        else
          ..._myTasks.map(_buildMyTaskCard),

        const SizedBox(height: 30),

        _buildSectionHeading(
          title: 'Assigned by me',
          onPressed: widget.onViewTasks,
        ),
        const SizedBox(height: 12),

        if (_assignedByMeTasks.isEmpty)
          _buildEmptyCard(
            'You have no active assigned tasks.',
          )
        else
          ..._assignedByMeTasks.map(
            _buildAssignedByMeCard,
          ),

        const SizedBox(height: 30),

        _buildSectionHeading(
          title: 'Recent Activity',
          onPressed: widget.onViewFriends,
        ),
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

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: widget.onViewFriends,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Overall Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                ),
              ],
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

  Widget _buildSectionHeading({
    required String title,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View all',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 19,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyTaskCard(
    Map<String, dynamic> task,
  ) {
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            ProfileAvatar(
              avatarPath: avatarPath,
              name: personName,
              radius: 22,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ??
                        'Task',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assigned by $personName',
                    style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDueDate(
                      task['due_at'],
                    ),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatMoney(
                _readPence(
                  task['reward_pence'],
                ),
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

  Widget _buildAssignedByMeCard(
    Map<String, dynamic> task,
  ) {
    final taskId = task['id']?.toString();

    final personName =
        task['other_person_name']?.toString() ??
            'Friend';

    final avatarPath =
        task['other_person_avatar_path']
            ?.toString();

    final status =
        task['status']?.toString() ?? 'pending';

    final isAwaitingApproval =
        status == 'completed';

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
            ProfileAvatar(
              avatarPath: avatarPath,
              name: personName,
              radius: 22,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ??
                        'Task',
                    style: const TextStyle(
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
                  const SizedBox(height: 5),
                  Text(
                    isAwaitingApproval
                        ? 'Awaiting approval'
                        : 'Waiting to be completed',
                    style: TextStyle(
                      color: isAwaitingApproval
                          ? AppColors.warning
                          : AppColors.subtitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatMoney(
                _readPence(
                  task['reward_pence'],
                ),
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

            final personName =
                transaction['other_person_name']
                        ?.toString() ??
                    'Friend';

            final avatarPath =
                transaction[
                        'other_person_avatar_path']
                    ?.toString();

            return Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  leading: ProfileAvatar(
                    avatarPath: avatarPath,
                    name: personName,
                    radius: 22,
                  ),
                  title: Text(
                    _activityTitle(transaction),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _activitySubtitle(transaction),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                  trailing: Text(
                    _activityAmount(transaction),
                    style: TextStyle(
                      color: _activityColour(
                        transaction,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (index <
                    _recentActivity.length - 1)
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