import '../models/task_model.dart';
import 'db_service.dart';

class ApiService {
  final DbService _db = DbService();

  ApiService();

  // Auth services backed by local DB
  Future<Map<String, dynamic>> register(String email, String password) async {
    final success = await _db.registerUser(email, password);
    if (!success) return {'success': false, 'message': 'Email already registered'};
    return {'success': true, 'message': 'Registration successful', 'data': {'email': email}};
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final ok = await _db.loginUser(email, password);
    if (ok) return {'success': true, 'message': 'Login Success', 'data': {'token': 'local-token'}};
    return {'success': false, 'message': 'Invalid credentials'};
  }

  Future<Map<String, dynamic>> verifyPin(String pin) async {
    if (pin == '1234') return {'success': true, 'message': 'PIN Verified'};
    return {'success': false, 'message': 'Invalid PIN'};
  }

  // Task services backed by local DB
  Future<List<Task>> getTasks() async {
    return await _db.getTasks();
  }

  Future<bool> addTask(String title, String description) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return await _db.addTask(id, title, description, 'pending', DateTime.now());
  }

  Future<bool> updateTask(Task task) async {
    return await _db.updateTask(task.id, task.title, task.description, task.status, task.dueDate);
  }

  Future<bool> deleteTask(String id) async {
    return await _db.deleteTask(id);
  }
}
