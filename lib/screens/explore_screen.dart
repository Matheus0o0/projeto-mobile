import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../provider/user_provider.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';

enum SearchMode { users, posts }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  SearchMode _mode = SearchMode.users;

  bool _loading = false;
  List<User> _users = [];
  List<Post> _posts = [];

  Future<void> _doSearch() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) {
      setState(() {
        _users = [];
        _posts = [];
      });
      return;
    }

    setState(() => _loading = true);

    try {
      if (_mode == SearchMode.users) {
        final res = await _api.listUsers(search: term);
        final List<User> found = [];
        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          found.addAll(list.map((e) => User.fromJson(e)));
        }

        // Fallback: tentar achar por login exato (GET /users/{login}) quando aplicável
        final loginProbe = term.startsWith('@') ? term.substring(1) : term;
        if (loginProbe.isNotEmpty && !loginProbe.contains(' ')) {
          try {
            final r2 = await _api.getUserByLogin(loginProbe);
            if (r2.statusCode == 200) {
              final map = jsonDecode(r2.body) as Map<String, dynamic>;
              final u = User.fromJson(map);
              final exists = found.any((x) => x.login == u.login);
              if (!exists) found.add(u);
            }
          } catch (_) {}
        }

        // ordenar alfabeticamente por nome, depois login
        found.sort((a, b) {
          final an = (a.name).toLowerCase();
          final bn = (b.name).toLowerCase();
          final byName = an.compareTo(bn);
          if (byName != 0) return byName;
          return a.login.toLowerCase().compareTo(b.login.toLowerCase());
        });

        _users = found;
        _posts = [];
      } else {
        // Posts via feed com ?search=term
        final res = await _api.getPosts(page: 1, search: term);
        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          final parsed = list.map((e) => Post.fromJson(e)).toList();
          // mostrar apenas posts raiz e ordenar por created_at desc
          final roots = parsed.where((p) => p.postId == null).toList();
          roots.sort((a, b) {
            final ca = a.createdAt ?? '';
            final cb = b.createdAt ?? '';
            if (ca.isEmpty && cb.isEmpty) return 0;
            if (ca.isEmpty) return 1;
            if (cb.isEmpty) return -1;
            return cb.compareTo(ca);
          });
          _posts = roots;
          _users = [];
        } else {
          _posts = [];
        }
      }
    } catch (_) {
      _users = [];
      _posts = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _doSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuários ou posts...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _doSearch,
                  tooltip: 'Buscar',
                ),
              ],
            ),
          ),
          // Seletor
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SegmentedButton<SearchMode>(
              segments: const [
                ButtonSegment<SearchMode>(
                  value: SearchMode.users,
                  icon: Icon(Icons.person_search),
                  label: Text('Usuários'),
                ),
                ButtonSegment<SearchMode>(
                  value: SearchMode.posts,
                  icon: Icon(Icons.article_outlined),
                  label: Text('Posts'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (set) {
                final m = set.first;
                setState(() {
                  _mode = m;
                  _users = [];
                  _posts = [];
                });
                _doSearch();
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_mode == SearchMode.users ? _buildUsers(up) : _buildPosts()),
          ),
        ],
      ),
    );
  }

  Widget _buildUsers(UserProvider up) {
    if (_users.isEmpty) {
      return const Center(child: Text('Nenhum usuário encontrado.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final u = _users[i];
        final following = up.isFollowing(u.login);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(u.name.isNotEmpty ? u.name : u.login),
            subtitle: Text('@${u.login}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(viewLogin: u.login)),
              );
            },
            trailing: ElevatedButton(
              onPressed: () async {
                final ok = await context.read<UserProvider>().followToggle(u.login);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Não foi possível atualizar o seguimento')),
                  );
                } else {
                  // atualiza rótulo do botão
                  if (mounted) setState(() {});
                }
              },
              child: Text(following ? 'Deixar de seguir' : 'Seguir'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPosts() {
    if (_posts.isEmpty) {
      return const Center(child: Text('Nenhum post encontrado.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final p = _posts[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person, size: 18)),
                    const SizedBox(width: 8),
                    Text('@${p.userLogin}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(p.message),
              ],
            ),
          ),
        );
      },
    );
  }
}
