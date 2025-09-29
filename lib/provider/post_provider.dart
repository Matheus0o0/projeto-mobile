import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/post.dart';
import '../services/api_service.dart';

class PostProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  final List<Post> _posts = <Post>[];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;

  String? _error;

  // GETTERS
  List<Post> get posts => List.unmodifiable(_posts);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ----- Feed -----
  Future<void> fetchFeed({bool reset = false, String? search}) async {
    if (_isLoading) return;

    if (reset) {
      _posts.clear();
      _page = 1;
      _hasMore = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.getFeed(page: _page, search: search);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        final newPosts = data
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();

        _posts.addAll(newPosts);
        _hasMore = newPosts.isNotEmpty;
        if (_hasMore) _page += 1;
      } else if (res.statusCode == 401) {
        _error = 'Sessão expirada (401). Faça login novamente.';
      } else {
        _error = 'Falha ao carregar o feed (${res.statusCode}).';
      }
    } catch (_) {
      _error = 'Falha ao carregar o feed.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ----- Criar post -----
  Future<bool> createPost(String message) async {
    try {
      final res = await _api.createPost(message);
      if (res.statusCode == 201) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final created = Post.fromJson(map);
        _posts.insert(0, created);
        notifyListeners();
        return true;
      } else {
        _error = 'Não foi possível postar (${res.statusCode}).';
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Não foi possível postar.';
      notifyListeners();
      return false;
    }
  }

  // ----- Excluir post -----
  Future<bool> deletePost(int id) async {
    try {
      final res = await _api.deletePost(id);
      final ok = res.statusCode == 204;
      if (ok) {
        _posts.removeWhere((p) => p.id == id);
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  // ----- Likes -----
  Future<void> refreshLikes(Post post, {required String currentLogin}) async {
    try {
      final r = await _api.listLikes(post.id);
      if (r.statusCode == 200) {
        final List list = jsonDecode(r.body) as List;
        post.likeCount = list.length;

        // tenta achar o like do usuário logado para saber o likeId
        int? myId;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final ulogin = (m['user_login'] ?? '') as String;
          if (ulogin == currentLogin) {
            myId = (m['id'] as num?)?.toInt();
            break;
          }
        }
        post.myLikeId = myId;
        notifyListeners();
      }
    } catch (_) {
      // silencioso
    }
  }

  Future<void> toggleLike(Post post, {required String currentLogin}) async {
    // se já tá curtido, descurte
    if (post.myLikeId != null) {
      final likeId = post.myLikeId!;
      final r = await _api.unlikePost(post.id, likeId);
      if (r.statusCode == 204) {
        post.myLikeId = null;
        post.likeCount = (post.likeCount - 1).clamp(0, 1 << 30);
        notifyListeners();
      } else {
        // fallback: recarrega pra sincronizar
        await refreshLikes(post, currentLogin: currentLogin);
      }
      return;
    }

    // senão, curte
    final r = await _api.likePost(post.id);
    if (r.statusCode == 201) {
      // alguns backends retornam o like recém-criado;
      // por segurança, vamos recarregar a lista e achar o meu likeId
      await refreshLikes(post, currentLogin: currentLogin);
    } else {
      // tenta ao menos atualizar contador
      await refreshLikes(post, currentLogin: currentLogin);
    }
  }

  // ----- Replies -----
  Future<void> loadReplies(Post post) async {
    if (post.repliesLoaded) return;
    try {
      final r = await _api.getReplies(post.id);
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body) as List;
        final list = data
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        post.replies
          ..clear()
          ..addAll(list);
        post.repliesLoaded = true;
        notifyListeners();
      }
    } catch (_) {
      // silencioso
    }
  }

  Future<bool> reply(int parentId, String message) async {
    try {
      final r = await _api.replyToPost(parentId, message);
      if (r.statusCode == 201) {
        // opcional: inserir a reply no post pai já carregado
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        final created = Post.fromJson(map);

        final parent = _posts.firstWhere(
          (p) => p.id == parentId,
          orElse: () => Post(
            id: parentId,
            userLogin: '',
            postId: null,
            message: '',
          ),
        );

        parent.repliesLoaded = true; // sabemos que tem ao menos 1
        parent.replies.insert(0, created);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // util
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
