import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? _amountInPence() {
    final text = _amountController.text.trim();

    final amount = double.tryParse(text);

    if (amount == null) {
      return null;
    }

    return (amount * 100).round();
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amountPence = _amountInPence();

    if (amountPence == null || amountPence <= 0) {
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
          'payment_amount_pence': amountPence,
          'payment_note': _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        },
      );

      if (!mounted) return;

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
          content: Text('Could not record the payment.'),
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
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment to ${widget.friendName}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this when you have paid your friend outside the app.',
                  style: TextStyle(
                    color: AppColors.subtitle,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '5.00',
                    prefixText: '£ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Please enter an amount';
                    }

                    final amount = double.tryParse(text);

                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }

                    if (amount > 100000) {
                      return 'Payment amount is too large';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _noteController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Note — optional',
                    hintText: 'For example, paid in cash',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _recordPayment,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Record Payment',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}