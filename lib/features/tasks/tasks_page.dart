import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import 'task_detail_page.dart';
import 'widgets/active_task_card.dart';
import 'widgets/history_task_card.dart';
import 'widgets/task_filter_chips.dart';
import 'widgets/task_search_bar.dart';
import 'widgets/task_tabs.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TextEditingController _searchController =
      TextEditingController();

  bool _isLoading = true;
  bool _showHistory = false;

  TaskStatusFilter _selectedFilter =
      TaskStatusFilter.all;

  String? _errorMessage;

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _assignedByMe = [];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    _loadTasks();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _loadTasks() async {
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
      final taskRows =
          await Supabase.instance.client
              .from('tasks')
              .select()
              .or(
                'assigned_to.eq.${currentUser.id},'
                'assigned_by.eq.${currentUser.id}',
              )
              .order(
                'created_at',
                ascending: false,
              );

      final tasks =
          List<Map<String, dynamic>>.from(
        taskRows,
      );

      final profileIds = tasks
          .expand<String>((task) {
            final assignedById =
                task['assigned_by']?.toString();

            final assignedToId =
                task['assigned_to']?.toString();

            return [
              if (assignedById != null)
                assignedById,
              if (assignedToId != null)
                assignedToId,
            ];
          })
          .toSet()
          .toList();

      List<Map<String, dynamic>> profiles = [];

      if (profileIds.isNotEmpty) {
        final profileRows =
            await Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, avatar_path',
                )
                .inFilter(
                  'id',
                  profileIds,
                );

        profiles =
            List<Map<String, dynamic>>.from(
          profileRows,
        );
      }

      final profilesById = {
        for (final profile in profiles)
          profile['id']?.toString() ?? '':
              profile,
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
          'other_person_name':
              otherProfile?['name']?.toString() ??
                  'Friend',
          'other_person_avatar_path':
              otherProfile?['avatar_path']
                  ?.toString(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _myTasks = enrichedTasks
            .where(
              (task) =>
                  task['assigned_to']
                      ?.toString() ==
                  currentUser.id,
            )
            .toList();

        _assignedByMe = enrichedTasks
            .where(
              (task) =>
                  task['assigned_by']
                      ?.toString() ==
                  currentUser.id,
            )
            .toList();

        _errorMessage = null;
        _isLoading = false;
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
        _errorMessage =
            'Could not load your tasks.';
        _isLoading = false;
      });
    }
  }

  String get _searchText {
    return _searchController.text
        .trim()
        .toLowerCase();
  }

  bool _matchesSearch(
    Map<String, dynamic> task,
  ) {
    if (_searchText.isEmpty) {
      return true;
    }

    final title = task['title']
            ?.toString()
            .toLowerCase() ??
        '';

    return title.contains(_searchText);
  }

  bool _isActiveTask(
    Map<String, dynamic> task,
  ) {
    final status =
        task['status']?.toString() ?? 'pending';

    return status == 'pending' ||
        status == 'completed';
  }

  bool _isHistoryTask(
    Map<String, dynamic> task,
  ) {
    final status =
        task['status']?.toString() ?? '';

    return status == 'approved' ||
        status == 'cancelled' ||
        status == 'declined';
  }

  bool _matchesSelectedFilter(
    Map<String, dynamic> task,
  ) {
    final status =
        task['status']?.toString() ?? 'pending';

    switch (_selectedFilter) {
      case TaskStatusFilter.pending:
        return status == 'pending';

      case TaskStatusFilter.awaitingApproval:
        return status == 'completed';

      case TaskStatusFilter.approved:
        return status == 'approved';

      case TaskStatusFilter.cancelled:
        return status == 'cancelled';

      case TaskStatusFilter.declined:
        return status == 'declined';

      case TaskStatusFilter.all:
        return true;
    }
  }

  List<Map<String, dynamic>>
      get _activeMyTasks {
    return _myTasks
        .where(_isActiveTask)
        .where(_matchesSelectedFilter)
        .where(_matchesSearch)
        .toList();
  }

  List<Map<String, dynamic>>
      get _activeAssignedByMe {
    return _assignedByMe
        .where(_isActiveTask)
        .where(_matchesSelectedFilter)
        .where(_matchesSearch)
        .toList();
  }

  List<Map<String, dynamic>>
      get _historyTasks {
    final allTasks = <Map<String, dynamic>>[
      ..._myTasks,
      ..._assignedByMe,
    ];

    final seenIds = <String>{};

    return allTasks.where((task) {
      final taskId = task['id']?.toString();

      if (taskId == null ||
          seenIds.contains(taskId)) {
        return false;
      }

      if (!_isHistoryTask(task) ||
          !_matchesSelectedFilter(task) ||
          !_matchesSearch(task)) {
        return false;
      }

      seenIds.add(taskId);
      return true;
    }).toList();
  }

  int get _activeCount {
    final allTasks = <Map<String, dynamic>>[
      ..._myTasks,
      ..._assignedByMe,
    ];

    final seenIds = <String>{};

    return allTasks.where((task) {
      final taskId = task['id']?.toString();

      if (taskId == null ||
          seenIds.contains(taskId) ||
          !_isActiveTask(task)) {
        return false;
      }

      seenIds.add(taskId);
      return true;
    }).length;
  }

  int get _historyCount {
    final allTasks = <Map<String, dynamic>>[
      ..._myTasks,
      ..._assignedByMe,
    ];

    final seenIds = <String>{};

    return allTasks.where((task) {
      final taskId = task['id']?.toString();

      if (taskId == null ||
          seenIds.contains(taskId) ||
          !_isHistoryTask(task)) {
        return false;
      }

      seenIds.add(taskId);
      return true;
    }).length;
  }

  Future<void> _completeTask(
    String taskId,
  ) async {
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
          content: Text(
            'Task marked as complete.',
          ),
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
          content: Text(
            'Could not complete the task.',
          ),
        ),
      );
    }
  }

  Future<void> _approveTask(
    String taskId,
  ) async {
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
          content: Text(
            'Could not approve the task.',
          ),
        ),
      );
    }
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

    await _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadTasks();
  }

  void _showActiveTasks() {
    setState(() {
      _showHistory = false;
      _selectedFilter =
          TaskStatusFilter.all;
    });
  }

  void _showHistoryTasks() {
    setState(() {
      _showHistory = true;
      _selectedFilter =
          TaskStatusFilter.all;
    });
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
        physics:
            const AlwaysScrollableScrollPhysics(),
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
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        120,
      ),
      children: [
        TaskTabs(
          showingHistory: _showHistory,
          activeCount: _activeCount,
          historyCount: _historyCount,
          onShowActive: _showActiveTasks,
          onShowHistory: _showHistoryTasks,
        ),
        const SizedBox(height: 16),
        TaskSearchBar(
          controller: _searchController,
          showingHistory: _showHistory,
        ),
        const SizedBox(height: 14),
        TaskFilterChips(
          showingHistory: _showHistory,
          selectedFilter: _selectedFilter,
          onChanged: (filter) {
            setState(() {
              _selectedFilter = filter;
            });
          },
        ),
        const SizedBox(height: 26),
        if (_showHistory)
          _buildHistorySection()
        else
          _buildActiveSection(),
      ],
    );
  }

  Widget _buildActiveSection() {
    final noMatches =
        (_searchText.isNotEmpty ||
            _selectedFilter !=
                TaskStatusFilter.all) &&
        _activeMyTasks.isEmpty &&
        _activeAssignedByMe.isEmpty;

    if (noMatches) {
      return _buildNoMatchingTasks();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'My Tasks (${_activeMyTasks.length})',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_activeMyTasks.isEmpty)
          _buildEmptyCard(
            'You have no active tasks.',
          )
        else
          ..._activeMyTasks.map((task) {
            final taskId =
                task['id']?.toString();

            return ActiveTaskCard(
              task: task,
              assignedByCurrentUser: false,
              onTap: taskId == null
                  ? null
                  : () => _openTaskDetails(
                        taskId,
                      ),
              onComplete: taskId == null
                  ? null
                  : () => _completeTask(
                        taskId,
                      ),
            );
          }),
        const SizedBox(height: 30),
        Text(
          'Assigned by me '
          '(${_activeAssignedByMe.length})',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_activeAssignedByMe.isEmpty)
          _buildEmptyCard(
            'You have no active assigned tasks.',
          )
        else
          ..._activeAssignedByMe.map((task) {
            final taskId =
                task['id']?.toString();

            return ActiveTaskCard(
              task: task,
              assignedByCurrentUser: true,
              onTap: taskId == null
                  ? null
                  : () => _openTaskDetails(
                        taskId,
                      ),
              onApprove: taskId == null
                  ? null
                  : () => _approveTask(
                        taskId,
                      ),
            );
          }),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (_historyTasks.isEmpty &&
        (_searchText.isNotEmpty ||
            _selectedFilter !=
                TaskStatusFilter.all)) {
      return _buildNoMatchingTasks();
    }

    if (_historyTasks.isEmpty) {
      return _buildEmptyHistory();
    }

    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Task History '
          '(${_historyTasks.length})',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ..._historyTasks.map((task) {
          final taskId =
              task['id']?.toString();

          final assignedByCurrentUser =
              task['assigned_by']?.toString() ==
                  currentUserId;

          return HistoryTaskCard(
            task: task,
            assignedByCurrentUser:
                assignedByCurrentUser,
            onTap: taskId == null
                ? null
                : () => _openTaskDetails(
                      taskId,
                    ),
          );
        }),
      ],
    );
  }

  Widget _buildNoMatchingTasks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          const Text(
            'No matching tasks',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try changing the search text or selecting a different filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.subtitle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();

              setState(() {
                _selectedFilter =
                    TaskStatusFilter.all;
              });
            },
            icon: const Icon(
              Icons.refresh,
            ),
            label: const Text(
              'Clear Search and Filter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.history_outlined,
            size: 44,
            color: AppColors.primary,
          ),
          SizedBox(height: 14),
          Text(
            'No task history yet',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Approved, cancelled and declined tasks will appear here.',
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