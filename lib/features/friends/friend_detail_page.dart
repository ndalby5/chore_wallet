import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';
import '../tasks/add_task_page.dart';
import 'record_payment_page.dart';

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
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
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
      final balance = await _balanceService.getBalanceWithFriend(
        widget.friendId,
      );

      final transactionRows = await Supabase.instance.client
          .from('transactions')
          .select(
            'id, user_id, friend_id, task_id, '
            'amount_pence, type, note, created_at',
          )
          .or(
            'and(user_id.eq.${currentUser.id},'
            'friend_id.eq.${widget.friendId}),'
            'and(user_id.eq.${widget.friendId},'
            'friend_id.eq.${currentUser.id})',
          )
          .order(
            'created_at',
            ascending: false,
          );

      if (!mounted) return;

      setState(() {
        _balancePence = balance;
        _transactions =
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
        _errorMessage = 'Could not load this friend.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadPage();
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

      await _refreshPage();
    }
  }

  Future<void> _openRecordPayment() async {
    final paymentRecorded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPaymentPage(
          friendId: widget.friendId,
          friendName: widget.friendName,
        ),
      ),
    );

    if (paymentRecorded == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded.'),
        ),
      );

      await _refreshPage();
    }
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

  String _formatDate(dynamic value) {
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

  bool _isMoneyOwedToCurrentUser(
    Map<String, dynamic> transaction,
  ) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return transaction['user_id']?.toString() == currentUserId;
  }

  String _transactionAmount(
    Map<String, dynamic> transaction,
  ) {
    final amountPence = _readPence(
      transaction['amount_pence'],
    );

    if (_isMoneyOwedToCurrentUser(transaction)) {
      return '+${_formatMoney(amountPence)}';
    }

    return '-${_formatMoney(amountPence)}';
  }

  Color _transactionAmountColor(
    Map<String, dynamic> transaction,
  ) {
    if (_isMoneyOwedToCurrentUser(transaction)) {
      return AppColors.success;
    }

    return AppColors.danger;
  }

  IconData _transactionIcon(
    Map<String, dynamic> transaction,
  ) {
    final type = transaction['type']?.toString();

    switch (type) {
      case 'payment':
        return Icons.payments_outlined;

      case 'adjustment':
        return Icons.tune_outlined;

      case 'reward':
      default:
        return Icons.task_alt;
    }
  }

  String _transactionTitle(
    Map<String, dynamic> transaction,
  ) {
    final note = transaction['note']?.toString().trim();

    if (note != null && note.isNotEmpty) {
      return note;
    }

    final type = transaction['type']?.toString();

    switch (type) {
      case 'payment':
        return 'Payment';

      case 'adjustment':
        return 'Balance adjustment';

      case 'reward':
      default:
        return 'Task reward';
    }
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
          onRefresh: _refreshPage,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              170,
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
                if (_transactions.isEmpty)
                  _buildEmptyActivity()
                else
                  _buildActivityCard(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'record_payment',
            onPressed: _openRecordPayment,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            icon: const Icon(Icons.payments_outlined),
            label: const Text(
              'Record Payment',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_task',
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
        ],
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

  Widget _buildActivityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Column(
        children: List.generate(
          _transactions.length,
          (index) {
            final transaction = _transactions[index];

            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      _transactionIcon(transaction),
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    _transactionTitle(transaction),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(
                      transaction['created_at'],
                    ),
                    style: const TextStyle(
                      color: AppColors.subtitle,
                    ),
                  ),
                  trailing: Text(
                    _transactionAmount(transaction),
                    style: TextStyle(
                      color: _transactionAmountColor(
                        transaction,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (index < _transactions.length - 1)
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
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: AppColors.primary,
          ),
          SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Approved task rewards and payments will appear here.',
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
          onPressed: _refreshPage,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}