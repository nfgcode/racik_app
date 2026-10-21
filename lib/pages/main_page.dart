import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../controller/food_controller.dart';
import 'food_list_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'scan_page.dart';

/// Kerangka navigasi untuk aktor Guest dan Pengguna.
///
/// Tamu tetap melihat keempat tab, tetapi tab Pindai, Riwayat, dan Profil
/// menampilkan ajakan masuk — sesuai diagram use case, fitur itu hanya
/// milik aktor Pengguna.
class MainPage extends StatefulWidget {
  final AuthController authController;
  final FoodController foodController;

  const MainPage({
    super.key,
    required this.authController,
    required this.foodController,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // IndexedStack menjaga state tiap tab (mis. kata kunci pencarian)
  // saat berpindah tab.
  late final List<Widget> _pages = [
    FoodListPage(foodController: widget.foodController),
    ScanPage(authController: widget.authController),
    HistoryPage(authController: widget.authController),
    ProfilePage(authController: widget.authController),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
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
