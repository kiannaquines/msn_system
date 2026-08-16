import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin_state.dart';
import 'login_screen.dart';
import 'workspace_pages.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;
  static const _destinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
    NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('Catalog')),
    NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Orders')),
    NavigationRailDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: Text('Riders')),
    NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('Live map')),
    NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Reports')),
  ];

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(adminProvider).snapshot;
    if (snapshot == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [DashboardPage(data: snapshot), CatalogPage(data: snapshot), OrdersPage(data: snapshot), RidersPage(data: snapshot), LivePage(data: snapshot), ReportsPage(data: snapshot)];
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      appBar: AppBar(title: Text('M&S · ${_destinations[_index].label is Text ? (_destinations[_index].label as Text).data : 'Operations'}'), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: PopupMenuButton(itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Sign out'))], onSelected: (_) async { await ref.read(adminProvider.notifier).logout(); if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())); }, child: const CircleAvatar(child: Text('AU'))))]),
      body: Row(children: [
        if (wide) NavigationRail(extended: MediaQuery.sizeOf(context).width >= 1180, selectedIndex: _index, onDestinationSelected: (value) => setState(() => _index = value), destinations: _destinations),
        if (wide) const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: _index, children: pages)),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: _index, onDestinationSelected: (value) => setState(() => _index = value), destinations: _destinations.map((item) => NavigationDestination(icon: item.icon, selectedIcon: item.selectedIcon, label: (item.label as Text).data!)).toList()),
    );
  }
}
