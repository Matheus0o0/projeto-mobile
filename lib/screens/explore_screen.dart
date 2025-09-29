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
        final res = await _api.searchUsers(term);
        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          _users = list.map((e) => User.fromJson(e)).toList();
          _posts = [];
        } else {
          _users = [];
        }
      } else {
        // Posts via feed com ?search=term
        final res = await _api.getFeed(page: 1, search: term);
        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          _posts = list.map((e) => Post.fromJson(e)).toList();
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
