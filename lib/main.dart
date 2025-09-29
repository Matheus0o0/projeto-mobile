import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/user_provider.dart';
import 'provider/post_provider.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_shell.dart';
import 'screens/edit_user_screen.dart' as edit;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PapacapimApp());
}

class PapacapimApp extends StatelessWidget {
  const PapacapimApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..restoreSession()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
      ],
      child: Consumer<UserProvider>(
        builder: (_, user, __) {
          final isLogged = user.isLoggedIn;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Papacapim',
            theme: theme,
            home: isLogged ? const HomeShell() : const LoginScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/home': (_) => const HomeShell(),
              '/feed': (_) => const HomeShell(),     // compatibilidade
              '/explore': (_) => const HomeShell(),  // compatibilidade
              '/profile': (_) => const HomeShell(),  // compatibilidade
              '/edit-profile': (_) => edit.EditUserScreen(), // <<< AQUI
            },
          );
        },
      ),
    );
  }
}
