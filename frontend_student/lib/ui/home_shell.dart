import 'package:flutter/material.dart';
import 'home_page.dart';
import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

