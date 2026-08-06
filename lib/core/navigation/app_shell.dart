import 'package:flutter/material.dart';

import '../../features/account/account_page.dart';
import '../../features/friends/friends_page.dart';
import '../../features/home/home_page.dart';
import '../../features/tasks/add_task_page.dart';
import '../../features/tasks/tasks_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTaskPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        onViewTasks: () => _selectPage(1),
        onViewFriends: () => _selectPage(2),
      ),
      const TasksPage(),
      const FriendsPage(),
      const AccountPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        backgroundColor: const Color(0xFF6C4DFF),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}