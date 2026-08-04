import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class AddTaskPage extends StatefulWidget {
  final String? preselectedFriendId;
  final String? preselectedFriendName;

  const AddTaskPage({
    super.key,
    this.preselectedFriendId,
    this.preselectedFriendName,
  });

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();

  bool _isLoadingFriends = true;
  bool _isSaving = false;

  String? _errorMessage;
  String? _selectedFriendId;
  DateTime? _selectedDueDate;

  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();

    _selectedFriendId = widget.preselectedFriendId;
    _loadFriends();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoadingFriends = false;
      });
      return;
    }

    try {
      final friendshipRows = await Supabase.instance.client
          .from('friendships')
          .select('user_one_id, user_two_id')
          .or(
            'user_one_id.eq.${currentUser.id},'
            'user_two_id.eq.${currentUser.id}',
          );

      final friendships =
          List<Map<String, dynamic>>.from(friendshipRows);

      final friendIds = friendships
          .map((friendship) {
            final userOneId = friendship['user_one_id']?.toString();
            final userTwoId = friendship['user_two_id']?.toString();

            return userOneId == currentUser.id
                ? userTwoId
                : userOneId;
          })
          .whereType<String>()
          .toList();

      if (friendIds.isEmpty) {
        if (!mounted) return;

        setState(() {
          _friends = [];
          _isLoadingFriends = false;
        });
        return;
      }

      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select('id, name')
          .inFilter('id', friendIds)
          .order('name');

      if (!mounted) return;

      setState(() {
        _friends = List<Map<String, dynamic>>.from(profileRows);
        _isLoadingFriends = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load your friends.';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _chooseDueDate() async {
    final now = DateTime.now();

    final chosenDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (chosenDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDueDate = chosenDate;
    });
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

  Future<void> _addTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a friend.'),
        ),
      );
      return;
    }

    final rewardPence = _rewardInPence();

    if (rewardPence == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid reward amount.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'create_task',
        params: {
          'friend_id': _selectedFriendId,
          'task_title': _titleController.text.trim(),
          'task_description':
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          'task_reward_pence': rewardPence,
          'task_due_at': _selectedDueDate?.toIso8601String(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task added successfully.'),
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
          content: Text('Could not add the task. Please try again.'),
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
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add Task',
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
    if (_isLoadingFriends) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline,
                size: 52,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Add a friend first',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You need at least one friend before you can assign a task.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subtitle,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedFriendId,
              decoration: const InputDecoration(
                labelText: 'Assign to',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: _friends.map((friend) {
                return DropdownMenuItem<String>(
                  value: friend['id']?.toString(),
                  child: Text(
                    friend['name']?.toString() ?? 'Friend',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFriendId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please choose a friend';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Task',
                hintText: 'For example, empty the dishwasher',
                prefixIcon: Icon(Icons.task_alt_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final title = value?.trim() ?? '';

                if (title.isEmpty) {
                  return 'Please enter a task';
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
                labelText: 'Description — optional',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rewardController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Reward',
                hintText: '0.20',
                prefixText: '£ ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return null;
                }

                final amount = double.tryParse(text);

                if (amount == null) {
                  return 'Enter a valid amount';
                }

                if (amount < 0 || amount > 1000) {
                  return 'Enter an amount between £0 and £1,000';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _chooseDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due date — optional',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDueDate == null
                      ? 'No due date'
                      : _formatDate(_selectedDueDate!),
                ),
              ),
            ),
            if (_selectedDueDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDueDate = null;
                    });
                  },
                  child: const Text('Remove due date'),
                ),
              ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _addTask,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.add),
                label: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add Task',
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
    );
  }
}