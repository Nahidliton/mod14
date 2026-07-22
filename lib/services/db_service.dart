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
  DbService._internal() {
    // initialize in-memory sample data for web
    if (kIsWeb) {
      final now = DateTime.now();
      _webTasks = [
        Task(
          id: '1',
          title: 'Design mobile app wireframe',
          description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          status: 'in_progress',
          dueDate: now,
        ),
        Task(
          id: '2',
          title: 'Develop API endpoints',
          description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          status: 'pending',
          dueDate: now.add(const Duration(days: 1)),
        ),
        Task(
          id: '3',
          title: 'Write unit tests',
          description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          status: 'completed',
          dueDate: now.subtract(const Duration(days: 1)),
        ),
      ];
    }
  }

  Database? _db;

  // In-memory fallback for web
  final Map<String, String> _webUsers = {};
  List<Task> _webTasks = [];

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('sqflite is not available on web; use the in-memory fallback.');
    }
    if (_db != null) return _db!;
    _db =await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            email TEXT PRIMARY KEY,
            password TEXT
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

        // Insert some sample tasks so the app has initial data
        final now = DateTime.now();
        await db.insert('tasks', {
          'id': '1',
          'title': 'Design mobile app wireframe',
          'description': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          'status': 'in_progress',
          'dueDate': now.millisecondsSinceEpoch,
        });
        await db.insert('tasks', {
          'id': '2',
          'title': 'Develop API endpoints',
          'description': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          'status': 'pending',
          'dueDate': now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        });
        await db.insert('tasks', {
          'id': '3',
          'title': 'Write unit tests',
          'description': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
          'status': 'completed',
          'dueDate': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        });
      },
    );
  }

  // User methods
  Future<bool> registerUser(String email, String password) async {
    if (kIsWeb) {
      if (_webUsers.containsKey(email)) return false;
      _webUsers[email] = password;
      _saveWebData();
      return true;
    }

    final db = await database;
    try {
      await db.insert('users', {'email': email, 'password': password});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    if (kIsWeb) {
      if (!_webUsers.containsKey(email)) return false;
      return _webUsers[email] == password;
    }

    final db = await database;
    final res = await db.query('users',
        columns: ['password'], where: 'email = ?', whereArgs: [email]);
    if (res.isEmpty) return false;
    return res.first['password'] == password;
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

  Future<bool> addTask(String id, String title, String description, String status, DateTime dueDate) async {
    if (kIsWeb) {
      try {
        _webTasks.add(Task(id: id, title: title, description: description, status: status, dueDate: dueDate));
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

  Future<bool> updateTask(String id, String title, String description, String status, DateTime dueDate) async {
    if (kIsWeb) {
      final idx = _webTasks.indexWhere((t) => t.id == id);
      if (idx == -1) return false;
      _webTasks[idx] = Task(id: id, title: title, description: description, status: status, dueDate: dueDate);
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

  Future<void> close() async {
    if (kIsWeb) {
      _webUsers.clear();
      _webTasks.clear();
      return;
    }

    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
