// lib/screens/login_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../provider/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscure = true;

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
    _passwordController.dispose();
    super.dispose();
  }

  void _sn(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final api = ApiService();

    try {
      // [A] chamar /sessions
      final res = await api.login(_loginController.text.trim(), _passwordController.text);
      // ignore: avoid_print
      print('[A] /sessions -> ${res.statusCode} | ${res.body}');
      if (res.statusCode != 200) {
        if (res.statusCode == 401) return _sn('Falha [A]: usuário/senha inválidos.');
        if (res.statusCode == 404) return _sn('Falha [A]: endpoint incorreto (deve ser POST /sessions).');
        return _sn('Falha [A]: ${res.statusCode} • ${res.body}');
      }

      // [B] decodificar sessão
      Map<String, dynamic> session;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) return _sn('Falha [B1]: resposta não é objeto JSON.');
        session = decoded;
      } catch (e) {
        return _sn('Falha [B2]: não foi possível ler a resposta do login.');
      }

      // [C] extrair token/id/login
      final token = session['token'];
      final sessionId = _asInt(session['id']);     // pode vir null e tudo bem
      final userLogin = session['user_login'];
      // ignore: avoid_print
      print('[C] token=${token is String}, sessionId=$sessionId, userLogin=$userLogin');
      if (token is! String || userLogin is! String) {
        return _sn('Falha [C1]: token/login ausentes na sessão.');
      }

      // [D] buscar usuário
      final userRes = await api.getUserByLogin(userLogin, token: token);
      // ignore: avoid_print
      print('[D] GET /users/$userLogin -> ${userRes.statusCode} | ${userRes.body}');
      if (userRes.statusCode != 200) {
        if (userRes.statusCode == 401) return _sn('Falha [D1]: token inválido.');
        if (userRes.statusCode == 404) return _sn('Falha [D2]: usuário não encontrado.');
        return _sn('Falha [D3]: ${userRes.statusCode}.');
      }

      // [E] decodificar usuário
      Map<String, dynamic> userJson;
      try {
        final body = jsonDecode(userRes.body);
        if (body is! Map<String, dynamic>) return _sn('Falha [E1]: usuário em formato inesperado.');
        userJson = body;
      } catch (e) {
        return _sn('Falha [E2]: não foi possível ler os dados do usuário.');
      }

      // [F] atualizar Provider + persistir sessão (id opcional)
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setSession(
          token: token,
          sessionId: sessionId,   // agora aceita null
          userLogin: userLogin,
        );
        await api.persistSession(
          token: token,
          sessionId: sessionId,   // se null, a persistência remove a chave sem quebrar
          userLogin: userLogin,
        );
        userProvider.setUser(User.fromJson(userJson));
      } catch (e) {
        // se algo aqui quebrar, vamos saber
        return _sn('Falha [F]: $e');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } catch (e) {
      _sn('Falha [G]: $e'); // exceções fora dos blocos acima
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FlutterLogo(size: 40),
                            const SizedBox(width: 12),
                            Text(
                              'Papacapim',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700, color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Entre para continuar',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _ModernField(
                                controller: _loginController,
                                label: 'Login',
                                icon: Icons.person_outline,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Informe seu login' : null,
                              ),
                              const SizedBox(height: 14),
                              _ModernField(
                                controller: _passwordController,
                                label: 'Senha',
                                icon: Icons.lock_outline,
                                obscure: _obscure,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                  color: Colors.white70,
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
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
                                            'Entrar',
                                            style: TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pushNamed(context, '/register'),
                                child: const Text('Criar nova conta'),
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
            IgnorePointer(
              child: Container(width: size.width, height: size.height, color: Colors.black26),
            ),
        ],
      ),
    );
  }
}

// helpers visuais
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
