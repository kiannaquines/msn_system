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

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.group,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String group;
  final String? badge;
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;
  bool _isRefreshing = false;

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Overview',
      group: 'COMMAND & CONTROL',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
      label: 'Live Operations',
      group: 'COMMAND & CONTROL',
      badge: 'LIVE',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Orders & Dispatch',
      group: 'CORE WORKFLOWS',
    ),
    _NavItem(
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      label: 'Store Catalog',
      group: 'FLEET & MERCHANTS',
    ),
    _NavItem(
      icon: Icons.two_wheeler_outlined,
      selectedIcon: Icons.two_wheeler_rounded,
      label: 'Riders Fleet',
      group: 'FLEET & MERCHANTS',
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
      label: 'Reports',
      group: 'INSIGHTS & AUDIT',
    ),
  ];

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(adminProvider.notifier).refreshDeliveries();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operations telemetry and snapshot updated.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final snapshot = state.snapshot;
    if (snapshot == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9D65E5)),
        ),
      );
    }

    final pages = [
      DashboardPage(data: snapshot),
      LivePage(data: snapshot),
      OrdersPage(data: snapshot),
      CatalogPage(data: snapshot),
      RidersPage(data: snapshot),
      ReportsPage(data: snapshot),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 860;
    final currentIndex = _index.clamp(0, _navItems.length - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        titleSpacing: isDesktop ? 24 : 16,
        leading: isDesktop
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: Row(
          children: [
            if (!isDesktop) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              'M&S Operations',
              style: TextStyle(
                color: isDesktop ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (isDesktop) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('›', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16)),
              ),
              Text(
                _navItems[currentIndex].label,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Realtime Live Status Indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isDesktop ? 'Realtime Connected' : 'LIVE',
                  style: const TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Quick Telemetry Refresh Button
          IconButton(
            tooltip: 'Refresh platform telemetry',
            icon: _isRefreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9D65E5)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
          const SizedBox(width: 6),

          // User Profile Menu
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'admin@mns.ph',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                      Divider(height: 16),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'logout') {
                  await ref.read(adminProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: const Color(0xFF9D65E5),
                      child: const Text(
                        'AU',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Admin',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(backgroundColor: Colors.white, child: _buildSidebarContent(context)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop)
            Container(
              width: 250,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: _buildSidebarContent(context),
            ),
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _index,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFB89CE5).withValues(alpha: 0.2),
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: _navItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon, color: const Color(0xFF64748B)),
                        selectedIcon: Icon(item.selectedIcon, color: const Color(0xFF9D65E5)),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    String? currentGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Brand Banner (Light)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'M&S System',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Kabacan Operations Hub',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Sidebar Nav Items (Light)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              for (int i = 0; i < _navItems.length; i++) ...[
                if (_navItems[i].group != currentGroup) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
                    child: Text(
                      _navItems[i].group,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  () {
                    currentGroup = _navItems[i].group;
                    return const SizedBox.shrink();
                  }(),
                ],
                _buildNavItem(i),
              ],
            ],
          ),
        ),

        // Sidebar Footer Status Card (Light)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 16),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Operational', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w700)),
                      Text('Vercel SG · Supabase Live', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _index == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE9D5FF) : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _index = index);
              if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                Navigator.pop(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF334155),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF047857),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
