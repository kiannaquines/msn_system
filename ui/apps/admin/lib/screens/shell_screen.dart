import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin_state.dart';
import 'login_screen.dart';
import 'workspace_pages.dart';

class _NavItem {
  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;
  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Catalog'),
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Orders'),
    _NavItem(icon: Icons.delivery_dining_outlined, selectedIcon: Icons.delivery_dining, label: 'Riders'),
    _NavItem(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Live map'),
    _NavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(adminProvider).snapshot;
    if (snapshot == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [
      DashboardPage(data: snapshot),
      CatalogPage(data: snapshot),
      OrdersPage(data: snapshot),
      RidersPage(data: snapshot),
      LivePage(data: snapshot),
      ReportsPage(data: snapshot),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: Text('M&S · ${_navItems[_index].label}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton(
              itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Sign out'))],
              onSelected: (_) async {
                await ref.read(adminProvider.notifier).logout();
                if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                child: Text('AU', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                children: [
                  for (var i = 0; i < _navItems.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: _index == i ? const Color(0xFFFF6B24).withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: Icon(
                            _index == i ? _navItems[i].selectedIcon : _navItems[i].icon,
                            color: _index == i ? const Color(0xFFFF6B24) : Colors.black87,
                          ),
                          title: Text(
                            _navItems[i].label,
                            style: TextStyle(
                              color: _index == i ? const Color(0xFFFF6B24) : Colors.black87,
                              fontWeight: _index == i ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          onTap: () => setState(() => _index = i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              color: const Color(0xFFFFF8F1),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: _navItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }
}
