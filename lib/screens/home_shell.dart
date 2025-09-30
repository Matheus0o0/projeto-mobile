import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/post_provider.dart';
import '../provider/user_provider.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final ScrollController _feedScrollCtrl = ScrollController();
  late final List<Widget> _pages = [
    FeedScreen(compactAppBar: true, controller: _feedScrollCtrl),
    const ExploreScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().fetchFeed(reset: true);
    });
  }

  Future<void> _scrollFeedToTop() async {
    if (!_feedScrollCtrl.hasClients) return;
    try {
      await _feedScrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _feedScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      extendBody: true,
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (i == _index) {
            if (i == 0) await _scrollFeedToTop();
            return;
          }
          final willShowFeed = i == 0;
          setState(() => _index = i);
          if (willShowFeed && mounted) {
            context.read<PostProvider>().refreshFeedSoft();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _scrollFeedToTop,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              label: const Text('Topo'),
            )
          : (_index == 2 && (user.userLogin ?? '').isNotEmpty)
              ? FloatingActionButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/edit-profile'),
                  child: const Icon(Icons.edit),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
