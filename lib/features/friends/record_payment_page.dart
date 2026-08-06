import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';

class RecordPaymentPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const RecordPaymentPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<RecordPaymentPage> createState() =>
      _RecordPaymentPageState();
}

class _RecordPaymentPageState
    extends State<RecordPaymentPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController =
      TextEditingController();

  final _noteController =
      TextEditingController();

  final BalanceService _balanceService =
      BalanceService();

  bool _isLoadingBalance = true;
  bool _isSaving = false;

  String? _balanceError;
  int _balancePence = 0;

  @override
  void initState() {
    super.initState();

    _amountController.addListener(
      _onAmountChanged,
    );

    _loadBalance();
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();

    _noteController.dispose();

    super.dispose();
  }

  void _onAmountChanged() {
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoadingBalance = true;
      _balanceError = null;
    });

    try {
      final balance =
          await _balanceService
              .getBalanceWithFriend(
        widget.friendId,
      );

      if (!mounted) return;

      setState(() {
        _balancePence = balance;
        _isLoadingBalance = false;
      });
    } on BalanceServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _balanceError = error.message;
        _isLoadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _balanceError =
            'Could not load this balance.';
        _isLoadingBalance = false;
      });
    }
  }

  int? _amountInPence() {
    final text = _amountController.text
        .trim()
        .replaceAll(',', '');

    final amount = double.tryParse(text);

    if (amount == null) {
      return null;
    }

    return (amount * 100).round();
  }

  int get _amountOwedPence {
    if (_balancePence >= 0) {
      return 0;
    }

    return _balancePence.abs();
  }

  bool get _youOweFriend {
    return _balancePence < 0;
  }

  bool get _friendOwesYou {
    return _balancePence > 0;
  }

  bool get _isSettled {
    return _balancePence == 0;
  }

  bool get _isOverpayment {
    final amountPence = _amountInPence();

    if (amountPence == null ||
        !_youOweFriend) {
      return false;
    }

    return amountPence > _amountOwedPence;
  }

  int get _overpaymentPence {
    final amountPence = _amountInPence();

    if (amountPence == null ||
        !_isOverpayment) {
      return 0;
    }

    return amountPence - _amountOwedPence;
  }

  int? get _remainingBalancePence {
    final amountPence = _amountInPence();

    if (amountPence == null ||
        amountPence <= 0 ||
        !_youOweFriend) {
      return null;
    }

    return _amountOwedPence - amountPence;
  }

  String _formatMoney(int pence) {
    return '£${(pence.abs() / 100).toStringAsFixed(2)}';
  }

  String _balanceHeading() {
    if (_youOweFriend) {
      return 'You owe ${widget.friendName}';
    }

    if (_friendOwesYou) {
      return '${widget.friendName} owes you';
    }

    return 'You’re settled up';
  }

  String _balanceDescription() {
    if (_youOweFriend) {
      return 'Record a payment after you have paid '
          '${widget.friendName} outside PocketPot.';
    }

    if (_friendOwesYou) {
      return 'You do not currently owe '
          '${widget.friendName}. They owe you instead.';
    }

    return 'There is currently no outstanding '
        'balance between you.';
  }

  Color _balanceColour() {
    if (_youOweFriend) {
      return AppColors.danger;
    }

    if (_friendOwesYou) {
      return AppColors.success;
    }

    return AppColors.subtitle;
  }

  IconData _balanceIcon() {
    if (_youOweFriend) {
      return Icons.arrow_upward_rounded;
    }

    if (_friendOwesYou) {
      return Icons.arrow_downward_rounded;
    }

    return Icons.check_circle_outline;
  }

  Future<bool> _confirmPayment(
    int amountPence,
  ) async {
    final note =
        _noteController.text.trim();

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            _isOverpayment
                ? Icons.warning_amber_rounded
                : Icons.payments_outlined,
            color: _isOverpayment
                ? AppColors.warning
                : AppColors.primary,
            size: 34,
          ),
          title: Text(
            _isOverpayment
                ? 'Confirm overpayment'
                : 'Record this payment?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'You are recording that you paid '
                '${widget.friendName} '
                '${_formatMoney(amountPence)}.',
              ),
              if (_isOverpayment) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning
                        .withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This is '
                    '${_formatMoney(_overpaymentPence)} '
                    'more than you currently owe. '
                    'After recording it, '
                    '${widget.friendName} will owe you '
                    '${_formatMoney(_overpaymentPence)}.',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight:
                          FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Note: $note',
                  style: const TextStyle(
                    color: AppColors.subtitle,
                  ),
                ),
              ],
            ],
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
                    _isOverpayment
                        ? AppColors.warning
                        : AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isOverpayment
                    ? 'Record Anyway'
                    : 'Record Payment',
              ),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_youOweFriend) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _friendOwesYou
                ? '${widget.friendName} owes you, '
                    'so you cannot record a payment '
                    'to them right now.'
                : 'You are already settled up.',
          ),
        ),
      );

      return;
    }

    final amountPence = _amountInPence();

    if (amountPence == null ||
        amountPence <= 0) {
      return;
    }

    final confirmed =
        await _confirmPayment(amountPence);

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'record_payment',
        params: {
          'friend_id': widget.friendId,
          'payment_amount_pence':
              amountPence,
          'payment_note':
              _noteController.text
                      .trim()
                      .isEmpty
                  ? null
                  : _noteController.text
                      .trim(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Payment to ${widget.friendName} '
            'recorded.',
          ),
        ),
      );

      Navigator.pop(context, true);
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
            'Could not record the payment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Record Payment',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor:
            AppColors.background,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingBalance) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_balanceError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                _balanceError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _loadBalance,
                child:
                    const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        24,
        16,
        24,
        40,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 30),
            Text(
              'Payment to ${widget.friendName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _balanceDescription(),
              style: const TextStyle(
                color: AppColors.subtitle,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _amountController,
              enabled:
                  _youOweFriend &&
                  !_isSaving,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              autofocus: _youOweFriend,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '5.00',
                prefixText: '£ ',
                prefixIcon: const Icon(
                  Icons.payments_outlined,
                ),
                helperText: _youOweFriend
                    ? 'Outstanding: '
                        '${_formatMoney(_amountOwedPence)}'
                    : null,
                border:
                    const OutlineInputBorder(),
              ),
              validator: (value) {
                if (!_youOweFriend) {
                  return null;
                }

                final text =
                    value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Please enter an amount';
                }

                final amount =
                    double.tryParse(
                  text.replaceAll(',', ''),
                );

                if (amount == null ||
                    amount <= 0) {
                  return 'Enter a valid amount';
                }

                if (amount > 100000) {
                  return 'Payment amount is too large';
                }

                return null;
              },
            ),

            if (_youOweFriend &&
                _amountInPence() != null &&
                _amountInPence()! > 0) ...[
              const SizedBox(height: 14),
              _buildPaymentPreview(),
            ],

            const SizedBox(height: 18),
            TextFormField(
              controller: _noteController,
              enabled:
                  _youOweFriend &&
                  !_isSaving,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Note — optional',
                hintText:
                    'For example, paid in cash',
                prefixIcon: Icon(
                  Icons.notes_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed:
                    !_youOweFriend ||
                            _isSaving
                        ? null
                        : _recordPayment,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.primary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Review Payment',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final colour = _balanceColour();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colour.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _balanceIcon(),
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
                  _balanceHeading(),
                  style: const TextStyle(
                    color: AppColors.subtitle,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatMoney(
                    _balancePence,
                  ),
                  style: TextStyle(
                    color: colour,
                    fontSize: 26,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPreview() {
    if (_isOverpayment) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning
              .withValues(alpha: 0.12),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning
                .withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This is an overpayment of '
                '${_formatMoney(_overpaymentPence)}. '
                '${widget.friendName} would owe you '
                'that amount afterwards.',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight:
                      FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final remaining =
        _remainingBalancePence;

    if (remaining == null) {
      return const SizedBox.shrink();
    }

    final fullySettled = remaining == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success
            .withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            fullySettled
                ? Icons
                    .check_circle_outline
                : Icons
                    .account_balance_wallet_outlined,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fullySettled
                  ? 'This payment will settle the balance.'
                  : 'You will still owe '
                      '${widget.friendName} '
                      '${_formatMoney(remaining)}.',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight:
                    FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}