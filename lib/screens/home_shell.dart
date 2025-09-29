import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/user_provider.dart';
import '../provider/post_provider.dart';

// alias para evitar conflito de nomes
import 'explore_screen.dart' as explore;

import 'feed_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({Key? key, this.initialIndex = 0}) : super(key: key);

  final int initialIndex;

  static void scrollToTop() {
    // atalho, caso queira acionar algo global depois
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  late final List<Widget> _pages = <Widget>[
    const FeedScreen(compactAppBar: true),
    explore.ExploreScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _pages.length - 1);
    // carrega feed ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().fetchFeed(reset: true);
    });
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
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => FeedScreen.scrollToTop(),
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              label: const Text('Topo'),
            )
          : (_index == 2 && (user.userLogin ?? '').isNotEmpty)
              ? FloatingActionButton(
                  onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
                  child: const Icon(Icons.edit),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
