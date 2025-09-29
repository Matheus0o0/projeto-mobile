import 'package:flutter/material.dart';
import '../models/post.dart';

class TweetCard extends StatelessWidget {
  final Post post;
  final String me;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  const TweetCard({
    super.key,
    required this.post,
    required this.me,
    required this.onLike,
    required this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final created = post.createdAt?.split('T').first ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('@${post.userLogin}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(created, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.myLikeId != null ? Icons.favorite : Icons.favorite_border,
                    color: post.myLikeId != null ? Colors.pinkAccent : Colors.white70,
                  ),
                  tooltip: post.myLikeId != null ? 'Descurtir' : 'Curtir',
                  onPressed: onLike,
                ),
                Text('${post.likeCount}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  tooltip: 'Responder',
                  onPressed: onReply,
                ),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Excluir',
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (post.replies.isNotEmpty) const Divider(height: 8, thickness: .4),
            if (post.replies.isNotEmpty)
              ...post.replies.map((r) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('↳ @${r.userLogin} respondeu @${post.userLogin}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          const SizedBox(height: 2),
                          Text(r.message),
                          const SizedBox(height: 2),
                          Text(r.createdAt?.split('T').first ?? '',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ]),
                      ),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }
}
