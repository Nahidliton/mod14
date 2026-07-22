import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

String _hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

String? _getToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) {
    return null;
  }
  return header.substring(7);
}

Response _jsonResponse(Object body, {int status = 200}) {
  return Response(status, body: jsonEncode(body), headers: {
    ..._corsHeaders,
    'content-type': 'application/json; charset=utf-8'
  });
}

Response _options(Request request) {
  return Response.ok('', headers: _corsHeaders);
}

void main() async {
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final dbPath = p.normalize(p.join(scriptDir, '..', 'backend.db'));

  final database = sqlite3.open(dbPath);
  database.execute('''
    CREATE TABLE IF NOT EXISTS users(
      email TEXT PRIMARY KEY,
      password TEXT,
      firstName TEXT,
      lastName TEXT,
      mobile TEXT
    );
  ''');
  database.execute('''
    CREATE TABLE IF NOT EXISTS sessions(
      token TEXT PRIMARY KEY,
      email TEXT,
      createdAt INTEGER
    );
  ''');

  final router = Router();

  router.options('/<ignored|.*>', _options);

  router.post('/register', (Request request) async {
    final payload =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (payload['email'] as String?)?.trim();
    final password = payload['password'] as String?;
    final firstName = (payload['firstName'] as String?)?.trim() ?? '';
    final lastName = (payload['lastName'] as String?)?.trim() ?? '';
    final mobile = (payload['mobile'] as String?)?.trim() ?? '';

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _jsonResponse(
          {'success': false, 'message': 'Email and password are required'},
          status: 400);
    }

    final existing =
        database.select('SELECT email FROM users WHERE email = ?', [email]);
    if (existing.isNotEmpty) {
      return _jsonResponse(
          {'success': false, 'message': 'Email already registered'},
          status: 409);
    }

    database.execute(
      'INSERT INTO users(email, password, firstName, lastName, mobile) VALUES(?, ?, ?, ?, ?)',
      [email, _hashPassword(password), firstName, lastName, mobile],
    );

    final token = _generateToken();
    database.execute(
      'INSERT INTO sessions(token, email, createdAt) VALUES(?, ?, ?)',
      [token, email, DateTime.now().millisecondsSinceEpoch],
    );

    return _jsonResponse({
      'success': true,
      'message': 'Registration successful',
      'data': {
        'token': token,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'mobile': mobile,
      }
    });
  });

  router.post('/login', (Request request) async {
    final payload =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (payload['email'] as String?)?.trim();
    final password = payload['password'] as String?;

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _jsonResponse(
          {'success': false, 'message': 'Email and password are required'},
          status: 400);
    }

    final rows =
        database.select('SELECT password FROM users WHERE email = ?', [email]);
    if (rows.isEmpty) {
      return _jsonResponse({'success': false, 'message': 'Invalid credentials'},
          status: 401);
    }
    final storedHash = rows.first['password'] as String;
    if (storedHash != _hashPassword(password)) {
      return _jsonResponse({'success': false, 'message': 'Invalid credentials'},
          status: 401);
    }

    final token = _generateToken();
    database.execute('DELETE FROM sessions WHERE email = ?', [email]);
    database.execute(
      'INSERT INTO sessions(token, email, createdAt) VALUES(?, ?, ?)',
      [token, email, DateTime.now().millisecondsSinceEpoch],
    );

    return _jsonResponse({
      'success': true,
      'message': 'Login Success',
      'data': {'token': token, 'email': email},
    });
  });

  router.get('/profile', (Request request) {
    final token = _getToken(request);
    if (token == null) {
      return _jsonResponse({'success': false, 'message': 'Missing auth token'},
          status: 401);
    }

    final sessionRows =
        database.select('SELECT email FROM sessions WHERE token = ?', [token]);
    if (sessionRows.isEmpty) {
      return _jsonResponse({'success': false, 'message': 'Invalid auth token'},
          status: 401);
    }
    final email = sessionRows.first['email'] as String;
    final userRows = database.select(
        'SELECT email, firstName, lastName, mobile FROM users WHERE email = ?',
        [email]);
    if (userRows.isEmpty) {
      return _jsonResponse({'success': false, 'message': 'User not found'},
          status: 404);
    }
    final row = userRows.first;
    return _jsonResponse({
      'success': true,
      'data': {
        'email': row['email'] as String,
        'firstName': row['firstName'] as String? ?? '',
        'lastName': row['lastName'] as String? ?? '',
        'mobile': row['mobile'] as String? ?? '',
      }
    });
  });

  router.post('/profile', (Request request) async {
    final token = _getToken(request);
    if (token == null) {
      return _jsonResponse({'success': false, 'message': 'Missing auth token'},
          status: 401);
    }

    final sessionRows =
        database.select('SELECT email FROM sessions WHERE token = ?', [token]);
    if (sessionRows.isEmpty) {
      return _jsonResponse({'success': false, 'message': 'Invalid auth token'},
          status: 401);
    }
    final email = sessionRows.first['email'] as String;
    final payload =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final firstName = (payload['firstName'] as String?)?.trim() ?? '';
    final lastName = (payload['lastName'] as String?)?.trim() ?? '';
    final mobile = (payload['mobile'] as String?)?.trim() ?? '';

    database.execute(
      'UPDATE users SET firstName = ?, lastName = ?, mobile = ? WHERE email = ?',
      [firstName, lastName, mobile, email],
    );

    return _jsonResponse({'success': true, 'message': 'Profile updated'});
  });

  router.post('/logout', (Request request) {
    final token = _getToken(request);
    if (token == null) {
      return _jsonResponse({'success': false, 'message': 'Missing auth token'},
          status: 401);
    }
    database.execute('DELETE FROM sessions WHERE token = ?', [token]);
    return _jsonResponse({'success': true, 'message': 'Logged out'});
  });

  final handler = const Pipeline().addMiddleware((innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return _options(request);
      }
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  }).addHandler(router.call);

  const port = 8080;
  await io.serve(handler, '0.0.0.0', port);
  print('Backend server listening on http://localhost:$port');
}
