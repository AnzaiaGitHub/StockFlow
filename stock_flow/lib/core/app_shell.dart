import 'package:flutter/material.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/movements/movements_screen.dart';
import '../features/products/products_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _titles = ['Dashboard', 'Productos', 'Movimientos'];

  static const _screens = <Widget>[
    DashboardScreen(),
    ProductsScreen(),
    MovementsScreen(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Productos',
    ),
    NavigationDestination(
      icon: Icon(Icons.swap_vert_outlined),
      selectedIcon: Icon(Icons.swap_vert),
      label: 'Movimientos',
    ),
  ];

  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations,
      ),
    );
  }
}
