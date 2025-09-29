// lib/screens/profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../provider/post_provider.dart';
import '../provider/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewLogin; // se null, abre o próprio perfil
  const ProfileScreen({super.key, this.viewLogin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  final List<Post> _userPosts = <Post>[];
  bool _loading = true;

  late String _login;

  @override
  void initState() {
    super.initState();
    _login = widget.viewLogin ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final me = context.read<UserProvider>().userLogin ?? '';
      if (_login.isEmpty) _login = me;
      await _loadUserPosts(_login);
      await context.read<UserProvider>().loadFollowers(_login);
    });
  }

  Future<void> _loadUserPosts(String login) async {
    setState(() => _loading = true);
    try {
      final res = await _api.getUserPosts(login, page: 1);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        _userPosts
          ..clear()
          ..addAll(data.map((e) => Post.fromJson(e as Map<String, dynamic>)));
      } else {
        _userPosts.clear();
      }
    } catch (_) {
      _userPosts.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final me = up.userLogin ?? '';

    final isMe = _login == me;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$_login', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Seguidores: ${up.followers.length}  •  Seguindo: ${up.followings.length}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (!isMe)
                    FilledButton(
                      onPressed: () async {
                        final ok = await up.followUser(_login);
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agora você segue este usuário.')));
                          setState(() {}); // atualiza contagem de seguidores
                        }
                      },
                      child: const Text('Seguir'),
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          SliverList.builder(
            itemCount: _userPosts.length,
            itemBuilder: (_, i) {
              final p = _userPosts[i];
              return _PostTile(post: p);
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final pp = context.read<PostProvider>();
    final created = post.createdAt?.split('T').first ?? '';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
              const SizedBox(width: 8),
              Text('@${post.userLogin}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(created, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
            const SizedBox(height: 8),
            Text(post.message),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await pp.loadReplies(post);
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _RepliesSheet(post: post),
                      );
                    }
                  },
                  icon: const Icon(Icons.reply_outlined),
                  label: Text('Respostas (${post.replies.length})'),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RepliesSheet extends StatefulWidget {
  final Post post;
  const _RepliesSheet({required this.post});

  @override
  State<_RepliesSheet> createState() => _RepliesSheetState();
}

class _RepliesSheetState extends State<_RepliesSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    setState(() => _sending = true);
    final ok = await context.read<PostProvider>().reply(widget.post.id, txt);
    if (mounted) {
      setState(() => _sending = false);
      if (ok) _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostProvider>();
    final post = widget.post;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 12, right: 12, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          Align(alignment: Alignment.centerLeft, child: Text('Respostas de @${post.userLogin}')),
          const SizedBox(height: 8),
          if (!post.repliesLoaded)
            const LinearProgressIndicator(minHeight: 2)
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: post.replies.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = post.replies[i];
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                    title: Text('@${r.userLogin}', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(r.message),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Responder…', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
