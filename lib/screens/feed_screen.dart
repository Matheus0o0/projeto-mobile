import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/post_provider.dart';
import '../provider/user_provider.dart';
import '../models/post.dart';

class FeedScreen extends StatefulWidget {
  final bool compactAppBar;
  const FeedScreen({super.key, this.compactAppBar = false});

  // opcional: usado pelo HomeShell pra rolar pro topo
  static final _scrollCtrl = ScrollController();
  static void scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _composerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // carregamento inicial (se necessário)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PostProvider>();
      if (p.posts.isEmpty) {
        p.fetchFeed(reset: true);
      }
    });

    // scroll infinito
    FeedScreen._scrollCtrl.addListener(() {
      final p = context.read<PostProvider>();
      if (FeedScreen._scrollCtrl.position.pixels >=
          FeedScreen._scrollCtrl.position.maxScrollExtent - 160) {
        if (!p.isLoading && p.hasMore) {
          p.fetchFeed();
        }
      }
    });
  }

  @override
  void dispose() {
    _composerCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendPost() async {
    final text = _composerCtrl.text.trim();
    if (text.isEmpty) return;
    final ok = await context.read<PostProvider>().createPost(text);
    if (ok) _composerCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostProvider>();
    final me = context.watch<UserProvider>().userLogin ?? '';

    return Scaffold(
      appBar: widget.compactAppBar
          ? AppBar(title: const Text('Início'))
          : null,
      body: Column(
        children: [
          // composer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composerCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escreva algo...',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: p.isLoading ? null : _sendPost,
                  child: const Text('Postar'),
                ),
              ],
            ),
          ),
          if (p.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(p.error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => p.fetchFeed(reset: true),
              child: Builder(
                builder: (_) {
                  if (p.posts.isEmpty && p.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (p.posts.isEmpty) {
                    return ListView(
                      controller: FeedScreen._scrollCtrl,
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Nenhuma postagem encontrada.')),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: FeedScreen._scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: p.posts.length + (p.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= p.posts.length) {
                        // indicador de "carregando mais"
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final Post post = p.posts[index];
                      return _PostCard(
                        post: post,
                        meLogin: me,
                        onLike: () => context
                            .read<PostProvider>()
                            .toggleLike(post, currentLogin: me),
                        onDelete: () =>
                            context.read<PostProvider>().deletePost(post.id),
                        onLoadReplies: () =>
                            context.read<PostProvider>().loadReplies(post),
                        onReply: (text) =>
                            context.read<PostProvider>().reply(post.id, text),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final String meLogin;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final Future<void> Function() onLoadReplies;
  final Future<bool> Function(String text) onReply;

  const _PostCard({
    required this.post,
    required this.meLogin,
    required this.onLike,
    required this.onDelete,
    required this.onLoadReplies,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final created = post.createdAt?.split('T').first ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${post.userLogin}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  created,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                if (post.userLogin == meLogin)
                  IconButton(
                    tooltip: 'Excluir',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // conteúdo
            Text(
              post.message,
              style: const TextStyle(fontSize: 15.5),
            ),
            const SizedBox(height: 8),
            // ações
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.myLikeId == null
                        ? Icons.favorite_border
                        : Icons.favorite,
                  ),
                  onPressed: onLike,
                  tooltip: 'Curtir',
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.reply_outlined),
                  onPressed: () async {
                    await onLoadReplies();
                    final ctrl = TextEditingController();
                    // dialog simples
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Responder'),
                        content: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            hintText: 'Sua resposta',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              final ok =
                                  await onReply(ctrl.text.trim());
                              if (ok && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Enviar'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Responder',
                ),
                const Spacer(),
              ],
            ),
            // replies (se já carregadas)
            if (post.repliesLoaded && post.replies.isNotEmpty) ...[
              const Divider(height: 16),
              for (final r in post.replies)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.subdirectory_arrow_right, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${r.userLogin}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(r.message),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
