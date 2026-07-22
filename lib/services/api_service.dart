import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task_model.dart';
import 'db_service.dart';
import 'kv_storage.dart';

class ApiService {
  final DbService _db = DbService();
  final KvStorage _storage = KvStorage();

  static const _backendBaseUrl = 'http://localhost:8080';
  static const _tokenKey = 'task_manager_auth_token';

  ApiService();

  String? _getStoredToken() {
    return _storage.getItem(_tokenKey);
  }

  void _saveToken(String token) {
    _storage.setItem(_tokenKey, token);
  }

  void _clearToken() {
    _storage.removeItem(_tokenKey);
  }

  Future<Map<String, dynamic>> _remoteRequest(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$_backendBaseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = _getStoredToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = method == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Remote server returned ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String firstName,
    String lastName,
    String mobile,
  ) async {
    try {
      final response = await _remoteRequest(
        '/register',
        method: 'POST',
        body: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'mobile': mobile,
        },
      );
      if (response['success'] == true) {
        final token = response['data'] != null
            ? response['data']['token'] as String?
            : null;
        if (token != null) {
          _saveToken(token);
        }
      }
      return response;
    } catch (_) {
      final success = await _db.registerUser(
        email,
        password,
        firstName: firstName,
        lastName: lastName,
        mobile: mobile,
      );
      if (!success) {
        return {'success': false, 'message': 'Email already registered'};
      }
      return {
        'success': true,
        'message': 'Registration successful',
        'data': {
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'mobile': mobile,
        },
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _remoteRequest(
        '/login',
        method: 'POST',
        body: {'email': email, 'password': password},
      );
      if (response['success'] == true) {
        final token = response['data'] != null
            ? response['data']['token'] as String?
            : null;
        if (token != null) {
          _saveToken(token);
        }
      }
      return response;
    } catch (_) {
      final ok = await _db.loginUser(email, password);
      if (ok) {
        return {
          'success': true,
          'message': 'Login Success',
          'data': {'email': email},
        };
      }
      return {'success': false, 'message': 'Invalid credentials'};
    }
  }

  Future<Map<String, String>?> getProfile() async {
    final token = _getStoredToken();
    if (token != null) {
      try {
        final response = await _remoteRequest('/profile', auth: true);
        if (response['success'] == true && response['data'] != null) {
          return Map<String, String>.from(response['data'] as Map);
        }
      } catch (_) {
        // Fall back to local profile if remote is unavailable.
      }
    }

    return await _db.getCurrentUserProfile();
  }

  Future<bool> updateProfile(
    String email,
    String firstName,
    String lastName,
    String mobile,
  ) async {
    final token = _getStoredToken();
    if (token != null) {
      try {
        final response = await _remoteRequest(
          '/profile',
          method: 'POST',
          auth: true,
          body: {
            'firstName': firstName,
            'lastName': lastName,
            'mobile': mobile,
          },
        );
        if (response['success'] == true) {
          return true;
        }
      } catch (_) {
        // Fall through to local update.
      }
    }
    return await _db.updateUserProfile(email, firstName, lastName, mobile);
  }

  Future<bool> logout() async {
    final token = _getStoredToken();
    bool remoteSuccess = false;
    if (token != null) {
      try {
        final response = await _remoteRequest(
          '/logout',
          method: 'POST',
          auth: true,
        );
        remoteSuccess = response['success'] == true;
      } catch (_) {
        remoteSuccess = false;
      }
      _clearToken();
    }

    final localSuccess = await _db.logoutUser();
    return remoteSuccess || localSuccess;
  }

  Future<Map<String, dynamic>> verifyPin(String pin) async {
    if (pin == '1234') {
      return {'success': true, 'message': 'PIN Verified'};
    }
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
    return await _db.updateTask(
      task.id,
      task.title,
      task.description,
      task.status,
      task.dueDate,
    );
  }

  Future<bool> deleteTask(String id) async {
    return await _db.deleteTask(id);
  }
}
