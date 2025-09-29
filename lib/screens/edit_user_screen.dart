import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/user_provider.dart';
import '../models/user.dart';

class EditUserScreen extends StatefulWidget {
  const EditUserScreen({super.key});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _saving = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
          ..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);

    final up = context.read<UserProvider>();
    final User? u = up.user;
    _loginCtrl.text = u?.login.isNotEmpty == true ? u!.login : (up.userLogin ?? '');
    _nameCtrl.text = (u?.name ?? '').isNotEmpty ? u!.name : '';
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _loginCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final newLogin = _loginCtrl.text.trim();
    final newName = _nameCtrl.text.trim();
    final newPass = _passwordCtrl.text;
    final newPassConf = _confirmCtrl.text;

    try {
      final ok = await context.read<UserProvider>().updateProfile(
            name: newName.isNotEmpty ? newName : null, // <- usa name
            password: newPass.isNotEmpty ? newPass : null,
            passwordConfirmation: newPassConf.isNotEmpty ? newPassConf : null,
            newLogin: newLogin.isNotEmpty ? newLogin : null, // <- usa newLogin
          );

      if (!mounted) return;
      if (ok) {
        _snack('Dados atualizados com sucesso.');
        Navigator.pop(context);
      } else {
        _snack('Não foi possível atualizar os dados.');
      }
    } catch (e) {
      _snack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text('Tem certeza? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    final ok = await context.read<UserProvider>().deleteAccount();
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _snack('Conta excluída.');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } else {
      _snack('Não foi possível excluir a conta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // fundo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF1F2937)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -80, right: -40, child: _Bubble(color: Colors.blueAccent.withOpacity(0.25), size: 180)),
          Positioned(bottom: -60, left: -30, child: _Bubble(color: Colors.purpleAccent.withOpacity(0.20), size: 160)),

          // conteúdo
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 36),
                              const SizedBox(width: 12),
                              Text(
                                'Editar perfil',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // login
                          _ModernField(
                            controller: _loginCtrl,
                            label: 'Login',
                            icon: Icons.alternate_email_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um login' : null,
                          ),
                          const SizedBox(height: 14),

                          // nome
                          _ModernField(
                            controller: _nameCtrl,
                            label: 'Nome',
                            icon: Icons.badge_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                          ),
                          const SizedBox(height: 14),

                          // senha (opcional)
                          _ModernField(
                            controller: _passwordCtrl,
                            label: 'Nova senha (opcional)',
                            icon: Icons.lock_outline,
                            obscure: _obscure1,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure1 = !_obscure1),
                              icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // confirmar senha (opcional)
                          _ModernField(
                            controller: _confirmCtrl,
                            label: 'Confirmar nova senha',
                            icon: Icons.lock_person_outlined,
                            obscure: _obscure2,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure2 = !_obscure2),
                              icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                              color: Colors.white70,
                            ),
                            validator: (v) {
                              if (_passwordCtrl.text.isEmpty && (v ?? '').isEmpty) return null;
                              if (v != _passwordCtrl.text) return 'Senhas não coincidem';
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),

                          // salvar
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _saving
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Salvar alterações', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // excluir
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _saving ? null : _deleteAccount,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Excluir conta'),
                            ),
                          ),

                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            child: const Text('Voltar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Helpers visuais (iguais aos usados nas outras telas) =====

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 40,
                spreadRadius: -8,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModernField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _ModernField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Color color;
  final double size;
  const _Bubble({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
