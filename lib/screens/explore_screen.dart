import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/post.dart';
import '../provider/post_provider.dart';
import 'profile_screen.dart';

enum ExploreTab { users, posts }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  final _api = ApiService();

  ExploreTab _tab = ExploreTab.users;

  // estado local para resultados de usuários
  bool _loadingUsers = false;
  String? _usersError;
  List<String> _userLogins = <String>[];

  // dispara a busca conforme a aba selecionada
  Future<void> _runSearch() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;

    if (_tab == ExploreTab.users) {
      await _searchUsers(term);
    } else {
      await _searchPosts(term);
    }
  }

  Future<void> _searchUsers(String term) async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
      _userLogins.clear();
    });

    try {
      final res = await _api.searchUsers(term);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body) as List;
        _userLogins = list
            .map((e) => (e as Map<String, dynamic>)['login'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (res.statusCode == 401) {
        _usersError = 'Sessão expirada (401). Faça login novamente.';
      } else {
        _usersError = 'Falha ao buscar usuários (${res.statusCode}).';
      }
    } catch (_) {
      _usersError = 'Falha ao buscar usuários.';
    } finally {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<void> _searchPosts(String term) async {
    // usa o PostProvider para popular a lista local de posts da tela
    final pp = context.read<PostProvider>();
    await pp.fetchFeed(reset: true, search: term);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PostProvider>(); // para observar posts quando _tab == posts
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
      ),
      body: Column(
        children: [
          // Seletor + campo + botão
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                // Seletor “Usuários / Posts”
                SegmentedButton<ExploreTab>(
                  segments: const [
                    ButtonSegment<ExploreTab>(
                      value: ExploreTab.users,
                      label: Text('Usuários'),
                      icon: Icon(Icons.person_search),
                    ),
                    ButtonSegment<ExploreTab>(
                      value: ExploreTab.posts,
                      label: Text('Posts'),
                      icon: Icon(Icons.article_outlined),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) {
                    setState(() {
                      _tab = s.first;
                      // ao trocar de aba, limpamos os erros locais da aba de usuários
                      _usersError = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                // Campo de busca
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Buscar…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botão de buscar (visível)
                ElevatedButton.icon(
                  onPressed: _runSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),

          // Conteúdo de resultados
          Expanded(
            child: _tab == ExploreTab.users
                ? _buildUsersResult(theme)
                : _buildPostsResult(pp, theme),
          ),
        ],
      ),
    );
  }

  // ====== UI: resultados de usuários ======
  Widget _buildUsersResult(ThemeData theme) {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return Center(
        child: Text(
          _usersError!,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_userLogins.isEmpty) {
      return const Center(child: Text('Nenhum usuário encontrado.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _userLogins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final login = _userLogins[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('@$login', style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // abre a tela de perfil daquele usuário
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(viewLogin: login)),
            );
          },
        );
      },
    );
  }

  // ====== UI: resultados de posts ======
  Widget _buildPostsResult(PostProvider pp, ThemeData theme) {
    if (pp.isLoading && pp.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pp.error != null && pp.posts.isEmpty) {
      return Center(
        child: Text(
          pp.error!,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (pp.posts.isEmpty) {
      return const Center(child: Text('Nenhum post encontrado.'));
    }

    // Lista simples, sem like/seguir aqui
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: pp.posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final Post post = pp.posts[i];
        final created = post.createdAt?.split('T').first ?? '';
        return Card(
          elevation: 1.2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // cabeçalho
                Row(
                  children: [
                    const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '@${post.userLogin}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (created.isNotEmpty)
                      Text(created, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                // conteúdo
                Text(post.message),
              ],
            ),
          ),
        );
      },
    );
  }
}
