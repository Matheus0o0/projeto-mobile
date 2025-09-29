// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.papacapim.just.pro.br';

  // Storage keys
  static const _kToken = 'token';
  static const _kSessionId = 'session_id';
  static const _kUserLogin = 'user_login';

  Map<String, String> _jsonHeaders({String? token}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      h['x-session-token'] = token; // header que a API espera
    }
    return h;
  }

  // ----------------- Persistência -----------------
  Future<void> persistSession({
    String? token,
    int? sessionId,
    String? userLogin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_kToken, token);
    } else {
      await prefs.remove(_kToken);
    }

    if (sessionId != null) {
      await prefs.setInt(_kSessionId, sessionId);
    } else {
      await prefs.remove(_kSessionId);
    }

    if (userLogin != null) {
      await prefs.setString(_kUserLogin, userLogin);
    } else {
      await prefs.remove(_kUserLogin);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kSessionId);
    await prefs.remove(_kUserLogin);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<int?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSessionId);
  }

  Future<String?> getStoredUserLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserLogin);
  }

  // ----------------- AUTENTICAÇÃO -----------------
  Future<http.Response> login(String login, String password) {
    final url = Uri.parse('$baseUrl/sessions');
    final body = jsonEncode({'login': login, 'password': password});
    return http.post(url, headers: _jsonHeaders(), body: body);
  }

  Future<http.Response> logout() async {
    final sessionId = await getSessionId();
    final token = await getToken();
    if (sessionId == null) {
      await clearSession();
      return http.Response('', 204);
    }
    final url = Uri.parse('$baseUrl/sessions/$sessionId');
    final res = await http.delete(url, headers: _jsonHeaders(token: token));
    await clearSession();
    return res;
  }

  // ----------------- USUÁRIOS -----------------
  Future<http.Response> createUser({
    required String login,
    required String name,
    required String password,
    required String passwordConfirmation,
  }) {
    final url = Uri.parse('$baseUrl/users');
    final body = jsonEncode({
      'user': {
        'login': login,
        'name': name,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }
    });
    return http.post(url, headers: _jsonHeaders(), body: body);
  }

  Future<http.Response> getUserByLogin(String userLogin, {String? token}) async {
    final t = token ?? await getToken();
    final url = Uri.parse('$baseUrl/users/$userLogin');
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  Future<http.Response> updateUser({
    String? login,
    String? name,
    String? password,
    String? passwordConfirmation,
  }) async {
    final t = await getToken();
    final me = await getStoredUserLogin();
    final url = Uri.parse('$baseUrl/users/$me');
    final body = jsonEncode({
      'user': {
        if (login != null) 'login': login,
        if (name != null) 'name': name,
        if (password != null) 'password': password,
        if (passwordConfirmation != null)
          'password_confirmation': passwordConfirmation,
      }
    });
    return http.patch(url, headers: _jsonHeaders(token: t), body: body);
  }

  Future<http.Response> deleteUser() async {
    final t = await getToken();
    final me = await getStoredUserLogin();
    final url = Uri.parse('$baseUrl/users/$me');
    return http.delete(url, headers: _jsonHeaders(token: t));
  }

  Future<http.Response> searchUsers(String term) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/users?search=$term');
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  // ----------------- POSTS -----------------
  Future<http.Response> getFeed({int? page, int? feed, String? search}) async {
    final t = await getToken();
    final qp = <String, String>{};
    if (page != null) qp['page'] = '$page';
    if (feed != null) qp['feed'] = '$feed'; // 1 = apenas quem eu sigo
    if (search != null && search.isNotEmpty) qp['search'] = search;
    final url = Uri.parse('$baseUrl/posts')
        .replace(queryParameters: qp.isEmpty ? null : qp);
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  Future<http.Response> getUserPosts(String login, {int? page}) async {
    final t = await getToken();
    final qp = <String, String>{};
    if (page != null) qp['page'] = '$page';
    final url = Uri.parse('$baseUrl/users/$login/posts')
        .replace(queryParameters: qp.isEmpty ? null : qp);
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  Future<http.Response> createPost(String message) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts');
    final body = jsonEncode({'post': {'message': message}});
    return http.post(url, headers: _jsonHeaders(token: t), body: body);
  }

  Future<http.Response> deletePost(int id) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts/$id');
    return http.delete(url, headers: _jsonHeaders(token: t));
  }

  Future<http.Response> replyToPost(int parentPostId, String message) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts/$parentPostId/replies');
    final body = jsonEncode({'reply': {'message': message}});
    return http.post(url, headers: _jsonHeaders(token: t), body: body);
  }

  Future<http.Response> getReplies(int parentPostId) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts/$parentPostId/replies');
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  // ----------------- LIKES -----------------
  Future<http.Response> likePost(int id) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts/$id/likes');
    return http.post(url, headers: _jsonHeaders(token: t), body: jsonEncode({}));
  }

  Future<http.Response> listLikes(int id) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts/$id/likes');
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  Future<http.Response> unlikePost(int postId, int likeId) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/posts/$postId/likes/$likeId');
    return http.delete(url, headers: _jsonHeaders(token: t));
  }

  // ----------------- FOLLOWERS -----------------
  /// Lista seguidores de um usuário (quem segue ESSE usuário).
  Future<http.Response> listFollowers(String login) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/users/$login/followers');
    return http.get(url, headers: _jsonHeaders(token: t));
  }

  /// Segue o usuário.
  Future<http.Response> follow(String loginToFollow) async {
    final t = await getToken();
    final url = Uri.parse('$baseUrl/users/$loginToFollow/followers');
    return http.post(url, headers: _jsonHeaders(token: t), body: jsonEncode({}));
  }

  /// Deixa de seguir (precisa do id do follower).
  Future<http.Response> unfollow(String loginToUnfollow, int followerId) async {
    final t = await getToken();
    final url =
        Uri.parse('$baseUrl/users/$loginToUnfollow/followers/$followerId');
    return http.delete(url, headers: _jsonHeaders(token: t));
  }
}
