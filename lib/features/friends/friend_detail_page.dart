import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../tasks/add_task_page.dart';
import 'record_payment_page.dart';

class FriendDetailPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendAvatarPath;

  const FriendDetailPage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatarPath,
  });

  @override
  State<FriendDetailPage> createState() =>
      _FriendDetailPageState();
}

class _FriendDetailPageState
    extends State<FriendDetailPage> {
  final BalanceService _balanceService =
      BalanceService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _undoingPaymentId;

  int _balancePence = 0;

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    final currentUser =
        Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'You need to sign in again.';
        _isLoading = false;
      });

      return;
    }

    try {
      final balance =
          await _balanceService.getBalanceWithFriend(
        widget.friendId,
      );

      final transactionRows =
          await Supabase.instance.client
              .from('transactions')
              .select(
                'id, user_id, friend_id, task_id, '
                'amount_pence, type, note, created_at, '
                'created_by, can_edit, edited_at',
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

      final transactions =
          List<Map<String, dynamic>>.from(
        transactionRows,
      );

      final transactionsWithBalances =
          _addRunningBalances(
        transactions,
        currentUser.id,
      );

      if (!mounted) return;

      setState(() {
        _balancePence = balance;
        _transactions =
            transactionsWithBalances;

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
            'Could not load this friend.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _addRunningBalances(
    List<Map<String, dynamic>> transactions,
    String currentUserId,
  ) {
    final oldestFirst =
        transactions.reversed.toList();

    var runningBalancePence = 0;

    final enrichedOldestFirst =
        oldestFirst.map((transaction) {
      final amountPence = _readPence(
        transaction['amount_pence'],
      );

      final receiverId =
          transaction['user_id']?.toString();

      final otherPersonId =
          transaction['friend_id']?.toString();

      if (receiverId == currentUserId) {
        runningBalancePence += amountPence;
      } else if (otherPersonId ==
          currentUserId) {
        runningBalancePence -= amountPence;
      }

      return <String, dynamic>{
        ...transaction,
        'running_balance_pence':
            runningBalancePence,
      };
    }).toList();

    return enrichedOldestFirst.reversed.toList();
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadPage();
  }

  Future<void> _openAddTask() async {
    final taskCreated =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskPage(
          preselectedFriendId: widget.friendId,
          preselectedFriendName:
              widget.friendName,
        ),
      ),
    );

    if (taskCreated == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
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
    final paymentRecorded =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPaymentPage(
          friendId: widget.friendId,
          friendName: widget.friendName,
        ),
      ),
    );

    if (paymentRecorded == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Payment recorded.',
          ),
        ),
      );

      await _refreshPage();
    }
  }

  Future<void> _confirmUndoPayment(
    Map<String, dynamic> transaction,
  ) async {
    if (!_canUndoPayment(transaction)) {
      return;
    }

    final amountPence = _readPence(
      transaction['amount_pence'],
    );

    final shouldUndo =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.undo_rounded,
            color: AppColors.danger,
            size: 34,
          ),
          title: const Text(
            'Undo this payment?',
          ),
          content: Text(
            'This will remove your payment of '
            '${_formatMoney(amountPence)} to '
            '${widget.friendName} and restore the '
            'previous balance between you.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Undo Payment',
              ),
            ),
          ],
        );
      },
    );

    if (shouldUndo != true || !mounted) {
      return;
    }

    await _undoPayment(transaction);
  }

  Future<void> _undoPayment(
    Map<String, dynamic> transaction,
  ) async {
    final paymentId =
        transaction['id']?.toString();

    if (paymentId == null ||
        paymentId.isEmpty ||
        !_canUndoPayment(transaction)) {
      return;
    }

    setState(() {
      _undoingPaymentId = paymentId;
    });

    try {
      await Supabase.instance.client.rpc(
        'delete_payment',
        params: {
          'p_payment_id': paymentId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Payment to ${widget.friendName} undone.',
          ),
        ),
      );

      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not undo the payment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _undoingPaymentId = null;
        });
      }
    }
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

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() ==
        'true';
  }

  String _formatMoney(int pence) {
    return '£${(pence.abs() / 100).toStringAsFixed(2)}';
  }

  String get _balanceAmount {
    return _formatMoney(_balancePence);
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

    final date =
        DateTime.tryParse(value.toString());

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

    final transactionDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference =
        today.difference(transactionDay).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    final day = localDate.day
        .toString()
        .padLeft(2, '0');

    final month = localDate.month
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  bool _benefitsCurrentUser(
    Map<String, dynamic> transaction,
  ) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return transaction['user_id']?.toString() ==
        currentUserId;
  }

  bool _isPayment(
    Map<String, dynamic> transaction,
  ) {
    return transaction['type']?.toString() ==
        'payment';
  }

  bool _canUndoPayment(
    Map<String, dynamic> transaction,
  ) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) {
      return false;
    }

    final createdBy =
        transaction['created_by']?.toString();

    final canEdit =
        _readBool(transaction['can_edit']);

    return _isPayment(transaction) &&
        createdBy == currentUserId &&
        canEdit;
  }

  String _transactionAmount(
    Map<String, dynamic> transaction,
  ) {
    final amountPence = _readPence(
      transaction['amount_pence'],
    );

    return _formatMoney(amountPence);
  }

  String _transactionTitle(
    Map<String, dynamic> transaction,
  ) {
    final note = transaction['note']
        ?.toString()
        .trim();

    if (_isPayment(transaction)) {
      if (_benefitsCurrentUser(transaction)) {
        return 'You were paid';
      }

      return 'You paid ${widget.friendName}';
    }

    if (note != null && note.isNotEmpty) {
      return note;
    }

    final type =
        transaction['type']?.toString();

    switch (type) {
      case 'adjustment':
        return 'Balance adjustment';

      case 'reward':
      default:
        return 'Task reward';
    }
  }

  String _transactionDescription(
    Map<String, dynamic> transaction,
  ) {
    if (_isPayment(transaction)) {
      if (_benefitsCurrentUser(transaction)) {
        return 'You were paid';
      }

      return 'You paid';
    }

    if (_benefitsCurrentUser(transaction)) {
      return 'You earned';
    }

    return 'You owe';
  }

  Color _transactionColour(
    Map<String, dynamic> transaction,
  ) {
    if (_isPayment(transaction)) {
      return AppColors.subtitle;
    }

    if (_benefitsCurrentUser(transaction)) {
      return AppColors.success;
    }

    return AppColors.danger;
  }

  Color _transactionIconBackground(
    Map<String, dynamic> transaction,
  ) {
    final colour =
        _transactionColour(transaction);

    return colour.withValues(alpha: 0.1);
  }

  IconData _transactionIcon(
    Map<String, dynamic> transaction,
  ) {
    final type =
        transaction['type']?.toString();

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

  String _runningBalanceText(
    Map<String, dynamic> transaction,
  ) {
    final balancePence = _readPence(
      transaction['running_balance_pence'],
    );

    if (balancePence > 0) {
      return 'They owe you '
          '${_formatMoney(balancePence)}';
    }

    if (balancePence < 0) {
      return 'You owe '
          '${_formatMoney(balancePence)}';
    }

    return 'Settled up';
  }

  Color _runningBalanceColour(
    Map<String, dynamic> transaction,
  ) {
    final balancePence = _readPence(
      transaction['running_balance_pence'],
    );

    if (balancePence > 0) {
      return AppColors.success;
    }

    if (balancePence < 0) {
      return AppColors.danger;
    }

    return AppColors.subtitle;
  }

  bool _isUndoing(
    Map<String, dynamic> transaction,
  ) {
    final paymentId =
        transaction['id']?.toString();

    return paymentId != null &&
        paymentId == _undoingPaymentId;
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
        backgroundColor:
            AppColors.background,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage,
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              170,
            ),
            children: [
              if (_isLoading)
                const Padding(
                  padding:
                      EdgeInsets.only(top: 100),
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                _buildError()
              else ...[
                _buildFriendHeader(),
                const SizedBox(height: 20),
                _buildBalanceCard(),
                const SizedBox(height: 30),
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w800,
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
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'record_payment',
            onPressed:
                _undoingPaymentId == null
                    ? _openRecordPayment
                    : null,
            backgroundColor: Colors.white,
            foregroundColor:
                AppColors.primary,
            icon: const Icon(
              Icons.payments_outlined,
            ),
            label: const Text(
              'Record Payment',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_task',
            onPressed:
                _undoingPaymentId == null
                    ? _openAddTask
                    : null,
            backgroundColor:
                AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Task',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFriendHeader() {
    return Column(
      children: [
        ProfileAvatar(
          avatarPath:
              widget.friendAvatarPath,
          name: widget.friendName,
          radius: 46,
        ),
        const SizedBox(height: 12),
        Text(
          widget.friendName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius:
            BorderRadius.circular(24),
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
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Column(
        children: List.generate(
          _transactions.length,
          (index) {
            final transaction =
                _transactions[index];

            final colour =
                _transactionColour(
              transaction,
            );

            final canUndo =
                _canUndoPayment(transaction);

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    12,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor:
                            _transactionIconBackground(
                          transaction,
                        ),
                        child: Icon(
                          _transactionIcon(
                            transaction,
                          ),
                          color: colour,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _transactionTitle(
                                transaction,
                              ),
                              style:
                                  const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              _transactionDescription(
                                transaction,
                              ),
                              style: TextStyle(
                                color: colour,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              _formatDate(
                                transaction[
                                    'created_at'],
                              ),
                              style:
                                  const TextStyle(
                                color:
                                    AppColors.subtitle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            _transactionAmount(
                              transaction,
                            ),
                            style: TextStyle(
                              color: colour,
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _runningBalanceText(
                              transaction,
                            ),
                            textAlign:
                                TextAlign.right,
                            style: TextStyle(
                              color:
                                  _runningBalanceColour(
                                transaction,
                              ),
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (canUndo)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      74,
                      0,
                      14,
                      10,
                    ),
                    child: Align(
                      alignment:
                          Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            _isUndoing(transaction)
                                ? null
                                : () =>
                                    _confirmUndoPayment(
                                      transaction,
                                    ),
                        icon: _isUndoing(transaction)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.undo_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isUndoing(transaction)
                              ? 'Undoing...'
                              : 'Undo payment',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppColors.danger,
                        ),
                      ),
                    ),
                  ),

                if (index <
                    _transactions.length - 1)
                  const Divider(
                    height: 1,
                    indent: 74,
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
        borderRadius:
            BorderRadius.circular(20),
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