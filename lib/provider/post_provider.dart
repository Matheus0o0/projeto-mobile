// lib/provider/post_provider.dart
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

  int _currentFeedType = 0;
  String? _currentSearch;

  final Set<int> _likeBusy = <int>{};

  List<Post> get posts => List.unmodifiable(_posts);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;
  int get currentFeedType => _currentFeedType;
  String? get currentSearch => _currentSearch;

  Post? getById(int id) {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx == -1) return null;
    return _posts[idx];
  }

  List<Post> repliesOf(int postId) {
    final p = getById(postId);
    return p?.replies ?? const [];
  }

  int replyCountOf(int postId) {
    final p = getById(postId);
    return p?.replies.length ?? 0;
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  Future<void> fetchFeed({
    bool reset = false,
    int feedType = 0,
    String? search,
  }) async {
    if (_isLoading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _posts.clear();
      _setError(null);
      _currentFeedType = feedType;
      _currentSearch = search;
      notifyListeners();
    }
    if (!_hasMore) return;

    _setLoading(true);
    try {
      int iterations = 0;
      final int maxIterations = reset ? 20 : 5;
      final int targetMinRoots = reset ? 10 : 0;

      while (true) {
        final res = await _api.getPosts(
          page: _page,
          feed: (_currentFeedType == 1 ? 1 : null),
          search: _currentSearch,
        );
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body) as List;
          if (data.isEmpty) {
            _hasMore = false;
            _setError(null);
            break;
          }

          final incoming = data
              .map((e) => Post.fromJson(e as Map<String, dynamic>))
              .toList();

          incoming.sort((a, b) {
            final ca = a.createdAt ?? '';
            final cb = b.createdAt ?? '';
            if (ca.isEmpty && cb.isEmpty) return 0;
            if (ca.isEmpty) return 1;
            if (cb.isEmpty) return -1;
            return cb.compareTo(ca);
          });

          final onlyRoots = incoming.where((p) => p.postId == null).toList();

          if (onlyRoots.isNotEmpty) {
            _posts.addAll(onlyRoots);
            _posts.sort((a, b) {
              final ca = a.createdAt ?? '';
              final cb = b.createdAt ?? '';
              if (ca.isEmpty && cb.isEmpty) return 0;
              if (ca.isEmpty) return 1;
              if (cb.isEmpty) return -1;
              return cb.compareTo(ca);
            });
            notifyListeners();
          }

          _page += 1;
          _setError(null);

          iterations += 1;
          final bool reachedTargetRoots = targetMinRoots == 0 || _posts.length >= targetMinRoots;
          if (reachedTargetRoots || iterations >= maxIterations) {
            break;
          }
        } else {
          _setError('Falha ao carregar feed (${res.statusCode}).');
          break;
        }
      }
    } catch (_) {
      _setError('Erro ao carregar feed.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshFeed() {
    return fetchFeed(reset: true, feedType: _currentFeedType, search: _currentSearch);
  }

  Future<void> refreshFeedSoft({int maxPages = 3, int minRoots = 5}) async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      final existingIds = _posts.map((e) => e.id).toSet();
      int pageToLoad = 1;
      int pagesLoaded = 0;
      int newRootsAdded = 0;
      bool keepGoing = true;
      while (keepGoing && pagesLoaded < maxPages) {
        final res = await _api.getPosts(
          page: pageToLoad,
          feed: (_currentFeedType == 1 ? 1 : null),
          search: _currentSearch,
        );
        if (res.statusCode != 200) break;
        final List data = jsonDecode(res.body) as List;
        if (data.isEmpty) break;
        final incoming = data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        final onlyRoots = incoming.where((p) => p.postId == null).toList();
        for (final p in onlyRoots) {
          if (!existingIds.contains(p.id)) {
            _posts.add(p);
            existingIds.add(p.id);
            newRootsAdded += 1;
          }
        }
        pagesLoaded += 1;
        pageToLoad += 1;
        keepGoing = newRootsAdded < minRoots;
      }

      _posts.sort((a, b) {
        final ca = a.createdAt ?? '';
        final cb = b.createdAt ?? '';
        if (ca.isEmpty && cb.isEmpty) return 0;
        if (ca.isEmpty) return 1;
        if (cb.isEmpty) return -1;
        return cb.compareTo(ca);
      });

      if (_page < pageToLoad) {
        _page = pageToLoad;
      }
      notifyListeners();
    } catch (_) {
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createPost(String message) async {
    try {
      final res = await _api.createPost(message);
      if (res.statusCode == 201) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final created = Post.fromJson(map);
        if (created.postId == null) {
          _posts.insert(0, created);
          _posts.sort((a, b) {
            final ca = a.createdAt ?? '';
            final cb = b.createdAt ?? '';
            if (ca.isEmpty && cb.isEmpty) return 0;
            if (ca.isEmpty) return 1;
            if (cb.isEmpty) return -1;
            return cb.compareTo(ca);
          });
          notifyListeners();
          refreshFeedSoft();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePost(int id) async {
    try {
      final res = await _api.deletePost(id);
      if (res.statusCode == 204) {
        final idx = _posts.indexWhere((p) => p.id == id);
        if (idx >= 0) {
          _posts.removeAt(idx);
          notifyListeners();
          return true;
        }
        for (var i = 0; i < _posts.length; i++) {
          final rIdx = _posts[i].replies.indexWhere((r) => r.id == id);
          if (rIdx >= 0) {
            final replies = List<Post>.from(_posts[i].replies)..removeAt(rIdx);
            _posts[i] = _posts[i].copyWith(replies: replies);
            notifyListeners();
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshLikes(Post post, {String currentLogin = ''}) async {
    try {
      final r = await _api.listLikes(post.id);
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body) as List;
        final likeCount = data.length;
        int? myLikeId;
        if (currentLogin.isNotEmpty) {
          for (final e in data.cast<Map<String, dynamic>>()) {
            if ((e['user_login'] ?? '') == currentLogin) {
              myLikeId = (e['id'] as num?)?.toInt();
              break;
            }
          }
        }

        bool updated = false;
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx >= 0) {
          _posts[idx] = _posts[idx].copyWith(likeCount: likeCount, myLikeId: myLikeId);
          updated = true;
        } else {
          for (var i = 0; i < _posts.length; i++) {
            final rIdx = _posts[i].replies.indexWhere((r) => r.id == post.id);
            if (rIdx >= 0) {
              final replies = List<Post>.from(_posts[i].replies);
              replies[rIdx] = replies[rIdx].copyWith(likeCount: likeCount, myLikeId: myLikeId);
              _posts[i] = _posts[i].copyWith(replies: replies);
              updated = true;
              break;
            }
          }
        }
        if (updated) notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleLike(Post post, {String currentLogin = ''}) async {
    if (_likeBusy.contains(post.id)) return;
    _likeBusy.add(post.id);

    try {
      int feedIndex = _posts.indexWhere((p) => p.id == post.id);
      bool isReply = false;
      int parentIdx = -1;
      int replyIdx = -1;

      if (feedIndex < 0) {
        for (var i = 0; i < _posts.length; i++) {
          final idxR = _posts[i].replies.indexWhere((r) => r.id == post.id);
          if (idxR >= 0) { isReply = true; parentIdx = i; replyIdx = idxR; break; }
        }
      }

      Post target = post;
      if (feedIndex >= 0) target = _posts[feedIndex];
      if (isReply) target = _posts[parentIdx].replies[replyIdx];

      final already = (target.myLikeId ?? 0) > 0;

      if (!already) {
        final before = target;
        final optimistic = before.copyWith(likeCount: before.likeCount + 1, myLikeId: -1);
        if (feedIndex >= 0) {
          _posts[feedIndex] = optimistic;
        } else if (isReply) {
          final replies = List<Post>.from(_posts[parentIdx].replies);
          replies[replyIdx] = optimistic;
          _posts[parentIdx] = _posts[parentIdx].copyWith(replies: replies);
        }
        notifyListeners();

        final r = await _api.likePost(post.id);
        if (r.statusCode == 201 || r.statusCode == 422) {
          await refreshLikes(post, currentLogin: currentLogin);
        } else {
          if (feedIndex >= 0) {
            _posts[feedIndex] = before;
          } else if (isReply) {
            final replies = List<Post>.from(_posts[parentIdx].replies);
            replies[replyIdx] = before;
            _posts[parentIdx] = _posts[parentIdx].copyWith(replies: replies);
          }
          notifyListeners();
        }
      } else {
        final likeId = target.myLikeId!;
        final before = target;
        final optimistic = before.copyWith(
          likeCount: (before.likeCount - 1).clamp(0, 1 << 31),
          myLikeId: null,
        );
        if (feedIndex >= 0) {
          _posts[feedIndex] = optimistic;
        } else if (isReply) {
          final replies = List<Post>.from(_posts[parentIdx].replies);
          replies[replyIdx] = optimistic;
          _posts[parentIdx] = _posts[parentIdx].copyWith(replies: replies);
        }
        notifyListeners();

        final r = await _api.unlikePost(post.id, likeId);
        if (r.statusCode == 204 || r.statusCode == 404 || r.statusCode == 422) {
          await refreshLikes(post, currentLogin: currentLogin);
        } else {
          if (feedIndex >= 0) {
            _posts[feedIndex] = before;
          } else if (isReply) {
            final replies = List<Post>.from(_posts[parentIdx].replies);
            replies[replyIdx] = before;
            _posts[parentIdx] = _posts[parentIdx].copyWith(replies: replies);
          }
          notifyListeners();
        }
      }
    } finally {
      _likeBusy.remove(post.id);
    }
  }

  Future<void> loadReplies(Post post) async {
    try {
      final r = await _api.getReplies(post.id);
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body) as List;
        List<Post> replies = data
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();

        if (replies.isEmpty) {
          replies = await _findRepliesFallback(parentId: post.id, maxPages: 5);
        }

        replies.sort((a, b) {
          final ca = a.createdAt ?? '';
          final cb = b.createdAt ?? '';
          if (ca.isEmpty && cb.isEmpty) return 0;
          if (ca.isEmpty) return 1;
          if (cb.isEmpty) return -1;
          return cb.compareTo(ca);
        });

        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx >= 0) {
          _posts[idx] = _posts[idx].copyWith(replies: replies, repliesLoaded: true);
          notifyListeners();
        }
        return;
      }
    } catch (_) {}

    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx >= 0) {
      _posts[idx] = _posts[idx].copyWith(repliesLoaded: true);
      notifyListeners();
    }
  }

  Future<List<Post>> _findRepliesFallback({required int parentId, int maxPages = 5}) async {
    final List<Post> found = [];
    for (int page = 1; page <= maxPages; page++) {
      try {
        final res = await _api.getPosts(
          page: page,
          feed: (_currentFeedType == 1 ? 1 : null),
          search: _currentSearch,
        );
        if (res.statusCode != 200) break;
        final List data = jsonDecode(res.body) as List;
        if (data.isEmpty) break;

        final incoming = data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        final replies = incoming.where((p) => p.postId == parentId).toList();
        found.addAll(replies);

        if (found.isNotEmpty && page >= 2) break;
      } catch (_) {
        break;
      }
    }
    return found;
  }

  Future<bool> reply(int parentId, String message) async {
    final idx = _posts.indexWhere((p) => p.id == parentId);
    if (idx < 0) return false;

    try {
      final r = await _api.replyToPost(parentId, message);
      if (r.statusCode == 201) {
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        final created = Post.fromJson(map);

        final current = _posts[idx];
        final list = List<Post>.from(current.replies)..add(created);
        list.sort((a, b) {
          final ca = a.createdAt ?? '';
          final cb = b.createdAt ?? '';
          if (ca.isEmpty && cb.isEmpty) return 0;
          if (ca.isEmpty) return 1;
          if (cb.isEmpty) return -1;
          return cb.compareTo(ca);
        });
        _posts[idx] = current.copyWith(replies: list, repliesLoaded: true);
        notifyListeners();

        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
