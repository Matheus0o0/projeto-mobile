// lib/screens/register_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../provider/user_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _loginController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _extractApiErrors(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['errors'] is Map) {
        final errs = data['errors'] as Map;
        final parts = <String>[];
        errs.forEach((k, v) {
          if (v is List && v.isNotEmpty) {
            parts.add('$k: ${v.join(", ")}');
          } else if (v is String) {
            parts.add('$k: $v');
          }
        });
        if (parts.isNotEmpty) return parts.join(' • ');
      }
    } catch (_) {}
    return body.isEmpty ? 'Dados inválidos' : body;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final api = ApiService();

    try {
      final res = await api.createUser(
        login: _loginController.text.trim(),
        name: _nameController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );

      if (res.statusCode == 201) {
        // auto-login
        final loginRes = await api.login(_loginController.text.trim(), _passwordController.text);
        if (loginRes.statusCode == 200) {
          final session = jsonDecode(loginRes.body);
          final token = session['token'];
          final sessionId = session['id'];
          final userLogin = session['user_login'];

          if (token is String && sessionId is int && userLogin is String) {
            final userRes = await api.getUserByLogin(userLogin, token: token);
            if (userRes.statusCode == 200) {
              final userJson = jsonDecode(userRes.body) as Map<String, dynamic>;
              if (!mounted) return;
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              userProvider.setSession(token: token, sessionId: sessionId, userLogin: userLogin);
              userProvider.setUser(User.fromJson(userJson));
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/feed');
            } else {
              _showSnack('Conta criada. Faça login manualmente.');
              if (!mounted) return;
              Navigator.pop(context);
            }
          } else {
            _showSnack('Conta criada, mas login retornou formato inesperado.');
          }
        } else {
          final extra = loginRes.body.isNotEmpty ? ' • ${loginRes.body}' : '';
          _showSnack('Conta criada, mas login falhou (${loginRes.statusCode})$extra');
          if (!mounted) return;
          Navigator.pop(context);
        }
      } else if (res.statusCode == 422) {
        _showSnack('Erro 422: ${_extractApiErrors(res.body)}');
      } else {
        final extra = res.body.isNotEmpty ? ' • ${res.body}' : '';
        _showSnack('Erro ${res.statusCode} ao criar conta$extra');
      }
    } catch (e) {
      _showSnack('Falha na requisição: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF1F2937)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -80, right: -40, child: _Bubble(color: Colors.blueAccent.withOpacity(0.3), size: 180)),
          Positioned(bottom: -60, left: -30, child: _Bubble(color: Colors.purpleAccent.withOpacity(0.25), size: 160)),
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FlutterLogo(size: 40),
                            const SizedBox(width: 12),
                            Text('Criar conta',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700, color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _ModernField(
                                controller: _loginController,
                                label: 'Login (único)',
                                icon: Icons.person_outline,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um login' : null,
                              ),
                              const SizedBox(height: 14),
                              _ModernField(
                                controller: _nameController,
                                label: 'Nome',
                                icon: Icons.badge_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                              ),
                              const SizedBox(height: 14),
                              _ModernField(
                                controller: _passwordController,
                                label: 'Senha',
                                icon: Icons.lock_outline,
                                obscure: _obscure1,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                                  icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                                  color: Colors.white70,
                                ),
                                validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
                              ),
                              const SizedBox(height: 14),
                              _ModernField(
                                controller: _confirmController,
                                label: 'Confirmar senha',
                                icon: Icons.lock_person_outlined,
                                obscure: _obscure2,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                                  icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                                  color: Colors.white70,
                                ),
                                validator: (v) => (v != _passwordController.text) ? 'Senhas não coincidem' : null,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: _isLoading
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 22, height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text(
                                            key: ValueKey('text'),
                                            'Criar conta',
                                            style: TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _isLoading ? null : () => Navigator.pop(context),
                                child: const Text('Já tenho conta'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            IgnorePointer(child: Container(width: size.width, height: size.height, color: Colors.black26)),
        ],
      ),
    );
  }
}

// helpers
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
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: -8, offset: Offset(0, 18))],
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
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}
