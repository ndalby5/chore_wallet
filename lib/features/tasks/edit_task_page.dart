import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class EditTaskPage extends StatefulWidget {
  final String taskId;

  const EditTaskPage({
    super.key,
    required this.taskId,
  });

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    try {
      final rows = await Supabase.instance.client
          .from('tasks')
          .select(
            'id, title, description, reward_pence, '
            'due_at, status, assigned_by',
          )
          .eq('id', widget.taskId)
          .limit(1);

      final tasks = List<Map<String, dynamic>>.from(rows);

      if (tasks.isEmpty) {
        throw Exception('Task not found.');
      }

      final task = tasks.first;
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id;

      if (task['assigned_by']?.toString() != currentUserId) {
        throw Exception('You cannot edit this task.');
      }

      if (task['status']?.toString() != 'pending') {
        throw Exception('Only pending tasks can be edited.');
      }

      final rewardPence = _readPence(
        task['reward_pence'],
      );

      final dueAt = task['due_at'];
      DateTime? dueDate;

      if (dueAt != null) {
        dueDate = DateTime.tryParse(
          dueAt.toString(),
        )?.toLocal();
      }

      if (!mounted) return;

      setState(() {
        _titleController.text =
            task['title']?.toString() ?? '';

        _descriptionController.text =
            task['description']?.toString() ?? '';

        _rewardController.text =
            (rewardPence / 100).toStringAsFixed(2);

        _selectedDueDate = dueDate;

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

  int _readPence(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int? _rewardInPence() {
    final text = _rewardController.text.trim();

    if (text.isEmpty) {
      return 0;
    }

    final amount = double.tryParse(text);

    if (amount == null) {
      return null;
    }

    return (amount * 100).round();
  }

  Future<void> _chooseDueDate() async {
    final now = DateTime.now();

    final initialDate = _selectedDueDate != null &&
            _selectedDueDate!.isAfter(
              DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 1)),
            )
        ? _selectedDueDate!
        : now;

    final chosenDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(now.year + 5),
    );

    if (chosenDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDueDate = chosenDate;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rewardPence = _rewardInPence();

    if (rewardPence == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid reward amount.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'update_task',
        params: {
          'task_id': widget.taskId,
          'new_title': _titleController.text.trim(),
          'new_description':
              _descriptionController.text.trim(),
          'new_reward_pence': rewardPence,
          'new_due_at':
              _selectedDueDate?.toIso8601String(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task updated.'),
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
          content: Text(
            'Could not update the task.',
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Task',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _loadTask();
                },
                child: const Text('Try again'),
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
            TextFormField(
              controller: _titleController,
              textInputAction:
                  TextInputAction.next,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Task',
                prefixIcon: Icon(
                  Icons.task_alt_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final title =
                    value?.trim() ?? '';

                if (title.isEmpty) {
                  return 'Please enter a task';
                }

                if (title.length > 100) {
                  return 'Task must be 100 characters or fewer';
                }

                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    'Description — optional',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rewardController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              textInputAction:
                  TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Reward',
                hintText: '0.20',
                prefixText: '£ ',
                prefixIcon: Icon(
                  Icons.payments_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text =
                    value?.trim() ?? '';

                if (text.isEmpty) {
                  return null;
                }

                final amount =
                    double.tryParse(text);

                if (amount == null) {
                  return 'Enter a valid amount';
                }

                if (amount < 0 ||
                    amount > 1000) {
                  return 'Enter an amount between £0 and £1,000';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius:
                  BorderRadius.circular(12),
              onTap: _chooseDueDate,
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Due date — optional',
                  prefixIcon: Icon(
                    Icons
                        .calendar_today_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDueDate == null
                      ? 'No due date'
                      : _formatDate(
                          _selectedDueDate!,
                        ),
                ),
              ),
            ),
            if (_selectedDueDate != null)
              Align(
                alignment:
                    Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDueDate = null;
                    });
                  },
                  child: const Text(
                    'Remove due date',
                  ),
                ),
              ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isSaving
                    ? null
                    : _saveChanges,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save_outlined),
                label: _isSaving
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
                        'Save Changes',
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
}