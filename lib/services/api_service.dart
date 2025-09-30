// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.papacapim.just.pro.br';

  void _logResponse(String method, Uri uri, http.Response r) {
    final body = r.body;
    final preview = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    // Não logar tokens do header; mostramos apenas método, path, status e preview do corpo
    // ignore: avoid_print
    print('[API] $method ${uri.path}${uri.hasQuery ? '?${uri.query}' : ''} -> ${r.statusCode}\n$preview');
  }

  // ========= Sessão (token, sessionId, login) =========
  Future<void> persistSession({String? token, int? sessionId, String? userLogin}) async {
    final p = await SharedPreferences.getInstance();
    if (token != null) await p.setString('x_session_token', token);
    if (sessionId != null) await p.setInt('x_session_id', sessionId);
    if (userLogin != null) await p.setString('x_user_login', userLogin);
  }

  Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('x_session_token');
  }

  Future<int?> getSessionId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('x_session_id');
  }

  Future<String?> getStoredUserLogin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('x_user_login');
  }

  Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('x_session_token');
    await p.remove('x_session_id');
    await p.remove('x_user_login');
  }

  Map<String, String> _jsonHeaders({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'x-session-token': token,
      };

  // ========= Auth =========
  Future<http.Response> login(String login, String password) async {
    final uri = Uri.parse('$baseUrl/sessions');
    final r = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({'login': login, 'password': password}),
    );
    _logResponse('POST', uri, r);
    return r;
  }

  Future<http.Response> logout(int sessionId) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/sessions/$sessionId');
    final r = await http.delete(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('DELETE', uri, r);
    return r;
  }

  // ========= Users =========
  Future<http.Response> createUser({
    required String login,
    required String name,
    required String password,
    required String passwordConfirmation,
  }) async {
    final uri = Uri.parse('$baseUrl/users');
    final r = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'user': {
          'login': login,
          'name': name,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }
      }),
    );
    _logResponse('POST', uri, r);
    return r;
  }

  Future<http.Response> updateUser({
    String? login,
    String? name,
    String? password,
    String? passwordConfirmation,
  }) async {
    final t = await getToken();
    // a API usa /users/1 (o “1” é ignorado e pega o user autenticado)
    final uri = Uri.parse('$baseUrl/users/1');
    final r = await http.patch(
      uri,
      headers: _jsonHeaders(token: t),
      body: jsonEncode({
        'user': {
          if (login != null) 'login': login,
          if (name != null) 'name': name,
          if (password != null) 'password': password,
          if (passwordConfirmation != null) 'password_confirmation': passwordConfirmation,
        }
      }),
    );
    _logResponse('PATCH', uri, r);
    return r;
  }

  Future<http.Response> deleteUser() async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/users/1');
    final r = await http.delete(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('DELETE', uri, r);
    return r;
  }

  Future<http.Response> listUsers({int page = 1, String? search}) async {
    final t = await getToken();
    final q = <String, String>{'page': '$page'};
    if (search != null && search.isNotEmpty) q['search'] = search;
    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: q);
    final r = await http.get(uri, headers: _jsonHeaders(token: t));
    _logResponse('GET', uri, r);
    return r;
  }

  Future<http.Response> getUserByLogin(String login, {String? token}) async {
    final t = token ?? await getToken();
    final uri = Uri.parse('$baseUrl/users/$login');
    final r = await http.get(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('GET', uri, r);
    return r;
  }

  // ========= Followers =========
  Future<http.Response> follow(String userLogin) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/users/$userLogin/followers');
    final r = await http.post(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('POST', uri, r);
    return r;
  }

  Future<http.Response> listFollowers(String userLogin) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/users/$userLogin/followers');
    final r = await http.get(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('GET', uri, r);
    return r;
  }

  Future<http.Response> unfollow(String userLogin, int followerId) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/users/$userLogin/followers/$followerId');
    final r = await http.delete(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('DELETE', uri, r);
    return r;
  }

  // ========= Posts =========
  Future<http.Response> getPosts({int page = 1, int? feed, String? search}) async {
    final t = await getToken();
    final qp = <String, String>{'page': '$page'};
    if (feed != null) qp['feed'] = '$feed';
    if (search != null && search.isNotEmpty) qp['search'] = search;
    final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: qp);
    final r = await http.get(uri, headers: _jsonHeaders(token: t));
    _logResponse('GET', uri, r);
    return r;
  }

  Future<http.Response> getUserPosts(String login, {int page = 1}) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/users/$login/posts?page=$page');
    final r = await http.get(uri, headers: _jsonHeaders(token: t));
    _logResponse('GET', uri, r);
    return r;
  }

  Future<http.Response> createPost(String message) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts');
    final r = await http.post(
      uri,
      headers: _jsonHeaders(token: t),
      body: jsonEncode({'post': {'message': message}}),
    );
    _logResponse('POST', uri, r);
    return r;
  }

  Future<http.Response> deletePost(int id) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts/$id');
    final r = await http.delete(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('DELETE', uri, r);
    return r;
  }

  // ========= Replies =========
  Future<http.Response> getReplies(int parentId, {int page = 1}) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts/$parentId/replies?page=$page');
    final r = await http.get(uri, headers: _jsonHeaders(token: t));
    _logResponse('GET', uri, r);
    return r;
  }

  Future<http.Response> replyToPost(int parentId, String message) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts/$parentId/replies');
    final r = await http.post(
      uri,
      headers: _jsonHeaders(token: t),
      body: jsonEncode({'reply': {'message': message}}),
    );
    _logResponse('POST', uri, r);
    return r;
  }

  // ========= Likes =========
  Future<http.Response> likePost(int postId) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts/$postId/likes');
    final r = await http.post(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('POST', uri, r);
    return r;
  }

  Future<http.Response> listLikes(int postId) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts/$postId/likes');
    final r = await http.get(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('GET', uri, r);
    return r;
  }

  Future<http.Response> unlikePost(int postId, int likeId) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/posts/$postId/likes/$likeId');
    final r = await http.delete(
      uri,
      headers: _jsonHeaders(token: t),
    );
    _logResponse('DELETE', uri, r);
    return r;
  }
}
