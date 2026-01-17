import 'package:flutter/material.dart';
import 'classes/classes_page.dart';
// import 'history_page.dart'; // No longer needed here
import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;

  // REMOVED: HistoryPage from the list of pages
  final pages = const [ClassesPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        // REMOVED: The NavigationDestination for 'History'
        destinations: const [
          NavigationDestination(icon: Icon(Icons.class_), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onDestinationSelected: (i) => setState(() => idx = i),
      ),
    );
  }
}
