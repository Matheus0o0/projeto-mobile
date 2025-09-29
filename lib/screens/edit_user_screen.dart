import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/user_provider.dart';

class EditUserScreen extends StatefulWidget {
  const EditUserScreen({Key? key}) : super(key: key);

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _loginCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _showPass = false;
  bool _showPass2 = false;

  @override
  void initState() {
    super.initState();
    final up = context.read<UserProvider>();
    _loginCtrl.text = up.user?.login ?? up.userLogin ?? '';
    _nameCtrl.text = up.user?.name ?? '';
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final userProv = context.read<UserProvider>();
    final newLogin = _loginCtrl.text.trim();
    final newName = _nameCtrl.text.trim();
    final newPass = _passCtrl.text.trim();
    final newPass2 = _pass2Ctrl.text.trim();

    final ok = await userProv.updateProfile(
      name: newName.isNotEmpty ? newName : null,
      newLogin: newLogin.isNotEmpty ? newLogin : null,
      password: newPass.isNotEmpty ? newPass : null,
      passwordConfirmation: newPass2.isNotEmpty ? newPass2 : null,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar perfil.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza que deseja excluir sua conta? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (sure != true) return;

    setState(() => _isDeleting = true);
    final ok = await context.read<UserProvider>().deleteAccount();
    setState(() => _isDeleting = false);

    if (!mounted) return;

    if (ok) {
      // Sai para a tela de login
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta excluída com sucesso.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir a conta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                // LOGIN
                TextFormField(
                  controller: _loginCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Login (@usuario)',
                    border: OutlineInputBorder(),
                    prefixText: '@',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Informe um login';
                    if (s.contains(' ')) return 'Não use espaços no login';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // NAME
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Informe seu nome';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // PASSWORD
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    labelText: 'Nova senha (opcional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPass = !_showPass),
                      icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // PASSWORD CONFIRMATION
                TextFormField(
                  controller: _pass2Ctrl,
                  obscureText: !_showPass2,
                  decoration: InputDecoration(
                    labelText: 'Confirmar nova senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPass2 = !_showPass2),
                      icon: Icon(_showPass2 ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (v) {
                    final p1 = _passCtrl.text.trim();
                    final p2 = (v ?? '').trim();
                    if (p1.isEmpty && p2.isEmpty) return null; // sem troca de senha
                    if (p1 != p2) return 'As senhas não coincidem';
                    if (p1.length < 4) return 'Use ao menos 4 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // SALVAR
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar alterações'),
                  ),
                ),
                const SizedBox(height: 12),

                // EXCLUIR CONTA
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    onPressed: _isDeleting ? null : _deleteAccount,
                    child: _isDeleting
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Excluir conta'),
                  ),
                ),

                const SizedBox(height: 8),
                if (up.userLogin != null)
                  Text(
                    'Logado como @${up.userLogin}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
