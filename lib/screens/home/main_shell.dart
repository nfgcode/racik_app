import 'package:flutter/material.dart';

import '../history/scan_history_screen.dart';
import '../profile/profile_screen.dart';
import '../recipe/recipe_search_screen.dart';
import '../scan/scan_home_screen.dart';

/// Kerangka navigasi untuk aktor Guest dan Pengguna.
///
/// Tamu tetap melihat keempat tab, tetapi tab Pindai, Riwayat, dan Profil
/// menampilkan ajakan masuk (LoginRequired) — sesuai diagram use case,
/// fitur itu hanya milik aktor Pengguna.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _historyVisits = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga state tiap tab (mis. kata kunci pencarian)
      // saat berpindah tab.
      body: IndexedStack(
        index: _index,
        children: [
          const RecipeSearchScreen(),
          const ScanHomeScreen(),
          // Key baru setiap tab Riwayat dibuka → state lama dibuang dan
          // riwayat dimuat ulang, jadi hasil pindai terbaru langsung muncul.
          ScanHistoryScreen(key: ValueKey(_historyVisits)),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          if (i == 2) _historyVisits++;
          _index = i;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Resep'),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Pindai',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
