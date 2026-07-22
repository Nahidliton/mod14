import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/task_model.dart';
import 'kv_storage.dart';

/// DbService provides a simple sqflite-backed DB for mobile and a
/// lightweight in-memory fallback for web so auth (signup/login)
/// remains fast and workable on all platforms.
class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  final KvStorage _storage = KvStorage();
  Database? _db;

  // In-memory fallback for web
  final Map<String, Map<String, String>> _webUsers = {};
  String? _webCurrentUserEmail;
  List<Task> _webTasks = [];

  DbService._internal() {
    if (kIsWeb) {
      _loadWebData();
      if (_webTasks.isEmpty) {
        final now = DateTime.now();
        _webTasks = [
          Task(
            id: '1',
            title: 'Design mobile app wireframe',
            description:
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
            status: 'in_progress',
            dueDate: now,
          ),
          Task(
            id: '2',
            title: 'Develop API endpoints',
            description:
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
            status: 'pending',
            dueDate: now.add(const Duration(days: 1)),
          ),
          Task(
            id: '3',
            title: 'Write unit tests',
            description:
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
            status: 'completed',
            dueDate: now.subtract(const Duration(days: 1)),
          ),
        ];
        _saveWebData();
      }
    }
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'sqflite is not available on web; use the in-memory fallback.',
      );
    }
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            email TEXT PRIMARY KEY,
            password TEXT,
            firstName TEXT,
            lastName TEXT,
            mobile TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            status TEXT,
            dueDate INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE session(
            email TEXT
          )
        ''');

        // Insert some sample tasks so the app has initial data
        final now = DateTime.now();
        await db.insert('tasks', {
          'id': '1',
          'title': 'Design mobile app wireframe',
          'description':
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          'status': 'in_progress',
          'dueDate': now.millisecondsSinceEpoch,
        });
        await db.insert('tasks', {
          'id': '2',
          'title': 'Develop API endpoints',
          'description':
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          'status': 'pending',
          'dueDate': now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        });
        await db.insert('tasks', {
          'id': '3',
          'title': 'Write unit tests',
          'description':
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          'status': 'completed',
          'dueDate': now
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN firstName TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN lastName TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN mobile TEXT');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS session(
              email TEXT
            )
          ''');
        }
      },
    );
  }

  // User methods
  Future<bool> registerUser(
    String email,
    String password, {
    String firstName = '',
    String lastName = '',
    String mobile = '',
  }) async {
    if (kIsWeb) {
      if (_webUsers.containsKey(email)) return false;
      _webUsers[email] = {
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'mobile': mobile,
      };
      _saveWebData();
      return true;
    }

    final db = await database;
    try {
      await db.insert('users', {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'mobile': mobile,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    if (kIsWeb) {
      if (!_webUsers.containsKey(email)) return false;
      final user = _webUsers[email]!;
      final matches = user['password'] == password;
      if (matches) {
        _webCurrentUserEmail = email;
        _saveWebData();
      }
      return matches;
    }

    final db = await database;
    final res = await db.query(
      'users',
      columns: ['password'],
      where: 'email = ?',
      whereArgs: [email],
    );
    if (res.isEmpty) return false;
    if (res.first['password'] == password) {
      await _saveCurrentSession(email);
      return true;
    }
    return false;
  }

  Future<Map<String, String>?> getCurrentUserProfile() async {
    if (kIsWeb) {
      if (_webCurrentUserEmail == null) return null;
      final user = _webUsers[_webCurrentUserEmail!];
      if (user == null) return null;
      return {
        'email': _webCurrentUserEmail!,
        'password': user['password'] ?? '',
        'firstName': user['firstName'] ?? '',
        'lastName': user['lastName'] ?? '',
        'mobile': user['mobile'] ?? '',
      };
    }

    final db = await database;
    final session = await db.query('session', limit: 1);
    if (session.isEmpty) return null;
    final email = session.first['email'] as String?;
    if (email == null) return null;
    final res = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final row = res.first;
    return {
      'email': row['email'] as String,
      'password': row['password'] as String? ?? '',
      'firstName': row['firstName'] as String? ?? '',
      'lastName': row['lastName'] as String? ?? '',
      'mobile': row['mobile'] as String? ?? '',
    };
  }

  Future<bool> updateUserProfile(
    String email,
    String firstName,
    String lastName,
    String mobile,
  ) async {
    if (kIsWeb) {
      if (!_webUsers.containsKey(email)) return false;
      final user = _webUsers[email]!;
      user['firstName'] = firstName;
      user['lastName'] = lastName;
      user['mobile'] = mobile;
      _webUsers[email] = user;
      _saveWebData();
      return true;
    }

    final db = await database;
    final count = await db.update(
      'users',
      {'firstName': firstName, 'lastName': lastName, 'mobile': mobile},
      where: 'email = ?',
      whereArgs: [email],
    );
    return count > 0;
  }

  Future<bool> logoutUser() async {
    if (kIsWeb) {
      _webCurrentUserEmail = null;
      _saveWebData();
      return true;
    }

    final db = await database;
    await db.delete('session');
    return true;
  }

  Future<bool> _saveCurrentSession(String email) async {
    final db = await database;
    await db.delete('session');
    await db.insert('session', {'email': email});
    return true;
  }

  // Task methods
  Future<List<Task>> getTasks() async {
    if (kIsWeb) {
      // return a copy to avoid accidental mutation
      return List<Task>.from(_webTasks);
    }

    final db = await database;
    final maps = await db.query('tasks', orderBy: 'dueDate DESC');

    return maps.map((m) {
      return Task(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        status: m['status'] as String,
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['dueDate'] as int),
      );
    }).toList();
  }

  Future<bool> addTask(
    String id,
    String title,
    String description,
    String status,
    DateTime dueDate,
  ) async {
    if (kIsWeb) {
      try {
        _webTasks.add(
          Task(
            id: id,
            title: title,
            description: description,
            status: status,
            dueDate: dueDate,
          ),
        );
        _saveWebData();
        return true;
      } catch (e) {
        return false;
      }
    }

    final db = await database;
    try {
      await db.insert('tasks', {
        'id': id,
        'title': title,
        'description': description,
        'status': status,
        'dueDate': dueDate.millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTask(
    String id,
    String title,
    String description,
    String status,
    DateTime dueDate,
  ) async {
    if (kIsWeb) {
      final idx = _webTasks.indexWhere((t) => t.id == id);
      if (idx == -1) return false;
      _webTasks[idx] = Task(
        id: id,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
      );
      _saveWebData();
      return true;
    }

    final db = await database;
    final count = await db.update(
      'tasks',
      {
        'title': title,
        'description': description,
        'status': status,
        'dueDate': dueDate.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<bool> deleteTask(String id) async {
    if (kIsWeb) {
      final before = _webTasks.length;
      _webTasks.removeWhere((t) => t.id == id);
      return _webTasks.length < before;
    }

    final db = await database;
    final count = await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  void _loadWebData() {
    final usersJson = _storage.getItem('task_manager_users');
    if (usersJson != null && usersJson.isNotEmpty) {
      final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
      _webUsers.clear();
      decoded.forEach((key, value) {
        _webUsers[key] = Map<String, String>.from(value as Map);
      });
    }

    final currentEmail = _storage.getItem('task_manager_current_user');
    _webCurrentUserEmail = currentEmail?.isNotEmpty == true
        ? currentEmail
        : null;

    final tasksJson = _storage.getItem('task_manager_tasks');
    if (tasksJson != null && tasksJson.isNotEmpty) {
      final decodedTasks = jsonDecode(tasksJson) as List<dynamic>;
      _webTasks = decodedTasks.map((task) {
        final map = Map<String, dynamic>.from(task as Map);
        return Task(
          id: map['id'] as String,
          title: map['title'] as String,
          description: map['description'] as String,
          status: map['status'] as String,
          dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int),
        );
      }).toList();
    }
  }

  void _saveWebData() {
    final usersJson = jsonEncode(_webUsers);
    _storage.setItem('task_manager_users', usersJson);
    _storage.setItem('task_manager_current_user', _webCurrentUserEmail ?? '');
    final taskList = _webTasks
        .map(
          (task) => {
            'id': task.id,
            'title': task.title,
            'description': task.description,
            'status': task.status,
            'dueDate': task.dueDate.millisecondsSinceEpoch,
          },
        )
        .toList();
    _storage.setItem('task_manager_tasks', jsonEncode(taskList));
  }

  Future<void> close() async {
    if (kIsWeb) {
      _webUsers.clear();
      _webTasks.clear();
      _webCurrentUserEmail = null;
      return;
    }

    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
