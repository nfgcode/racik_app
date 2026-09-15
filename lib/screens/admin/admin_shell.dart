import 'package:flutter/material.dart';

import 'admin_foods_screen.dart';
import 'admin_ingredients_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_users_screen.dart';

/// Kerangka navigasi aktor Admin — satu tab untuk setiap use case Admin.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _pages = [
    AdminFoodsScreen(), // Mengelola Data Resep
    AdminIngredientsScreen(), // Mengelola Data Bahan
    AdminStatsScreen(), // Melihat Statistik Pemindaian Pengguna
    AdminUsersScreen(), // Mengelola Akun Pengguna
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Resep'),
          NavigationDestination(icon: Icon(Icons.egg_alt_outlined), label: 'Bahan'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Statistik'),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Akun'),
        ],
      ),
    );
  }
}
