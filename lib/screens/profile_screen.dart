// lib/screens/profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/user_provider.dart';
import '../provider/post_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewLogin;

  const ProfileScreen({super.key, this.viewLogin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _login;
  bool _loadingPosts = false;
  final List<Map<String, dynamic>> _rawPosts = [];

  @override
  void initState() {
    super.initState();
    final up = context.read<UserProvider>();
    _login = widget.viewLogin ?? (up.userLogin ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = context.read<UserProvider>();
      if ((_login == (u.userLogin ?? '')) && mounted) {
        u.reloadFollowingFromLocal();
      }
      _loadUserPosts();
    });
  }

  int _cmpIsoDesc(String? a, String? b) {
    if (a == null || a.isEmpty) return (b == null || b.isEmpty) ? 0 : 1;
    if (b == null || b.isEmpty) return -1;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  Future<void> _loadUserPosts() async {
    if (!mounted) return;
    setState(() => _loadingPosts = true);

    final service = ApiService();
    final List<Map<String, dynamic>> acc = [];
    final ids = <int>{};

    try {
      int page = 1;
      while (true) {
        final res = await service.getUserPosts(_login, page: page);
        if (res.statusCode != 200) break;
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        if (list.isEmpty) break;
        for (final m in list) {
          final id = (m['id'] as num).toInt();
          if (ids.add(id)) acc.add(m);
        }
        page += 1;
        if (page > 100) break;
      }

      int pageAll = 1;
      const maxAllPages = 12;
      while (pageAll <= maxAllPages) {
        final res = await service.getPosts(page: pageAll);
        if (res.statusCode != 200) break;
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        if (list.isEmpty) break;
        for (final m in list) {
          if ((m['user_login'] ?? '') == _login) {
            final id = (m['id'] as num).toInt();
            if (ids.add(id)) acc.add(m);
          }
        }
        pageAll += 1;
      }

      acc.sort((a, b) => _cmpIsoDesc(a['created_at'] as String?, b['created_at'] as String?));

      _rawPosts
        ..clear()
        ..addAll(acc);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _deleteUserPost(int postId) async {
    try {
      final service = ApiService();
      final res = await service.deletePost(postId);
      if (res.statusCode == 204) {
        final idx = _rawPosts.indexWhere((p) => (p['id'] as num?)?.toInt() == postId);
        if (idx >= 0) {
          setState(() {
            _rawPosts.removeAt(idx);
          });
        }
        if (mounted) {
          // ignore: use_build_context_synchronously
          context.read<PostProvider>().deletePost(postId);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final me = up.userLogin ?? '';
    final isMe = _login == me;

    final following = up.following;
    final isFollowing = up.isFollowing(_login);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Meu perfil' : '@$_login'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserPosts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMe ? (up.user?.name ?? me) : _login,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('@${isMe ? me : _login}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                if (!isMe)
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await context.read<UserProvider>().followToggle(_login);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Não foi possível atualizar o seguimento')),
                        );
                      }
                      if (mounted) setState(() {});
                    },
                    child: Text(isFollowing ? 'Deixar de seguir' : 'Seguir'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            if (isMe) ...[
              const Text('Você segue',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              if (following.isEmpty)
                const Text('Você ainda não segue ninguém.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: following.map((l) => Chip(label: Text('@$l'))).toList(),
                ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text(isMe ? 'Seus posts' : 'Posts de @$_login',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            if (_loadingPosts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_rawPosts.isEmpty)
              const Text('Nenhum post encontrado.')
            else
              Column(
                children: _rawPosts.map((p) {
                  final msg = (p['message'] ?? '') as String;
                  final created = (p['created_at'] ?? '') as String;
                  final id = (p['id'] as num).toInt();
                  final author = (p['user_login'] ?? '') as String;
                  final meLogin = me;
                  final canDelete = author.isNotEmpty && author == meLogin;
                  final isReply = p['post_id'] != null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                      title: Text(msg),
                      subtitle: Text(
                        '${isReply ? 'Resposta' : 'Post'} • ${created.split('T').first}',
                      ),
                      trailing: canDelete
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Excluir',
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Excluir postagem'),
                                    content: const Text('Tem certeza que deseja excluir esta postagem?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await _deleteUserPost(id);
                                }
                              },
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
