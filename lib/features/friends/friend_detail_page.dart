import 'package:flutter/material.dart';

import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';
import '../tasks/add_task_page.dart';

class FriendDetailPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const FriendDetailPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final BalanceService _balanceService = BalanceService();

  bool _isLoading = true;
  String? _errorMessage;
  int _balancePence = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _balanceService.getBalanceWithFriend(
        widget.friendId,
      );

      if (!mounted) return;

      setState(() {
        _balancePence = balance;
        _isLoading = false;
        _errorMessage = null;
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
        _errorMessage = 'Could not load this friend.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddTask() async {
    final taskCreated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskPage(
          preselectedFriendId: widget.friendId,
          preselectedFriendName: widget.friendName,
        ),
      ),
    );

    if (taskCreated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.friendName} has been assigned the task.',
          ),
        ),
      );
    }
  }

  String _formatMoney(int pence) {
    return '£${(pence.abs() / 100).toStringAsFixed(2)}';
  }

  String get _balanceAmount {
    if (_balancePence > 0) {
      return '+${_formatMoney(_balancePence)}';
    }

    if (_balancePence < 0) {
      return '-${_formatMoney(_balancePence)}';
    }

    return '£0.00';
  }

  String get _balanceMessage {
    if (_balancePence > 0) {
      return '${widget.friendName} owes you';
    }

    if (_balancePence < 0) {
      return 'You owe ${widget.friendName}';
    }

    return 'You are all settled up';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.friendName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBalance,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              120,
            ),
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                _buildError()
              else ...[
                _buildBalanceCard(),
                const SizedBox(height: 30),
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _buildEmptyActivity(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Task',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            _balanceMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _balanceAmount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: const Text(
        'Transaction history will appear here next.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.subtitle,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
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
        OutlinedButton(
          onPressed: _loadBalance,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}