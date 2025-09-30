// lib/provider/user_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  String? _token;
  int? _sessionId;
  String? _userLogin;
  User? _user;

  /// Conjunto local de quem EU sigo (persistido por usuário logado).
  final Set<String> _followingLocal = <String>{};

  // =================== GETTERS ===================
  String? get token => _token;
  int? get sessionId => _sessionId;
  String? get userLogin => _userLogin;
  User? get user => _user;

  bool get isLoggedIn => _token != null && (_userLogin ?? '').isNotEmpty;

  List<String> get following =>
      _followingLocal.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  bool isFollowing(String login) => _followingLocal.contains(login);

  // =================== PERSISTÊNCIA FOLLOWING (LOCAL) ===================
  String _followingKey(String login) => 'following_local_$login';

  Future<void> _loadFollowingLocal() async {
    final me = _userLogin;
    if (me == null || me.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_followingKey(me)) ?? <String>[];
    _followingLocal
      ..clear()
      ..addAll(list);
  }

  /// Expõe recarga da lista de "quem eu sigo" a partir do storage local
  Future<void> reloadFollowingFromLocal() async {
    await _loadFollowingLocal();
    notifyListeners();
  }

  Future<void> _saveFollowingLocal() async {
    final me = _userLogin;
    if (me == null || me.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_followingKey(me), _followingLocal.toList());
  }

  Future<void> _clearFollowingLocal() async {
    final me = _userLogin;
    if (me == null || me.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_followingKey(me));
    _followingLocal.clear();
  }

  // =================== SESSÃO ===================
  void setSession({
    required String token,
    int? sessionId,
    required String userLogin,
  }) async {
    _token = token;
    _sessionId = sessionId;
    _userLogin = userLogin;
    await _loadFollowingLocal();
    notifyListeners();
  }

  void setUser(User u) async {
    _user = u;
    if (u.login.isNotEmpty) {
      final changed = (_userLogin ?? '') != u.login;
      _userLogin = u.login;
      if (changed) await _loadFollowingLocal();
    }
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _clearFollowingLocal();
    _token = null;
    _sessionId = null;
    _userLogin = null;
    _user = null;
    await _api.clearSession();
    notifyListeners();
  }

  /// Restaura sessão salva e baixa o usuário.
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
    } catch (_) {
      // mantém sessão parcial
    }

    await _loadFollowingLocal();
    notifyListeners();
  }

  // =================== FOLLOW / UNFOLLOW ===================
  Future<bool> followToggle(String login) async {
    if ((_userLogin ?? '').isEmpty || (_token ?? '').isEmpty) return false;

    final already = isFollowing(login);

    if (!already) {
      // seguir (otimista)
      _followingLocal.add(login);
      notifyListeners();
      await _saveFollowingLocal();

      try {
        final res = await _api.follow(login);
        if (res.statusCode == 201 || res.statusCode == 422) {
          // 422 = já seguia no servidor
          return true;
        }
        // falhou: reverte
        _followingLocal.remove(login);
        notifyListeners();
        await _saveFollowingLocal();
        return false;
      } catch (_) {
        _followingLocal.remove(login);
        notifyListeners();
        await _saveFollowingLocal();
        return false;
      }
    } else {
      // deixar de seguir (otimista)
      _followingLocal.remove(login);
      notifyListeners();
      await _saveFollowingLocal();

      try {
        final r = await _api.listFollowers(login);
        if (r.statusCode == 200) {
          final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
          Map<String, dynamic>? meRow;
          for (final row in list) {
            if ((row['login'] ?? '') == _userLogin) {
              meRow = row;
              break;
            }
          }
          final followerId = (meRow?['id'] as num?)?.toInt();
          if (followerId != null) {
            final del = await _api.unfollow(login, followerId);
            if (del.statusCode == 204) return true;
          }
        }
        // mesmo sem deletar no servidor, mantemos localmente
        return true;
      } catch (_) {
        return true;
      }
    }
  }

  // =================== ATUALIZAR / EXCLUIR CONTA ===================

  Future<bool> updateProfile({
    String? name,
    String? password,
    String? passwordConfirmation,
    String? newLogin,
  }) async {
    try {
      final r = await _api.updateUser(
        name: name,
        password: password,
        passwordConfirmation: passwordConfirmation,
        login: newLogin,
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
          await _loadFollowingLocal();
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
      return false;
    } catch (_) {
      return false;
    }
  }
}
