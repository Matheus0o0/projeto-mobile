import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  String? _token;
  int? _sessionId;
  String? _userLogin;
  User? _user;

  List<String> _followers = <String>[];
  List<String> _followings = <String>[]; // API não fornece followings

  String? get token => _token;
  int? get sessionId => _sessionId;
  String? get userLogin => _userLogin;
  User? get user => _user;

  List<String> get followers => _followers;
  List<String> get followings => _followings;

  bool get isLoggedIn => _token != null && (_userLogin ?? '').isNotEmpty;

  // ---------- Sessão ----------
  void setSession({required String token, int? sessionId, required String userLogin}) {
    _token = token;
    _sessionId = sessionId;
    _userLogin = userLogin;
    notifyListeners();
  }

  void setUser(User u) {
    _user = u;
    if (u.login.isNotEmpty) _userLogin = u.login;
    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    _sessionId = null;
    _userLogin = null;
    _user = null;
    _followers = <String>[];
    _followings = <String>[];
    await _api.clearSession();
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final t = await _api.getToken();
    final sid = await _api.getSessionId();
    final login = await _api.getStoredUserLogin();

    if (t == null || login == null) {
      await clearSession();
      return;
    }

    _token = t;
    _sessionId = sid;
    _userLogin = login;

    try {
      final r = await _api.getUserByLogin(login, token: t);
      if (r.statusCode == 200) {
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        _user = User.fromJson(map);
      }
    } catch (_) {}
    notifyListeners();
  }

  // ---------- Seguidores ----------
  Future<void> loadFollowers(String viewLogin) async {
    try {
      final r = await _api.listFollowers(viewLogin);
      if (r.statusCode == 200) {
        final List list = jsonDecode(r.body) as List;
        _followers = list
            .map((e) => (e as Map<String, dynamic>)['login'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        _followers = <String>[];
      }
      _followings = <String>[]; // API não expõe followings
    } catch (_) {
      _followers = <String>[];
      _followings = <String>[];
    }
    notifyListeners();
  }

  Future<bool> followUser(String loginToFollow) async {
    try {
      final r = await _api.follow(loginToFollow);
      final ok = r.statusCode == 201;
      if (ok) await loadFollowers(loginToFollow);
      return ok;
    } catch (_) {
      return false;
    }
  }

  // ---------- Compat: telas chamam `follow(login)` ----------
  Future<bool> follow(String login) => followUser(login);

  // ---------- Atualização / exclusão ----------
  Future<bool> updateProfile({
    String? newLogin,
    String? name,
    String? password,
    String? passwordConfirmation,
  }) async {
    try {
      final r = await _api.updateUser(
        login: newLogin,
        name: name,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      if (r.statusCode == 200 || r.statusCode == 201) {
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        final updated = User.fromJson(map);
        setUser(updated);
        if (newLogin != null && newLogin.isNotEmpty) {
          _userLogin = newLogin;
          await _api.persistSession(
            token: _token,
            sessionId: _sessionId,
            userLogin: _userLogin,
          );
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final r = await _api.deleteUser();
      if (r.statusCode == 204) {
        await clearSession();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
