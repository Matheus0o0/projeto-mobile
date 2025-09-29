// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewLogin; // se nulo, mostra meu perfil

  const ProfileScreen({super.key, this.viewLogin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _login;

  @override
  void initState() {
    super.initState();
    final up = context.read<UserProvider>();
    _login = widget.viewLogin ?? (up.userLogin ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final me = up.userLogin ?? '';
    final isMe = _login == me;

    final following = up.following; // minha lista local
    final isFollowing = up.isFollowing(_login);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Meu perfil' : '@$_login'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
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

          // Quem eu sigo (apenas no meu perfil)
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

          // (Opcional) Você pode adicionar outras seções aqui (bio, posts, etc.)
        ],
      ),
    );
  }
}
