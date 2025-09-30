// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/post_provider.dart';
import '../provider/user_provider.dart';
import '../models/post.dart';

class FeedScreen extends StatefulWidget {
  final bool compactAppBar;
  final ScrollController? controller;

  const FeedScreen({
    Key? key,
    this.compactAppBar = false,
    this.controller,
  }) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _composerCtrl = TextEditingController();
  late final ScrollController _scrollCtrl =
      widget.controller ?? ScrollController();
  late final VoidCallback _onScroll = () {
    if (!mounted) return;
    final prov = context.read<PostProvider>();
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !prov.isLoading &&
        prov.hasMore) {
      prov.fetchFeed();
    }
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<PostProvider>().fetchFeed(reset: true);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _composerCtrl.dispose();
    if (widget.controller == null) {
      _scrollCtrl.removeListener(_onScroll);
      _scrollCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollCtrl.hasClients) return;
    try {
      await _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  Future<void> _sendPost() async {
    final txt = _composerCtrl.text.trim();
    if (txt.isEmpty) return;

    final ok = await context.read<PostProvider>().createPost(txt);
    if (ok) {
      _composerCtrl.clear();
      await _scrollToTop();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao publicar. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostProvider>();
    final me = context.watch<UserProvider>().userLogin ?? '';

    final items = p.posts;

    return Scaffold(
      appBar: widget.compactAppBar
          ? AppBar(
              title: const Text('Início'),
              centerTitle: false,
              actions: [
                _FeedTypeToggle(),
              ],
            )
          : AppBar(
              title: const Text('Feed'),
              actions: [
                _FeedTypeToggle(),
              ],
            ),
      body: Column(
        children: [
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
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
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
          if (p.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                p.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<PostProvider>().refreshFeed(),
              child: Builder(
                builder: (_) {
                  if (items.isEmpty && p.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return ListView(
                      controller: _scrollCtrl,
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Nenhuma postagem encontrada.')),
                      ],
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length + (p.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = items[index];

                      return _PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        currentLogin: me,
                        onLike: () => context
                            .read<PostProvider>()
                            .toggleLike(post, currentLogin: me),
                        onDelete: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Excluir postagem'),
                              content: const Text(
                                  'Tem certeza que deseja excluir esta postagem?'),
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
                            await context
                                .read<PostProvider>()
                                .deletePost(post.id);
                          }
                        },
                        onLoadReplies: () =>
                            context.read<PostProvider>().loadReplies(post),
                        onReply: (txt) =>
                            context.read<PostProvider>().reply(post.id, txt),
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

class _PostCard extends StatefulWidget {
  final Post post;
  final String currentLogin;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final Future<void> Function() onLoadReplies;
  final Future<bool> Function(String text) onReply;

  const _PostCard({
    Key? key,
    required this.post,
    required this.currentLogin,
    required this.onLike,
    required this.onDelete,
    required this.onLoadReplies,
    required this.onReply,
  }) : super(key: key);

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showReplies = false;
  bool _loadingReplies = false;
  final TextEditingController _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRepliesPanel() async {
    setState(() => _showReplies = !_showReplies);
    if (_showReplies && !_loadingReplies) {
      setState(() => _loadingReplies = true);
      await widget.onLoadReplies();
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  Future<void> _sendReply() async {
    final txt = _replyCtrl.text.trim();
    if (txt.isEmpty) return;

    final ok = await widget.onReply(txt);
    if (ok && mounted) {
      _replyCtrl.clear();
      if (!_showReplies) setState(() => _showReplies = true);
      setState(() => _loadingReplies = true);
      await widget.onLoadReplies();
      if (mounted) setState(() => _loadingReplies = false);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível responder agora.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = context.select<PostProvider, Post?>(
          (prov) => prov.getById(widget.post.id),
        ) ??
        widget.post;

    final created = latest.createdAt?.split('T').first ?? '';
    final isMine =
        widget.currentLogin.isNotEmpty && widget.currentLogin == latest.userLogin;

    final liked = (latest.myLikeId ?? 0) > 0;
    final likeIcon = liked ? Icons.favorite : Icons.favorite_border;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${latest.userLogin}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Text(created,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Text(latest.message, style: const TextStyle(fontSize: 15.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: liked ? 'Descurtir' : 'Curtir',
                  icon: Icon(likeIcon),
                  onPressed: widget.onLike,
                ),
                Text('${latest.likeCount}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _toggleRepliesPanel,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Consumer<PostProvider>(
                    builder: (_, prov, __) =>
                        Text('Respostas (${prov.replyCountOf(widget.post.id)})'),
                  ),
                ),
                const Spacer(),
                if (isMine)
                  IconButton(
                    tooltip: 'Excluir postagem',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (_showReplies) ...[
              const Divider(height: 16),
              if (_loadingReplies)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Consumer<PostProvider>(
                  builder: (_, prov, __) {
                    final replies = prov.repliesOf(widget.post.id);
                    if (replies.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ainda não há respostas.',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      );
                    }
                    return Column(
                      children: replies
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReplyTile(reply: r),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Responder...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sendReply,
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final Post reply;
  const _ReplyTile({Key? key, required this.reply}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final created = reply.createdAt?.split('T').first ?? '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${reply.userLogin}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(created,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(reply.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTypeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostProvider>();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(value: 0, label: Text('Geral'), icon: Icon(Icons.public)),
          ButtonSegment<int>(value: 1, label: Text('Seguindo'), icon: Icon(Icons.group)),
        ],
        selected: {p.currentFeedType},
        onSelectionChanged: (sel) {
          final ft = sel.first;
          context.read<PostProvider>().fetchFeed(reset: true, feedType: ft, search: p.currentSearch);
        },
        style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
  }
}
