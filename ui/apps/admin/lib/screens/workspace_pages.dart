import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../util/report_export.dart';

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.subtitle, required this.child, this.actions = const []});
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                child,
              ],
            ),
          ),
        ),
      );
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.data});
  final AdminSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOrders = data.orders.where((order) => order.status == AdminOrderStatus.pending).toList();
    final activeDeliveries = data.deliveries.where((delivery) => delivery.status != AdminOrderStatus.delivered && delivery.status != AdminOrderStatus.cancelled).toList();
    final availableRiders = data.riders.where((rider) => rider.status == AdminRiderStatus.available).toList();
    final revenue = (data.report['cod_sales'] ?? data.orders.where((order) => order.codPaid).fold<double>(0, (sum, order) => sum + order.total)).toDouble();

    return _Page(
      title: 'Operations Command Center',
      subtitle: 'Real-time overview of incoming orders, active fleet, and cash collections.',
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Live Telemetry Active',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
              ),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Kpi(
                label: 'Pending Orders',
                value: '${pendingOrders.length}',
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFCD34D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                subtext: pendingOrders.isEmpty ? 'All orders processed' : 'Awaiting confirmation & dispatch',
              ),
              _Kpi(
                label: 'Active Deliveries',
                value: '${activeDeliveries.length}',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFF4F46E5),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                subtext: activeDeliveries.isEmpty ? 'No deliveries en route' : 'In transit across fleet',
              ),
              _Kpi(
                label: 'Available Riders',
                value: '${availableRiders.length} / ${data.riders.length}',
                icon: Icons.sports_motorsports_rounded,
                color: const Color(0xFF10B981),
                gradient: const LinearGradient(
                  colors: [Color(0xFF047857), Color(0xFF10B981), Color(0xFF34D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                subtext: '${data.riders.length - availableRiders.length} riders currently on delivery',
              ),
              _Kpi(
                label: 'COD Collected',
                value: '₱${NumberFormat('#,##0').format(revenue)}',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFFF6B24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5216), Color(0xFFFF6B24), Color(0xFFFF9233)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                subtext: '${data.orders.where((o) => o.codPaid).length} settled cash orders',
              ),
            ],
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final leftCol = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'Orders Requiring Attention',
                    badge: pendingOrders.isEmpty ? null : '${pendingOrders.length} Pending',
                    child: pendingOrders.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 44),
                                SizedBox(height: 12),
                                Text(
                                  'All caught up!',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'There are no pending orders waiting for assignment.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: pendingOrders.map((order) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8F1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B24).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFF6B24), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              order.id.length > 12 ? '${order.id.substring(0, 12)}...' : order.id,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${order.customer} · ${order.store}',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₱${order.total.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 6),
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(0, 32),
                                          backgroundColor: const Color(0xFFFF6B24),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => showAssignRiderDialog(context, ref, data, order),
                                        child: const Text('Assign Rider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Active Delivery Tracking',
                    badge: activeDeliveries.isEmpty ? null : '${activeDeliveries.length} in Transit',
                    child: activeDeliveries.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: const Text('No active deliveries in transit right now.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : Column(
                            children: activeDeliveries.map((delivery) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                    child: const Icon(Icons.delivery_dining, color: Color(0xFF3B82F6), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${delivery.rider} → ${delivery.customer}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Order ${delivery.orderId.length > 10 ? '${delivery.orderId.substring(0, 10)}...' : delivery.orderId}',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      delivery.status.label,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                  ),
                ],
              );

              final rightCol = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'Rider Fleet Status',
                    badge: '${availableRiders.length} Online',
                    child: Column(
                      children: data.riders.map((rider) {
                        final isAvail = rider.status == AdminRiderStatus.available;
                        final isBusy = rider.status == AdminRiderStatus.busy;
                        final dotColor = isAvail ? const Color(0xFF10B981) : (isBusy ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: dotColor.withValues(alpha: 0.15),
                                child: Text(
                                  rider.name.isEmpty ? '?' : rider.name.substring(0, 1),
                                  style: TextStyle(fontWeight: FontWeight.w800, color: dotColor, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rider.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                                    Text(rider.phone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 4, backgroundColor: dotColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    isAvail ? 'Available' : (isBusy ? 'On Delivery' : 'Offline'),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dotColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Recent Activity & Audit',
                    child: data.audit.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No audit events yet.', style: TextStyle(color: Color(0xFF64748B)))))
                        : Column(
                            children: data.audit.take(5).map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${entry.actor} · ${entry.reason.isNotEmpty ? entry.reason : 'System action'}',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('h:mm a').format(entry.createdAt),
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftCol),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: rightCol),
                  ],
                );
              }
              return Column(children: [leftCol, const SizedBox(height: 24), rightCol]);
            },
          ),
        ],
      ),
    );
  }
}

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, required this.data});
  final AdminSnapshot data;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String _searchQuery = '';
  bool? _availabilityFilter;
  String? _selectedCategory;

  Widget _buildStoreAvailabilityFilterChip(String label, bool? value, bool isSelected, {Color? dotColor}) {
    return InkWell(
      onTap: () => setState(() => _availabilityFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(adminProvider).snapshot ?? widget.data;
    final allStores = snapshot.stores;

    // Calculate metrics
    final totalStores = allStores.length;
    final openStores = allStores.where((s) => s.available).length;
    final allDishes = allStores.expand((s) => s.items).toList();
    final totalDishes = allDishes.length;
    final avgPrice = allDishes.isEmpty ? 0.0 : (allDishes.map((i) => i.price).reduce((a, b) => a + b) / totalDishes);

    // Extract all unique categories
    final categories = allDishes.map((i) => i.category).toSet().toList()..sort();

    // Filter stores based on search query, open/closed status, and category
    final filteredStores = allStores.where((store) {
      if (_availabilityFilter != null && store.available != _availabilityFilter) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchStoreName = store.name.toLowerCase().contains(q);
        final matchStoreDesc = store.description.toLowerCase().contains(q);
        final matchDishes = store.items.any((i) => i.name.toLowerCase().contains(q) || i.category.toLowerCase().contains(q));
        if (!matchStoreName && !matchStoreDesc && !matchDishes) return false;
      }

      if (_selectedCategory != null) {
        final hasCategory = store.items.any((i) => i.category == _selectedCategory);
        if (!hasCategory) return false;
      }

      return true;
    }).toList();

    return _Page(
      title: 'Store & Menu Catalog',
      subtitle: 'Manage active restaurant partners, menu dishes, prices, categories, and real-time merchant availability.',
      actions: [
        FilledButton.icon(
          onPressed: () => _editStore(context, ref),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Add Store Partner'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Metric Summary Banner
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Kpi(
                label: 'Partner Stores',
                value: '$totalStores Stores',
                icon: Icons.storefront_rounded,
                color: const Color(0xFFFF6B24),
                subtext: '$openStores Open · ${totalStores - openStores} Closed',
              ),
              _Kpi(
                label: 'Menu Dishes',
                value: '$totalDishes Items',
                icon: Icons.restaurant_menu_rounded,
                color: const Color(0xFF3B82F6),
                subtext: 'Across ${categories.length} Food Categories',
              ),
              _Kpi(
                label: 'Open Merchants',
                value: '$openStores / $totalStores',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                subtext: 'Ready for customer orders',
              ),
              _Kpi(
                label: 'Average Price',
                value: '₱${avgPrice.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
                color: const Color(0xFF8B5CF6),
                subtext: 'Across full platform catalog',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x04000000), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search restaurants, menu dishes, or categories...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Quick Status Filter Pills
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStoreAvailabilityFilterChip('All Stores', null, _availabilityFilter == null),
                          const SizedBox(width: 4),
                          _buildStoreAvailabilityFilterChip('Open Now', true, _availabilityFilter == true, dotColor: const Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          _buildStoreAvailabilityFilterChip('Closed', false, _availabilityFilter == false, dotColor: const Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Category: ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          showCheckmark: false,
                          label: const Text('All Categories'),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedCategory == null ? FontWeight.w800 : FontWeight.w600,
                            color: _selectedCategory == null ? Colors.white : const Color(0xFF475569),
                          ),
                          selected: _selectedCategory == null,
                          selectedColor: const Color(0xFF7C3AED),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: BorderSide(color: _selectedCategory == null ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          onSelected: (_) => setState(() => _selectedCategory = null),
                        ),
                        ...categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(cat),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF7C3AED),
                              backgroundColor: const Color(0xFFF8FAFC),
                              side: BorderSide(color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              onSelected: (sel) => setState(() => _selectedCategory = sel ? cat : null),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Balanced Responsive Store Cards Grid
          if (filteredStores.isEmpty)
            Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_mall_directory_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No store partners match your search criteria.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    const Text('Try adjusting your search terms or clearing the category filter.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isSingleCol = constraints.maxWidth < 880;
                final isTripleCol = constraints.maxWidth > 1420;
                final columnCount = isTripleCol ? 3 : (isSingleCol ? 1 : 2);
                final cardWidth = (constraints.maxWidth - (columnCount - 1) * 20) / columnCount;

                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: filteredStores.map((store) {
                    // Filter store items if a search query or category is active
                    final displayItems = store.items.where((i) {
                      if (_selectedCategory != null && i.category != _selectedCategory) return false;
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final matchItem = i.name.toLowerCase().contains(q) || i.category.toLowerCase().contains(q);
                        final matchStore = store.name.toLowerCase().contains(q) || store.description.toLowerCase().contains(q);
                        if (!matchItem && !matchStore) return false;
                      }
                      return true;
                    }).toList();

                    return SizedBox(
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: store.available ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
                            width: store.available ? 1 : 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store Card Header (Fixed height content)
                            Container(
                              height: 92,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: store.available
                                    ? const Color(0xFFFF6B24).withValues(alpha: 0.04)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Store Icon Avatar
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: store.available
                                        ? const Color(0xFFFF6B24).withValues(alpha: 0.15)
                                        : Colors.grey.shade300,
                                    child: Text(
                                      store.name.isEmpty ? 'S' : store.name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: store.available ? const Color(0xFFFF6B24) : Colors.black45,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          store.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          store.description.isNotEmpty ? store.description : 'Authentic Filipino restaurant partner',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Availability Switch Toggle
                                  Tooltip(
                                    message: store.available ? 'Store is Open & Accepting Orders' : 'Store is Closed',
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Transform.scale(
                                          scale: 0.85,
                                          child: Switch(
                                            value: store.available,
                                            activeThumbColor: const Color(0xFF10B981),
                                            activeTrackColor: const Color(0xFFA7F3D0),
                                            onChanged: (value) async => ref
                                                .read(adminProvider.notifier)
                                                .saveStore(store.copyWith(available: value)),
                                          ),
                                        ),
                                        Text(
                                          store.available ? 'OPEN' : 'CLOSED',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: store.available ? const Color(0xFF10B981) : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Store Dishes List Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Menu Dishes (${store.items.length})',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _editMenuItem(context, ref, store),
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                    label: const Text('Add Dish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),

                            // Store Dishes Scrollable View (Fixed balanced height of 280px)
                            SizedBox(
                              height: 280,
                              child: displayItems.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.restaurant_outlined, size: 32, color: Colors.grey.shade300),
                                          const SizedBox(height: 6),
                                          Text(
                                            store.items.isEmpty ? 'No menu dishes added yet.' : 'No dishes match filter.',
                                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      itemCount: displayItems.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                                      itemBuilder: (context, index) {
                                        final item = displayItems[index];
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: item.available ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13,
                                                        color: item.available ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                        decoration: item.available ? null : TextDecoration.lineThrough,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            item.category,
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                                          ),
                                                        ),
                                                        if (!item.available) ...[
                                                          const SizedBox(width: 6),
                                                          const Text('Sold Out', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w700)),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '₱${item.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color: item.available ? const Color(0xFF0F172A) : Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Edit Dish
                                              IconButton(
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                                tooltip: 'Edit dish',
                                                onPressed: () => _editMenuItem(context, ref, store, item),
                                              ),
                                              // Remove Dish
                                              IconButton(
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                                tooltip: 'Remove dish',
                                                onPressed: () async => ref.read(adminProvider.notifier).removeMenuItem(store.id, item),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),

                            // Store Card Footer Actions (Pinned at bottom)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _editStore(context, ref, store),
                                      icon: const Icon(Icons.edit_rounded, size: 16),
                                      label: const Text('Edit Store', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    style: IconButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(color: Color(0xFFFECACA)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _removeStore(context, ref, store),
                                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                    tooltip: 'Remove store partner',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _editStore(BuildContext context, WidgetRef ref, [AdminStore? current]) async {
    final name = TextEditingController(text: current?.name);
    final description = TextEditingController(text: current?.description);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: Color(0xFFFF6B24), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                current == null ? 'Add Store Partner' : 'Edit Store Details',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  hintText: 'e.g. Mang Inasal - Davao Downtown',
                  prefixIcon: Icon(Icons.business_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Store Description',
                  hintText: 'e.g. Authentic charcoal grilled chicken and Filipino favorites.',
                  prefixIcon: Icon(Icons.description_outlined, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await ref.read(adminProvider.notifier).saveStore(AdminStore(
                    id: current?.id ?? 'new-store-${DateTime.now().millisecondsSinceEpoch}',
                    name: name.text.trim(),
                    description: description.text.trim(),
                    available: current?.available ?? true,
                    items: current?.items ?? const [],
                  ));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Save Store'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
  }

  Future<void> _editMenuItem(BuildContext context, WidgetRef ref, AdminStore store, [AdminMenuItem? current]) async {
    final name = TextEditingController(text: current?.name);
    String selectedCategory = current?.category ?? 'Chicken & Inasal';
    final price = TextEditingController(text: current != null ? current.price.toStringAsFixed(0) : '');
    bool isAvailable = current?.available ?? true;

    final predefinedCategories = [
      'Chicken & Inasal',
      'Silog Meals',
      'Grilled & BBQ',
      'Noodles & Pancit',
      'Seafood',
      'Desserts & Snacks',
      'Beverages & Milk Tea',
      'Sides & Extras',
    ];

    if (!predefinedCategories.contains(selectedCategory)) {
      predefinedCategories.add(selectedCategory);
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFFF6B24), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  current == null ? 'Add Menu Dish' : 'Edit Menu Dish',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Dish Name',
                    hintText: 'e.g. Chicken Inasal Pecho Large',
                    prefixIcon: Icon(Icons.fastfood_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Food Category',
                    prefixIcon: Icon(Icons.category_rounded, size: 20),
                  ),
                  items: predefinedCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price in Philippine Peso (PHP)',
                    prefixText: '₱ ',
                    hintText: '185',
                    prefixIcon: Icon(Icons.payments_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available for Ordering', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(isAvailable ? 'Customers can order this dish now' : 'Marked as Sold Out', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    value: isAvailable,
                    onChanged: (val) => setState(() => isAvailable = val),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () async {
                final amount = double.tryParse(price.text);
                if (name.text.trim().isEmpty || amount == null) return;
                await ref.read(adminProvider.notifier).saveMenuItem(
                      store.id,
                      AdminMenuItem(
                        id: current?.id ?? 'new-item-${DateTime.now().millisecondsSinceEpoch}',
                        name: name.text.trim(),
                        category: selectedCategory,
                        price: amount,
                        available: isAvailable,
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save Dish'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    price.dispose();
  }

  Future<void> _removeStore(BuildContext context, WidgetRef ref, AdminStore store) async {
    final reason = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Remove Store "${store.name}"?',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Removing a store partner requires a mandatory audit reason per system compliance rules.',
                        style: TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Required Audit Reason',
                  hintText: 'e.g. Merchant contract concluded / relocation',
                  prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              if (reason.text.trim().isEmpty) return;
              await ref.read(adminProvider.notifier).removeStore(store, reason.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Confirm Remove'),
          ),
        ],
      ),
    );
    reason.dispose();
  }
}

Future<void> showAssignRiderDialog(BuildContext context, WidgetRef ref, AdminSnapshot data, AdminOrder order) async {
  final available = data.riders.where((rider) => rider.status == AdminRiderStatus.available).toList();
  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No riders are currently available.')));
    return;
  }
  AdminRider selected = available.first;
  final reason = TextEditingController(text: 'Nearest available rider');
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFFF6B24), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Assign Rider to Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AdminRider>(
                initialValue: selected,
                items: available
                    .map((rider) => DropdownMenuItem(
                          value: rider,
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(0xFF10B981),
                                child: Icon(Icons.check, size: 12, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Text('${rider.name} • ${rider.phone}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selected = value!),
                decoration: const InputDecoration(
                  labelText: 'Select Active Rider',
                  prefixIcon: Icon(Icons.person_pin_circle_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Audit Reason',
                  hintText: 'e.g. Nearest active rider in Poblacion',
                  prefixIcon: Icon(Icons.verified_user_outlined, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              try {
                await ref.read(adminProvider.notifier).assign(order.id, selected, reason.text.trim());
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id} assigned to ${selected.name}!'),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg.contains('409') || msg.contains('active') ? '${selected.name} already has an active delivery in Kabacan.' : msg),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Confirm Assignment'),
          ),
        ],
      ),
    ),
  );
  reason.dispose();
}

Future<void> showCancelOrderDialog(BuildContext context, WidgetRef ref, AdminOrder order) async {
  final reason = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cancel Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}?',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'An audit reason is strictly required before cancelling an order.',
                      style: TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'e.g. Customer unreachable upon delivery attempt',
                prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Order')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: () async {
            if (reason.text.trim().isEmpty) return;
            await ref.read(adminProvider.notifier).cancel(order.id, reason.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Confirm Cancel'),
        ),
      ],
    ),
  );
  reason.dispose();
}

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key, required this.data});
  final AdminSnapshot data;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _searchController = TextEditingController();
  AdminOrderStatus? _statusFilter;
  bool? _codFilter; // null = all, true = paid, false = unpaid
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<AdminOrder> orders) {
    final csv = [
      'order_id,customer,store,status,cod_paid,total_php,created_at,assigned_rider',
      ...orders.map((o) =>
          '${o.id},"${o.customer}","${o.store}",${o.status.name},${o.codPaid ? "paid" : "unpaid"},${o.total},${o.createdAt.toIso8601String()},"${o.rider ?? ""}"')
    ].join('\n');
    downloadCsv('mns-orders-${DateTime.now().millisecondsSinceEpoch}.csv', csv);
  }

  void _showOrderDetailsModal(BuildContext context, AdminOrder order) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                  Text(DateFormat('MMM d, yyyy · h:mm a').format(order.createdAt),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status & Settlement Row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ORDER STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        _buildOrderStatusBadge(order.status),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('COD SETTLEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: order.codPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: order.codPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            order.codPaid ? '✓ Cash Collected' : '⏳ Awaiting Collection',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: order.codPaid ? const Color(0xFF065F46) : const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Customer & Store Info
              _buildDetailInfoTile(Icons.person_outline_rounded, 'Customer', order.customer),
              const SizedBox(height: 10),
              _buildDetailInfoTile(Icons.storefront_rounded, 'Store Partner', order.store),
              const SizedBox(height: 10),
              _buildDetailInfoTile(
                Icons.two_wheeler_rounded,
                'Assigned Rider',
                order.rider?.isNotEmpty == true ? order.rider! : 'Unassigned (Awaiting dispatch)',
                isPending: order.rider?.isNotEmpty != true,
              ),
              const SizedBox(height: 16),

              // Total COD Amount Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Cash On Delivery (COD)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E142F))),
                    Text(currency.format(order.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF7C3AED))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          if (order.status == AdminOrderStatus.pending)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              onPressed: () {
                Navigator.pop(ctx);
                showAssignRiderDialog(context, ref, widget.data, order);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Assign Rider Now'),
            ),
          if (order.status != AdminOrderStatus.delivered && order.status != AdminOrderStatus.cancelled)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFFCA5A5))),
              onPressed: () {
                Navigator.pop(ctx);
                showCancelOrderDialog(context, ref, order);
              },
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel Order'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailInfoTile(IconData icon, String label, String value, {bool isPending = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isPending ? const Color(0xFFB45309) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildOrderStatusBadge(AdminOrderStatus status) {
    final (bg, fg, border) = switch (status) {
      AdminOrderStatus.pending => (const Color(0xFFFFFBEB), const Color(0xFFB45309), const Color(0xFFFDE68A)),
      AdminOrderStatus.confirmed => (const Color(0xFFF0F9FF), const Color(0xFF0284C7), const Color(0xFFBAE6FD)),
      AdminOrderStatus.assigned => (const Color(0xFFEEF2FF), const Color(0xFF4F46E5), const Color(0xFFC7D2FE)),
      AdminOrderStatus.pickedUp => (const Color(0xFFFAF5FF), const Color(0xFF7C3AED), const Color(0xFFE9D5FF)),
      AdminOrderStatus.onTheWay => (const Color(0xFFEFF6FF), const Color(0xFF2563EB), const Color(0xFFBFDBFE)),
      AdminOrderStatus.delivered => (const Color(0xFFECFDF5), const Color(0xFF047857), const Color(0xFFA7F3D0)),
      AdminOrderStatus.cancelled => (const Color(0xFFFEF2F2), const Color(0xFFDC2626), const Color(0xFFFECACA)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    // Filter Logic
    final filtered = widget.data.orders.where((order) {
      if (_statusFilter != null && order.status != _statusFilter) return false;
      if (_codFilter != null && order.codPaid != _codFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchId = order.id.toLowerCase().contains(q);
        final matchCustomer = order.customer.toLowerCase().contains(q);
        final matchStore = order.store.toLowerCase().contains(q);
        final matchRider = order.rider?.toLowerCase().contains(q) ?? false;
        if (!matchId && !matchCustomer && !matchStore && !matchRider) return false;
      }
      return true;
    }).toList();

    // Summary Metrics
    final totalOrders = widget.data.orders.length;
    final pendingOrders = widget.data.orders.where((o) => o.status == AdminOrderStatus.pending).length;
    final inTransit = widget.data.orders.where((o) => o.status == AdminOrderStatus.onTheWay || o.status == AdminOrderStatus.pickedUp).length;
    final totalCodSettled = widget.data.orders.where((o) => o.codPaid).fold<double>(0, (sum, o) => sum + o.total);
    final totalCodUnpaid = widget.data.orders.where((o) => !o.codPaid && o.status != AdminOrderStatus.cancelled).fold<double>(0, (sum, o) => sum + o.total);

    return _Page(
      title: 'Orders Management',
      subtitle: 'Dispatch live customer orders, assign courier fleet, track COD settlement, and audit order lifecycles.',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () => _exportCsv(filtered),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 Top KPI Cards for Orders
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Kpi(
                label: 'Total Orders',
                value: '$totalOrders',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF7C3AED),
                subtext: '${widget.data.orders.where((o) => o.status == AdminOrderStatus.delivered).length} delivered successfully',
              ),
              _Kpi(
                label: 'Pending Assignment',
                value: '$pendingOrders',
                icon: Icons.pending_actions_rounded,
                color: pendingOrders > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                subtext: pendingOrders > 0 ? 'Requires rider dispatch' : 'All incoming orders assigned',
              ),
              _Kpi(
                label: 'In Transit Fleet',
                value: '$inTransit',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFF2563EB),
                subtext: 'Couriers delivering across Kabacan',
              ),
              _Kpi(
                label: 'Settled COD Sales',
                value: currency.format(totalCodSettled),
                icon: Icons.payments_rounded,
                color: const Color(0xFF10B981),
                subtext: 'Outstanding: ${currency.format(totalCodUnpaid)} unpaid COD',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search Bar Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input & Payment Filter Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _query = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search by Order ID, Customer, Store, or Rider...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // COD Settlement Filter
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: SizedBox(
                          width: 180,
                          child: DropdownButton<bool?>(
                            value: _codFilter,
                            isExpanded: true,
                            hint: const Text('COD Settlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All COD Statuses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                              DropdownMenuItem(value: true, child: Text('Paid COD Only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF047857)))),
                              DropdownMenuItem(value: false, child: Text('Unpaid COD Only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB45309)))),
                            ],
                            onChanged: (val) => setState(() => _codFilter = val),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // "All" Chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text('All (${widget.data.orders.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _statusFilter == null ? FontWeight.w800 : FontWeight.w600,
                                color: _statusFilter == null ? Colors.white : const Color(0xFF475569),
                              )),
                          selected: _statusFilter == null,
                          selectedColor: const Color(0xFF7C3AED),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: BorderSide(color: _statusFilter == null ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          onSelected: (_) => setState(() => _statusFilter = null),
                        ),
                      ),
                      // Specific status chips
                      ...AdminOrderStatus.values.map((status) {
                        final isSelected = _statusFilter == status;
                        final count = widget.data.orders.where((o) => o.status == status).length;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text('${status.label} ($count)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                )),
                            selected: isSelected,
                            selectedColor: const Color(0xFF7C3AED),
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: BorderSide(color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            onSelected: (_) => setState(() => _statusFilter = isSelected ? null : status),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Orders Data Table Section
          _Section(
            title: 'Order Dispatch Records',
            badge: '${filtered.length} of $totalOrders Showing',
            child: filtered.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3E8FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF7C3AED)),
                        ),
                        const SizedBox(height: 14),
                        const Text('No orders match your filter criteria', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        const Text('Try clearing your search query or selecting a different status chip.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          horizontalMargin: 20,
                          columnSpacing: 28,
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF334155), fontSize: 13),
                          columns: const [
                            DataColumn(label: Text('Order ID')),
                            DataColumn(label: Text('Created At')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Store Partner')),
                            DataColumn(label: Text('Assigned Courier')),
                            DataColumn(label: Text('Order Status')),
                            DataColumn(label: Text('COD Settlement')),
                            DataColumn(label: Text('Total (₱)')),
                            DataColumn(label: Text('Dispatch Actions')),
                          ],
                          rows: filtered.map((order) {
                            final shortId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;

                            return DataRow(
                              cells: [
                                // Order ID
                                DataCell(
                                  InkWell(
                                    onTap: () => _showOrderDetailsModal(context, order),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#$shortId',
                                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                ),
                                // Created At
                                DataCell(Text(
                                  DateFormat('MMM d · h:mm a').format(order.createdAt),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                )),
                                // Customer
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: const Color(0xFFF3E8FF),
                                      child: Text(
                                        order.customer.isNotEmpty ? order.customer[0].toUpperCase() : 'C',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 140),
                                      child: Text(
                                        order.customer,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ],
                                )),
                                // Store Partner
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 160),
                                      child: Text(
                                        order.store,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                )),
                                // Assigned Courier
                                DataCell(
                                  order.rider?.isNotEmpty == true
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF10B981)),
                                            const SizedBox(width: 6),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 140),
                                              child: Text(
                                                order.rider!,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF047857)),
                                              ),
                                            ),
                                          ],
                                        )
                                      : InkWell(
                                          onTap: () => showAssignRiderDialog(context, ref, widget.data, order),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_rounded, size: 14, color: Color(0xFFB45309)),
                                                SizedBox(width: 4),
                                                Text('Assign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                // Order Status
                                DataCell(_buildOrderStatusBadge(order.status)),
                                // COD Settlement
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: order.codPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: order.codPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                                    ),
                                    child: Text(
                                      order.codPaid ? '✓ Paid' : '⏳ Unpaid',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: order.codPaid ? const Color(0xFF047857) : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ),
                                // Total Amount
                                DataCell(Text(
                                  currency.format(order.total),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                                )),
                                // Actions
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Inspect Details
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                                        tooltip: 'Inspect Order',
                                        onPressed: () => _showOrderDetailsModal(context, order),
                                      ),
                                      // Assign Rider
                                      if (order.status == AdminOrderStatus.pending) ...[
                                        const SizedBox(width: 4),
                                        IconButton.filled(
                                          style: IconButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                                          onPressed: () => showAssignRiderDialog(context, ref, widget.data, order),
                                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                                          tooltip: 'Assign Courier',
                                        ),
                                      ],
                                      // Cancel
                                      if (order.status != AdminOrderStatus.delivered && order.status != AdminOrderStatus.cancelled) ...[
                                        const SizedBox(width: 4),
                                        IconButton.outlined(
                                          style: IconButton.styleFrom(side: const BorderSide(color: Color(0xFFFECACA))),
                                          onPressed: () => showCancelOrderDialog(context, ref, order),
                                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                                          tooltip: 'Cancel Order',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class RidersPage extends ConsumerWidget {
  const RidersPage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Page(
        title: 'Rider Team & Fleet',
        subtitle: 'Manage rider accounts, dispatch availability, and active live assignments.',
        actions: [
          FilledButton.icon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Add New Rider'),
          ),
        ],
        child: _Section(
          title: 'Active Fleet Directory',
          badge: '${data.riders.length} Registered',
          child: Column(
            children: data.riders
                .map((rider) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFFF6B24).withValues(alpha: 0.15),
                            child: Text(
                              rider.name.isEmpty ? '?' : rider.name.substring(0, 1),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF6B24)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rider.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text('${rider.phone}${rider.activeDelivery == null ? '' : ' · Order ${rider.activeDelivery}'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                          ),
                          _Chip(rider.status.name.toUpperCase()),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      );

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFFF6B24), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Register Delivery Rider',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Rider Full Name',
                  hintText: 'e.g. Juan Dela Cruz',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'rider@mns.ph',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Philippine Mobile Number',
                  hintText: '+63 917 123 4567',
                  prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Initial Account Password',
                  hintText: 'Minimum 8 characters',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              if (name.text.trim().isEmpty || !email.text.contains('@') || password.text.length < 8) return;
              await ref.read(adminProvider.notifier).saveRider(
                    name: name.text.trim(),
                    email: email.text.trim(),
                    password: password.text,
                    phone: phone.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Create Rider Account'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
  }
}

class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key, required this.data});
  final AdminSnapshot data;

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  Timer? _telemetryTimer;
  String? _selectedDeliveryId;
  bool _isDrawerOpen = true;
  String _searchQuery = '';
  AdminOrderStatus? _statusFilter;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Auto-refresh rider locations every 3 seconds
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollTelemetry());
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pollTelemetry() async {
    if (!mounted) return;
    try {
      await ref.read(adminProvider.notifier).refreshDeliveries();
    } catch (_) {}
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    await _pollTelemetry();
    if (mounted) setState(() => _isSyncing = false);
  }

  void _flyTo(double lat, double lng) {
    if (lat == 0 && lng == 0) return;
    _mapController.move(LatLng(lat, lng), 15.0);
  }

  void _fitAllRiders(List<LiveDelivery> deliveries) {
    final valid = deliveries.where((d) => d.latitude != 0 && d.longitude != 0).toList();
    if (valid.isEmpty) {
      _mapController.move(const LatLng(7.0731, 125.6128), 13.0);
      return;
    }
    if (valid.length == 1) {
      _mapController.move(LatLng(valid.first.latitude, valid.first.longitude), 14.5);
      return;
    }
    double minLat = valid.first.latitude;
    double maxLat = valid.first.latitude;
    double minLng = valid.first.longitude;
    double maxLng = valid.first.longitude;
    for (final d in valid) {
      if (d.latitude < minLat) minLat = d.latitude;
      if (d.latitude > maxLat) maxLat = d.latitude;
      if (d.longitude < minLng) minLng = d.longitude;
      if (d.longitude > maxLng) maxLng = d.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 12.5);
  }

  @override
  Widget build(BuildContext context) {
    final currentSnapshot = ref.watch(adminProvider).snapshot ?? widget.data;
    final allDeliveries = currentSnapshot.deliveries;
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

    final filteredDeliveries = allDeliveries.where((d) {
      if (_statusFilter != null && d.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchRider = d.rider.toLowerCase().contains(query);
        final matchOrder = d.orderId.toLowerCase().contains(query);
        final matchCustomer = d.customer.toLowerCase().contains(query);
        if (!matchRider && !matchOrder && !matchCustomer) return false;
      }
      return true;
    }).toList();

    final positioned = filteredDeliveries.where((d) => d.latitude != 0 || d.longitude != 0).toList();
    final center = positioned.isNotEmpty
        ? LatLng(positioned.first.latitude, positioned.first.longitude)
        : const LatLng(7.0731, 125.6128);

    final selectedDelivery = _selectedDeliveryId == null
        ? null
        : allDeliveries.cast<LiveDelivery?>().firstWhere((d) => d?.id == _selectedDeliveryId, orElse: () => null);

    return SizedBox.expand(
      child: Stack(
        children: [
          // 1. Full-Screen Interactive Map Canvas
          Positioned.fill(
            child: mapboxToken.isEmpty
                ? CustomPaint(painter: _AdminMapPainter())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: positioned.map((delivery) {
                          final isSelected = delivery.id == _selectedDeliveryId;
                          final isStale = delivery.stale;
                          final markerColor = isStale
                              ? const Color(0xFFEF4444)
                              : (isSelected ? const Color(0xFFFF6B24) : const Color(0xFF10B981));

                          return Marker(
                            point: LatLng(delivery.latitude, delivery.longitude),
                            width: 140,
                            height: 72,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedDeliveryId = delivery.id);
                                _flyTo(delivery.latitude, delivery.longitude);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Live Rider Avatar Pin
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: markerColor.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                      border: Border.all(color: markerColor, width: 2.5),
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: markerColor,
                                      child: const Icon(
                                        Icons.delivery_dining_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  // Callout Badge Label
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: Text(
                                      delivery.rider,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),

          // 2. Top Floating Navigation & Telemetry HUD Bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Realtime Radar Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing green beacon dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'LIVE GPS DISPATCH RADAR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${positioned.length} Active Riders · Real-time auto sync',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Map & Dispatch Control Actions
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fit All Riders Action
                      IconButton(
                        tooltip: 'Fit All Riders on Screen',
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 20, color: Color(0xFF0F172A)),
                        onPressed: () => _fitAllRiders(allDeliveries),
                      ),
                      const SizedBox(width: 4),
                      // Manual Sync
                      IconButton(
                        tooltip: 'Sync GPS Telemetry Now',
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B24)),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF0F172A)),
                        onPressed: _isSyncing ? null : _manualSync,
                      ),
                      const SizedBox(width: 4),
                      // Toggle Dispatch Roster Drawer
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
                        icon: Icon(_isDrawerOpen ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined, size: 18),
                        label: Text(_isDrawerOpen ? 'Hide Fleet Roster' : 'Show Fleet Roster (${filteredDeliveries.length})'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Left Fleet Roster Overlay Drawer
          if (_isDrawerOpen)
            Positioned(
              top: 88,
              left: 20,
              bottom: 20,
              width: 360,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drawer Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Active Deliveries',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${filteredDeliveries.length}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFFF6B24)),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => setState(() => _isDrawerOpen = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Input Box
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search rider, order, or customer...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips (All, On The Way, Picked Up)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            showCheckmark: false,
                            label: const Text('All'),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: _statusFilter == null ? FontWeight.w800 : FontWeight.w600,
                              color: _statusFilter == null ? Colors.white : const Color(0xFF475569),
                            ),
                            selected: _statusFilter == null,
                            selectedColor: const Color(0xFF7C3AED),
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: BorderSide(color: _statusFilter == null ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            onSelected: (_) => setState(() => _statusFilter = null),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            showCheckmark: false,
                            label: const Text('On The Way'),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: _statusFilter == AdminOrderStatus.onTheWay ? FontWeight.w800 : FontWeight.w600,
                              color: _statusFilter == AdminOrderStatus.onTheWay ? Colors.white : const Color(0xFF475569),
                            ),
                            selected: _statusFilter == AdminOrderStatus.onTheWay,
                            selectedColor: const Color(0xFF7C3AED),
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: BorderSide(color: _statusFilter == AdminOrderStatus.onTheWay ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            onSelected: (sel) => setState(() => _statusFilter = sel ? AdminOrderStatus.onTheWay : null),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            showCheckmark: false,
                            label: const Text('Picked Up'),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: _statusFilter == AdminOrderStatus.pickedUp ? FontWeight.w800 : FontWeight.w600,
                              color: _statusFilter == AdminOrderStatus.pickedUp ? Colors.white : const Color(0xFF475569),
                            ),
                            selected: _statusFilter == AdminOrderStatus.pickedUp,
                            selectedColor: const Color(0xFF7C3AED),
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: BorderSide(color: _statusFilter == AdminOrderStatus.pickedUp ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            onSelected: (sel) => setState(() => _statusFilter = sel ? AdminOrderStatus.pickedUp : null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    // Delivery List
                    Expanded(
                      child: filteredDeliveries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_off_rounded, size: 36, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text('No deliveries match filter', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredDeliveries.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final delivery = filteredDeliveries[index];
                                final isSelected = delivery.id == _selectedDeliveryId;
                                final isStale = delivery.stale;
                                final pingAgeSec = DateTime.now().difference(delivery.updatedAt).inSeconds;

                                return Material(
                                  color: isSelected
                                      ? const Color(0xFFFF6B24).withValues(alpha: 0.1)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      setState(() => _selectedDeliveryId = delivery.id);
                                      _flyTo(delivery.latitude, delivery.longitude);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFFF6B24)
                                              : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: (isStale
                                                        ? const Color(0xFFEF4444)
                                                        : const Color(0xFF10B981))
                                                    .withValues(alpha: 0.15),
                                                child: Icon(
                                                  isStale ? Icons.location_off_rounded : Icons.my_location_rounded,
                                                  color: isStale ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                  size: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  delivery.rider,
                                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                                ),
                                              ),
                                              _Chip(delivery.status.label),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'To: ${delivery.customer}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Order ${delivery.orderId.length > 10 ? delivery.orderId.substring(0, 10) : delivery.orderId}',
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                                              ),
                                              Text(
                                                isStale
                                                    ? 'Stale (${DateFormat('h:mm a').format(delivery.updatedAt)})'
                                                    : 'Ping: ${pingAgeSec}s ago',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isStale ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Selected Rider Details Modal Card (Bottom Center)
          if (selectedDelivery != null)
            Positioned(
              bottom: 24,
              left: _isDrawerOpen ? 400 : 24,
              right: 100,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 580),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFFF6B24),
                        child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  selectedDelivery.rider,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B24).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    selectedDelivery.status.label,
                                    style: const TextStyle(color: Color(0xFFFF6B24), fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Delivering to ${selectedDelivery.customer} · Order ${selectedDelivery.orderId}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'GPS: ${selectedDelivery.latitude.toStringAsFixed(4)}, ${selectedDelivery.longitude.toStringAsFixed(4)} · Pinged ${DateFormat('h:mm:ss a').format(selectedDelivery.updatedAt)}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Close details',
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => setState(() => _selectedDeliveryId = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Floating Zoom & Orientation Controls (Bottom Right)
          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom In',
                    icon: const Icon(Icons.add_rounded, color: Color(0xFF0F172A)),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom + 1);
                    },
                  ),
                  const Divider(height: 1, indent: 6, endIndent: 6, color: Color(0xFFE2E8F0)),
                  IconButton(
                    tooltip: 'Zoom Out',
                    icon: const Icon(Icons.remove_rounded, color: Color(0xFF0F172A)),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom - 1);
                    },
                  ),
                  const Divider(height: 1, indent: 6, endIndent: 6, color: Color(0xFFE2E8F0)),
                  IconButton(
                    tooltip: 'Center on Davao Operations Hub',
                    icon: const Icon(Icons.my_location_rounded, color: Color(0xFFFF6B24)),
                    onPressed: () => _mapController.move(const LatLng(7.0731, 125.6128), 13.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  AdminOrderStatus? status;
  @override
  Widget build(BuildContext context) {
    final orders = widget.data.orders.where((order) => status == null || order.status == status).toList();
    final csv = ['order,customer,store,status,cod,total,created_at', ...orders.map((order) => '${order.id},${order.customer},${order.store},${order.status.name},${order.codPaid ? 'paid' : 'unpaid'},${order.total},${order.createdAt.toIso8601String()}')].join('\n');
    return _Page(
      title: 'Reports & Export Center',
      subtitle: 'Filter delivery logs, export audit-compliant CSV spreadsheets, or print official summaries.',
      actions: [
        OutlinedButton.icon(onPressed: () => downloadCsv('mns-orders.csv', csv), icon: const Icon(Icons.download_rounded), label: const Text('Export CSV')),
        const SizedBox(width: 10),
        FilledButton.icon(onPressed: printReport, icon: const Icon(Icons.print_rounded), label: const Text('Print Summary')),
      ],
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 280,
              child: DropdownButtonFormField<AdminOrderStatus?>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Filter by Order Status'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Statuses (Combined)')),
                  ...AdminOrderStatus.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))),
                ],
                onChanged: (value) => setState(() => status = value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Filtered Order Log',
            badge: '${orders.length} Records',
            child: Column(
              children: orders
                  .map((order) => ListTile(
                        title: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'monospace')),
                        subtitle: Text('${order.store} · ${DateFormat('MMM d, h:mm a').format(order.createdAt)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        trailing: Text('₱${order.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Customer Feedback & Ratings',
            badge: '${widget.data.feedback.length} Reviews',
            child: Column(
              children: widget.data.feedback
                  .map((entry) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFEF3C7),
                          child: Text('${entry.rating}★', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFB45309), fontSize: 12)),
                        ),
                        title: Text('${entry.customer} (Order ${entry.orderId.length > 10 ? entry.orderId.substring(0, 10) : entry.orderId})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        subtitle: Text(entry.comment.isNotEmpty ? '“${entry.comment}”' : 'No written feedback', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                        trailing: Text(DateFormat('MMM d').format(entry.createdAt), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Full Audit Trail Log',
            badge: '${widget.data.audit.length} Logged',
            child: Column(
              children: widget.data.audit
                  .map((entry) => ListTile(
                        leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF64748B)),
                        title: Text('${entry.action} · ${entry.target}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        subtitle: Text('${entry.actor} — ${entry.reason}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        trailing: Text(DateFormat('MMM d, h:mm a').format(entry.createdAt), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtext,
    this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtext;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 275,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.5,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.badge,
  });

  final String title;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF6B24),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B24).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF6B24).withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFFF6B24)),
        ),
      );
}

class _AdminMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(0, size.height * i / 6), Offset(size.width, size.height * i / 6), paint);
    }
    for (var i = 1; i < 7; i++) {
      canvas.drawLine(Offset(size.width * i / 7, 0), Offset(size.width * i / 7, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
