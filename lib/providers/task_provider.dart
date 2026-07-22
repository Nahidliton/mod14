import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Count methods
  int get totalTasks => _tasks.length;
  int get pendingTasks => _tasks.where((t) => t.status == 'pending').length;
  int get inProgressTasks =>
      _tasks.where((t) => t.status == 'in_progress').length;
  int get completedTasks => _tasks.where((t) => t.status == 'completed').length;

  Future<void> fetchTasks() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _tasks = await _apiService.getTasks();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask(String title, String description) async {
    bool success = await _apiService.addTask(title, description);
    if (success) {
      await fetchTasks(); // Refresh list
    }
    return success;
  }

  Future<bool> updateTask(Task task) async {
    final success = await _apiService.updateTask(task);
    if (success) await fetchTasks();
    return success;
  }

  Future<bool> deleteTask(String id) async {
    final success = await _apiService.deleteTask(id);
    if (success) await fetchTasks();
    return success;
  }
}
