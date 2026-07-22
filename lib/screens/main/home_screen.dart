import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import 'add_task_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _categoryTabController;

  final List<String> _pageTitles = [
    'All Tasks',
    'Categories',
    'Calendar',
    'Profile',
  ];

  final List<String> _categoryLabels = [
    'All',
    'Pending',
    'In Progress',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(
      length: _categoryLabels.length,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TaskProvider>(context, listen: false).fetchTasks();
    });
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C853),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedIndex != 3)
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        ],
      ),
      body: _buildPage(provider),
      floatingActionButton: _selectedIndex != 3
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              ),
              backgroundColor: const Color(0xFF00C853),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF00C853),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Tasks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildPage(TaskProvider provider) {
    if (_selectedIndex == 0) {
      return _buildAllTasks(provider);
    }
    if (_selectedIndex == 1) {
      return _buildCategories(provider);
    }
    if (_selectedIndex == 2) {
      return _buildCalendar(provider);
    }
    return _buildProfile();
  }

  Widget _buildAllTasks(TaskProvider provider) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF00C853),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(provider.totalTasks.toString(), 'All Tasks'),
              _buildStatCard(provider.pendingTasks.toString(), 'Pending'),
              _buildStatCard(
                provider.inProgressTasks.toString(),
                'In Progress',
              ),
              _buildStatCard(provider.completedTasks.toString(), 'Completed'),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.tasks.isEmpty
              ? const Center(child: Text('No tasks found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildTaskCard(provider.tasks[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategories(TaskProvider provider) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF7F7F7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TabBar(
            controller: _categoryTabController,
            isScrollable: true,
            labelColor: const Color(0xFF00C853),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF00C853),
            tabs: _categoryLabels.map((label) => Tab(text: label)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _categoryTabController,
            children: _categoryLabels.map((label) {
              final tasks = _filterTasks(provider.tasks, label);
              return tasks.isEmpty
                  ? Center(
                      child: Text(
                        'No ${label.toLowerCase()} tasks yet',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildTaskCard(tasks[index]),
                    );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Task> _filterTasks(List<Task> tasks, String category) {
    if (category == 'All') return tasks;
    final status = category.toLowerCase().replaceAll(' ', '_');
    return tasks.where((task) => task.status == status).toList();
  }

  Widget _buildCalendar(TaskProvider provider) {
    final tasks = provider.tasks;
    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : tasks.isEmpty
        ? const Center(child: Text('No tasks to show on the calendar yet'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Due ${_formatDate(task.dueDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: _buildStatusChip(task.status),
                ),
              );
            },
          );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildProfile() {
    return const ProfileScreen(embed: true);
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(task.status),
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        // Navigate to edit screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTaskScreen(task: task),
                          ),
                        );
                        // Refresh after coming back
                        Provider.of<TaskProvider>(context, listen: false).fetchTasks();
                      },
                      icon: const Icon(Icons.edit, color: Color(0xFF00C853)),
                    ),
                    IconButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete task'),
                            content: const Text('Are you sure you want to delete this task?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final success = await Provider.of<TaskProvider>(context, listen: false).deleteTask(task.id);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete task')));
                          }
                        }
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    if (status == 'completed') {
      color = const Color(0xFF00C853);
      label = 'Completed';
    } else if (status == 'in_progress') {
      color = const Color(0xFF2979FF);
      label = 'In Progress';
    } else {
      color = const Color(0xFFFB8C00);
      label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
