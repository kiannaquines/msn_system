import 'dart:async';
import 'dart:math' as math;
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
import '../util/road_route_service.dart';
import 'package:mns_design_system/design_system.dart';

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
                color: const Color(0xFF059669),
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706), size: 22),
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
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(0, 32),
                                          backgroundColor: const Color(0xFF7C3AED),
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
                color: const Color(0xFF7C3AED),
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
                                    ? const Color(0xFFF3E8FF).withValues(alpha: 0.3)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Store Icon Avatar / Image
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: store.available ? const Color(0xFFF3E8FF) : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                                        ? Image.network(
                                            store.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                store.name.isEmpty ? 'S' : store.name.substring(0, 1).toUpperCase(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                  color: store.available ? const Color(0xFF7C3AED) : Colors.black45,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              store.name.isEmpty ? 'S' : store.name.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                                color: store.available ? const Color(0xFF7C3AED) : Colors.black45,
                                              ),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: item.available ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              // Dish Thumbnail Image
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                                    ? Image.network(
                                                        item.imageUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => const Center(
                                                          child: Icon(Icons.restaurant_rounded, size: 18, color: Color(0xFF7C3AED)),
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: Icon(Icons.restaurant_rounded, size: 18, color: Color(0xFF7C3AED)),
                                                      ),
                                              ),
                                              const SizedBox(width: 10),
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
    final imageUrl = TextEditingController(text: current?.imageUrl);
    bool isAvailable = current?.available ?? true;

    final storePresets = [
      const _ImagePreset(
        label: 'Grill & BBQ',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        icon: Icons.local_fire_department_rounded,
      ),
      const _ImagePreset(
        label: 'Fast Food',
        url: 'https://images.unsplash.com/photo-1586816001966-79b736744398?w=600&auto=format&fit=crop&q=80',
        icon: Icons.fastfood_rounded,
      ),
      const _ImagePreset(
        label: 'Asian & Wok',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        icon: Icons.ramen_dining_rounded,
      ),
      const _ImagePreset(
        label: 'Cafe & Bakery',
        url: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600&auto=format&fit=crop&q=80',
        icon: Icons.coffee_rounded,
      ),
      const _ImagePreset(
        label: 'Milk Tea & Drinks',
        url: 'https://images.unsplash.com/photo-1558857563-b37cf5a26a8d?w=600&auto=format&fit=crop&q=80',
        icon: Icons.bubble_chart_rounded,
      ),
      const _ImagePreset(
        label: 'Seafood Bistro',
        url: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&auto=format&fit=crop&q=80',
        icon: Icons.set_meal_rounded,
      ),
    ];

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF7C3AED), size: 22),
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
            width: 500,
            child: SingleChildScrollView(
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
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Store Description',
                      hintText: 'e.g. Authentic charcoal grilled chicken and Filipino favorites.',
                      prefixIcon: Icon(Icons.description_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ImageUploadPickerField(
                    controller: imageUrl,
                    label: 'Store Cover / Logo Image',
                    presets: storePresets,
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
                      title: const Text('Store Open & Accepting Orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text(
                        isAvailable ? 'Store is open and accepting new customer orders' : 'Store is closed / temporarily offline',
                        style: TextStyle(fontSize: 11, color: isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      value: isAvailable,
                      activeThumbColor: const Color(0xFF10B981),
                      activeTrackColor: const Color(0xFFA7F3D0),
                      onChanged: (val) => setState(() => isAvailable = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final image = imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim();
                await ref.read(adminProvider.notifier).saveStore(AdminStore(
                      id: current?.id ?? 'new-store-${DateTime.now().millisecondsSinceEpoch}',
                      name: name.text.trim(),
                      description: description.text.trim(),
                      imageUrl: image,
                      available: isAvailable,
                      items: current?.items ?? const [],
                    ));
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save Store'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    imageUrl.dispose();
  }

  Future<void> _editMenuItem(BuildContext context, WidgetRef ref, AdminStore store, [AdminMenuItem? current]) async {
    final name = TextEditingController(text: current?.name);
    String selectedCategory = current?.category ?? 'Chicken & Inasal';
    final price = TextEditingController(text: current != null ? current.price.toStringAsFixed(0) : '');
    final imageUrl = TextEditingController(text: current?.imageUrl);
    bool isAvailable = current?.available ?? true;

    final dishPresets = [
      const _ImagePreset(
        label: 'Chicken Inasal',
        url: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=600&auto=format&fit=crop&q=80',
        icon: Icons.restaurant_rounded,
      ),
      const _ImagePreset(
        label: 'Crispy Pata',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        icon: Icons.dinner_dining_rounded,
      ),
      const _ImagePreset(
        label: 'Pork BBQ',
        url: 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=600&auto=format&fit=crop&q=80',
        icon: Icons.kebab_dining_rounded,
      ),
      const _ImagePreset(
        label: 'Sinigang / Soup',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
        icon: Icons.soup_kitchen_rounded,
      ),
      const _ImagePreset(
        label: 'Silog Breakfast',
        url: 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=600&auto=format&fit=crop&q=80',
        icon: Icons.egg_alt_rounded,
      ),
      const _ImagePreset(
        label: 'Pancit Canton',
        url: 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=600&auto=format&fit=crop&q=80',
        icon: Icons.ramen_dining_rounded,
      ),
      const _ImagePreset(
        label: 'Halo-Halo / Dessert',
        url: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&auto=format&fit=crop&q=80',
        icon: Icons.icecream_rounded,
      ),
      const _ImagePreset(
        label: 'Milk Tea & Drink',
        url: 'https://images.unsplash.com/photo-1558857563-b37cf5a26a8d?w=600&auto=format&fit=crop&q=80',
        icon: Icons.local_drink_rounded,
      ),
    ];

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
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF7C3AED), size: 22),
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
            width: 500,
            child: SingleChildScrollView(
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
                  _ImageUploadPickerField(
                    controller: imageUrl,
                    label: 'Dish Photography Image',
                    presets: dishPresets,
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () async {
                final amount = double.tryParse(price.text);
                if (name.text.trim().isEmpty || amount == null) return;
                final image = imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim();
                await ref.read(adminProvider.notifier).saveMenuItem(
                      store.id,
                      AdminMenuItem(
                        id: current?.id ?? 'new-item-${DateTime.now().millisecondsSinceEpoch}',
                        name: name.text.trim(),
                        category: selectedCategory,
                        price: amount,
                        imageUrl: image,
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
    imageUrl.dispose();
  }

  Future<void> _removeStore(BuildContext context, WidgetRef ref, AdminStore store) async {
    final reason = TextEditingController(text: 'Store partnership terminated / closed');
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
                        'Removing this store will deactivate it, remove it from customer catalogs, and record an audit entry.',
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
              final auditReason = reason.text.trim().isNotEmpty ? reason.text.trim() : 'Store partnership terminated / closed';
              Navigator.pop(context);
              await ref.read(adminProvider.notifier).removeStore(store, auditReason);
              if (context.mounted) {
                MnsSnackBar.show(
                  context,
                  title: 'Store Removed',
                  message: 'Store "${store.name}" was removed from the active catalog.',
                  type: MnsSnackBarType.info,
                );
              }
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
    MnsSnackBar.show(context, message: 'No riders are currently available.', type: MnsSnackBarType.warning);
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
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF7C3AED), size: 22),
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
                  MnsSnackBar.show(
                    context,
                    title: 'Rider Assigned',
                    message: 'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id} assigned to ${selected.name}!',
                    type: MnsSnackBarType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
                  MnsSnackBar.show(
                    context,
                    title: 'Assignment Failed',
                    message: msg.contains('409') || msg.contains('active') ? '${selected.name} already has an active delivery in progress.' : msg,
                    type: MnsSnackBarType.error,
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
                subtext: 'Couriers delivering across active zones',
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
                                // Assigned Courier (Rider)
                                DataCell(
                                  order.rider?.isNotEmpty == true
                                      ? InkWell(
                                          onTap: () => showAssignRiderDialog(context, ref, widget.data, order),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor: const Color(0xFF10B981),
                                                  child: Text(
                                                    order.rider![0].toUpperCase(),
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 140),
                                                  child: Text(
                                                    order.rider!,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF065F46)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : InkWell(
                                          onTap: () => showAssignRiderDialog(context, ref, widget.data, order),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person_add_alt_1_rounded, size: 14, color: Color(0xFFB45309)),
                                                SizedBox(width: 5),
                                                Text('Assign Courier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
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
        title: 'Rider Team & Fleet Management',
        subtitle: 'Manage courier accounts, vehicle transport assignments, document verifications, and real-time dispatch availability.',
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add New Rider', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        child: _Section(
          title: 'Active Fleet Directory',
          badge: '${data.riders.length} Registered Couriers',
          child: Column(
            children: data.riders.map((rider) {
              final isOnline = rider.status == AdminRiderStatus.available;
              final isBusy = rider.status == AdminRiderStatus.busy;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFF3E8FF),
                      child: Text(
                        rider.name.isEmpty ? 'R' : rider.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF7C3AED)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rider.name,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 12, color: Color(0xFF059669)),
                                    SizedBox(width: 3),
                                    Text('Verified Courier', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '📞 ${rider.phone} · 🏍️ Honda Click 125i (DAV-842) · Davao Toril Hub',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          if (rider.activeDelivery != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Active Delivery: #${rider.activeDelivery!.length > 8 ? rider.activeDelivery!.substring(0, 8) : rider.activeDelivery!}',
                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFFECFDF5)
                            : isBusy
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOnline
                              ? const Color(0xFFA7F3D0)
                              : isBusy
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        rider.status.name.toUpperCase(),
                        style: TextStyle(
                          color: isOnline
                              ? const Color(0xFF065F46)
                              : isBusy
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFFE9D5FF)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _edit(context, ref, rider),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CreateRiderDialog(ref: ref),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, AdminRider rider) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EditRiderDialog(ref: ref, rider: rider),
    );
  }
}

class _EditRiderDialog extends StatefulWidget {
  const _EditRiderDialog({required this.ref, required this.rider});
  final WidgetRef ref;
  final AdminRider rider;

  @override
  State<_EditRiderDialog> createState() => _EditRiderDialogState();
}

class _EditRiderDialogState extends State<_EditRiderDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _vehicleModel;
  late final TextEditingController _plateNumber;
  late AdminRiderStatus _status;

  String _vehicleType = 'Motorcycle';
  String _hub = 'Davao Toril Hub';
  String _shiftSlot = 'Morning Shift (6:00 AM - 2:00 PM)';

  // Document states
  String? _licenseFile = 'drivers_license_card.jpg';
  String? _orCrFile = 'vehicle_or_cr_reg.pdf';
  String? _clearanceFile = 'nbi_barangay_clearance.pdf';
  String? _photoIdFile = 'courier_formal_2x2.jpg';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _name = TextEditingController(text: widget.rider.name);
    _phone = TextEditingController(text: widget.rider.phone);
    _vehicleModel = TextEditingController();
    _plateNumber = TextEditingController();
    _status = widget.rider.status;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _name.dispose();
    _phone.dispose();
    _vehicleModel.dispose();
    _plateNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Courier Profile: ${widget.rider.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        const Text('Update driver contact, vehicle transport details, and duty availability.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF7C3AED),
                labelColor: const Color(0xFF7C3AED),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.badge_outlined, size: 18), text: '1. Courier Info'),
                  Tab(icon: Icon(Icons.two_wheeler_rounded, size: 18), text: '2. Vehicle & Status'),
                  Tab(icon: Icon(Icons.cloud_upload_outlined, size: 18), text: '3. Documents'),
                ],
              ),
            ),

            // Tab Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Personal Info
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _name,
                          decoration: InputDecoration(
                            labelText: 'Rider Full Legal Name *',
                            hintText: 'e.g. Arnel Dimaculangan',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Mobile Phone Number *',
                            hintText: '+63 917 555 1234',
                            prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<AdminRiderStatus>(
                          initialValue: _status,
                          decoration: InputDecoration(
                            labelText: 'Real-Time Dispatch Status *',
                            prefixIcon: const Icon(Icons.power_settings_new_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: AdminRiderStatus.available, child: Text('🟢 AVAILABLE (On Duty · Receiving Orders)')),
                            DropdownMenuItem(value: AdminRiderStatus.busy, child: Text('🔵 BUSY (Currently on Live Delivery)')),
                            DropdownMenuItem(value: AdminRiderStatus.offline, child: Text('⚪ OFFLINE (Off Duty)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Vehicle & Hub
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _vehicleType,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle Transport Type',
                                  prefixIcon: const Icon(Icons.commute_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Motorcycle', child: Text('🏍️ Motorcycle (Standard)')),
                                  DropdownMenuItem(value: 'Electric Scooter', child: Text('⚡ Electric Scooter')),
                                  DropdownMenuItem(value: 'Bicycle', child: Text('🚲 Bicycle / Eco-Courier')),
                                  DropdownMenuItem(value: 'Car / Van', child: Text('🚗 Car / Van (Bulk)')),
                                ],
                                onChanged: (val) => setState(() => _vehicleType = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _hub,
                                decoration: InputDecoration(
                                  labelText: 'Assigned Operating Hub',
                                  prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Davao Toril Hub', child: Text('📍 Davao Toril Hub')),
                                  DropdownMenuItem(value: 'Davao Matina Hub', child: Text('📍 Davao Matina Hub')),
                                  DropdownMenuItem(value: 'Davao Bajada Hub', child: Text('📍 Davao Bajada Hub')),
                                  DropdownMenuItem(value: 'Davao City Central Hub', child: Text('📍 Davao City Central Hub')),
                                ],
                                onChanged: (val) => setState(() => _hub = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _vehicleModel,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle Model & Year',
                                  hintText: 'e.g. Honda Click 125i (2024)',
                                  prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _plateNumber,
                                decoration: InputDecoration(
                                  labelText: 'License Plate / MV File No.',
                                  hintText: 'e.g. DAV-842',
                                  prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _shiftSlot,
                          decoration: InputDecoration(
                            labelText: 'Preferred Delivery Shift Slot',
                            prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Morning Shift (6:00 AM - 2:00 PM)', child: Text('🌅 Morning Shift (6:00 AM - 2:00 PM)')),
                            DropdownMenuItem(value: 'Afternoon Shift (2:00 PM - 10:00 PM)', child: Text('☀️ Afternoon Shift (2:00 PM - 10:00 PM)')),
                            DropdownMenuItem(value: 'Night Shift (10:00 PM - 6:00 AM)', child: Text('🌙 Night Shift (10:00 PM - 6:00 AM)')),
                            DropdownMenuItem(value: 'Full Flexibility', child: Text('🔄 Full Flexibility (Any Shift)')),
                          ],
                          onChanged: (val) => setState(() => _shiftSlot = val!),
                        ),
                      ],
                    ),
                  ),

                  // Tab 3: Document Uploads
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Courier Documents & Clearances',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage verified files on record for this rider account.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        _UploadDocumentCard(
                          title: "Professional Driver's License",
                          description: 'Front and back scan with non-expired LTO validity',
                          fileName: _licenseFile,
                          icon: Icons.badge_outlined,
                          onPick: () => setState(() => _licenseFile = 'drivers_license_card_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg'),
                        ),
                        const SizedBox(height: 10),

                        _UploadDocumentCard(
                          title: 'Vehicle OR / CR Registration',
                          description: 'Official Receipt & Certificate of Registration issued by LTO',
                          fileName: _orCrFile,
                          icon: Icons.article_outlined,
                          onPick: () => setState(() => _orCrFile = 'vehicle_or_cr_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.pdf'),
                        ),
                        const SizedBox(height: 10),

                        _UploadDocumentCard(
                          title: 'Barangay / Police Clearance',
                          description: 'Valid background clearance document for Davao City',
                          fileName: _clearanceFile,
                          icon: Icons.shield_outlined,
                          onPick: () => setState(() => _clearanceFile = 'davao_police_clearance_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.pdf'),
                        ),
                        const SizedBox(height: 10),

                        _UploadDocumentCard(
                          title: '2x2 Formal Courier Photo',
                          description: 'Recent white-background formal avatar photo',
                          fileName: _photoIdFile,
                          icon: Icons.account_box_outlined,
                          onPick: () => setState(() => _photoIdFile = 'formal_photo_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
                              MnsSnackBar.show(
                                context,
                                title: 'Required Fields Missing',
                                message: 'Rider name and phone number cannot be empty.',
                                type: MnsSnackBarType.warning,
                              );
                              return;
                            }
                            setState(() => _isSaving = true);
                            await widget.ref.read(adminProvider.notifier).updateRider(
                                  widget.rider,
                                  name: _name.text.trim(),
                                  phone: _phone.text.trim(),
                                  status: _status,
                                );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSaving ? 'Saving Changes...' : 'Save Courier Changes', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRiderDialog extends StatefulWidget {
  const _CreateRiderDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreateRiderDialog> createState() => _CreateRiderDialogState();
}

class _CreateRiderDialogState extends State<_CreateRiderDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _password = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _plateNumber = TextEditingController();

  String _vehicleType = 'Motorcycle';
  String _hub = 'Central Operations Hub';
  String _shiftSlot = 'Full Shift (7:00 AM - 7:00 PM)';
  bool _isOnlineOnCreate = true;

  // Document Upload States
  String? _licenseFile;
  String? _orCrFile;
  String? _clearanceFile;
  String? _photoIdFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _emergencyContact.dispose();
    _password.dispose();
    _vehicleModel.dispose();
    _plateNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF7C3AED), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Register Courier & Fleet Transport', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Onboard delivery rider, attach vehicle documents, and assign operating hub.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF7C3AED),
                labelColor: const Color(0xFF7C3AED),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.badge_outlined, size: 18), text: '1. Personal Info'),
                  Tab(icon: Icon(Icons.two_wheeler_rounded, size: 18), text: '2. Vehicle & Hub'),
                  Tab(icon: Icon(Icons.cloud_upload_outlined, size: 18), text: '3. Document Uploads'),
                ],
              ),
            ),

            // Tab Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Personal Info
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _name,
                          decoration: InputDecoration(
                            labelText: 'Rider Full Legal Name *',
                            hintText: 'e.g. Arnel Dimaculangan',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Account Email Address *',
                            hintText: 'rider.arnel@mns.ph',
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Mobile Phone Number *',
                                  hintText: '+63 917 555 1234',
                                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _emergencyContact,
                                decoration: InputDecoration(
                                  labelText: 'Emergency Contact Person',
                                  hintText: 'Maria Dimaculangan (Spouse)',
                                  prefixIcon: const Icon(Icons.contact_phone_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Initial Account Password *',
                            hintText: 'Minimum 8 characters (e.g. Password123!)',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Vehicle & Hub
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _vehicleType,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle Transport Type',
                                  prefixIcon: const Icon(Icons.commute_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Motorcycle', child: Text('🏍️ Motorcycle (Standard)')),
                                  DropdownMenuItem(value: 'Electric Scooter', child: Text('⚡ Electric Scooter')),
                                  DropdownMenuItem(value: 'Bicycle', child: Text('🚲 Bicycle / Eco-Courier')),
                                  DropdownMenuItem(value: 'Car / Van', child: Text('🚗 Car / Van (Bulk)')),
                                ],
                                onChanged: (val) => setState(() => _vehicleType = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _hub,
                                decoration: InputDecoration(
                                  labelText: 'Assigned Operating Hub',
                                  prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Davao Toril Hub', child: Text('📍 Davao Toril Hub')),
                                  DropdownMenuItem(value: 'Davao Matina Hub', child: Text('📍 Davao Matina Hub')),
                                  DropdownMenuItem(value: 'Davao Bajada Hub', child: Text('📍 Davao Bajada Hub')),
                                  DropdownMenuItem(value: 'Davao City Central Hub', child: Text('📍 Davao City Central Hub')),
                                ],
                                onChanged: (val) => setState(() => _hub = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _vehicleModel,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle Model & Year',
                                  hintText: 'e.g. Honda Click 125i (2024)',
                                  prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _plateNumber,
                                decoration: InputDecoration(
                                  labelText: 'License Plate / MV File No.',
                                  hintText: 'e.g. DAV-842',
                                  prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _shiftSlot,
                          decoration: InputDecoration(
                            labelText: 'Preferred Delivery Shift Slot',
                            prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Morning Shift (6:00 AM - 2:00 PM)', child: Text('🌅 Morning Shift (6:00 AM - 2:00 PM)')),
                            DropdownMenuItem(value: 'Afternoon Shift (2:00 PM - 10:00 PM)', child: Text('☀️ Afternoon Shift (2:00 PM - 10:00 PM)')),
                            DropdownMenuItem(value: 'Night Shift (10:00 PM - 6:00 AM)', child: Text('🌙 Night Shift (10:00 PM - 6:00 AM)')),
                            DropdownMenuItem(value: 'Full Flexibility', child: Text('🔄 Full Flexibility (Any Shift)')),
                          ],
                          onChanged: (val) => setState(() => _shiftSlot = val!),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Set Initial Status to ON DUTY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: const Text('Enable rider to receive dispatch assignments immediately upon account creation.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          value: _isOnlineOnCreate,
                          activeThumbColor: const Color(0xFF7C3AED),
                          activeTrackColor: const Color(0xFFE9D5FF),
                          onChanged: (val) => setState(() => _isOnlineOnCreate = val),
                        ),
                      ],
                    ),
                  ),

                  // Tab 3: Document Uploads
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Required Onboarding Attachments',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Upload courier credentials, vehicle registrations, and identity verification files.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        _UploadDocumentCard(
                          title: "Professional Driver's License",
                          description: 'Front and back scan with non-expired LTO validity',
                          fileName: _licenseFile,
                          icon: Icons.badge_outlined,
                          onPick: () => setState(() => _licenseFile = 'drivers_license_card_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg'),
                        ),
                        const SizedBox(height: 10),

                        _UploadDocumentCard(
                          title: 'Vehicle OR / CR Registration',
                          description: 'Official Receipt & Certificate of Registration issued by LTO',
                          fileName: _orCrFile,
                          icon: Icons.article_outlined,
                          onPick: () => setState(() => _orCrFile = 'vehicle_or_cr_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.pdf'),
                        ),
                        const SizedBox(height: 10),

                        _UploadDocumentCard(
                          title: 'Barangay / Police Clearance',
                          description: 'Valid background clearance document for Davao City',
                          fileName: _clearanceFile,
                          icon: Icons.shield_outlined,
                          onPick: () => setState(() => _clearanceFile = 'davao_police_clearance_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.pdf'),
                        ),
                        const SizedBox(height: 10),

                        _UploadDocumentCard(
                          title: '2x2 Formal Courier Photo',
                          description: 'Recent white-background formal avatar photo',
                          fileName: _photoIdFile,
                          icon: Icons.account_box_outlined,
                          onPick: () => setState(() => _photoIdFile = 'formal_photo_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_name.text.trim().isEmpty || !_email.text.contains('@') || _password.text.length < 8) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please complete rider name, valid email, and password (min 8 chars).')),
                              );
                              return;
                            }
                            setState(() => _isSaving = true);
                            await widget.ref.read(adminProvider.notifier).saveRider(
                                  name: _name.text.trim(),
                                  email: _email.text.trim(),
                                  password: _password.text,
                                  phone: _phone.text.trim().isEmpty ? '+63 917 555 1234' : _phone.text.trim(),
                                );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSaving ? 'Registering Courier...' : 'Complete Rider Registration', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreset {
  const _ImagePreset({required this.label, required this.url, required this.icon});
  final String label;
  final String url;
  final IconData icon;
}

class _ImageUploadPickerField extends StatefulWidget {
  const _ImageUploadPickerField({
    required this.controller,
    required this.label,
    required this.presets,
  });

  final TextEditingController controller;
  final String label;
  final List<_ImagePreset> presets;

  @override
  State<_ImageUploadPickerField> createState() => _ImageUploadPickerFieldState();
}

class _ImageUploadPickerFieldState extends State<_ImageUploadPickerField> {
  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.controller.text.trim();
    final hasImage = currentUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
              const Spacer(),
              if (hasImage)
                InkWell(
                  onTap: () {
                    widget.controller.clear();
                    setState(() {});
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                      SizedBox(width: 2),
                      Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Preview & URL input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image Preview Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Image.network(
                        currentUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF94A3B8), size: 24),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: widget.controller,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Image Web URL',
                        hintText: 'https://images.unsplash.com/...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Provide image link or tap a preset suggestion',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Presets Wrap
          const Text('Curated Presets / Suggestions:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.presets.map((preset) {
              final isSelected = currentUrl == preset.url;
              return InkWell(
                onTap: () {
                  widget.controller.text = preset.url;
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF3E8FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(preset.icon, size: 13, color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF334155),
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
    );
  }
}

class _UploadDocumentCard extends StatelessWidget {
  const _UploadDocumentCard({
    required this.title,
    required this.description,
    required this.fileName,
    required this.icon,
    required this.onPick,
  });

  final String title;
  final String description;
  final String? fileName;
  final IconData icon;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFF9F7FD) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasFile ? const Color(0xFFE9D5FF) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasFile ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: hasFile ? const Color(0xFF7C3AED) : const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(
                  hasFile ? 'Attached: $fileName' : description,
                  style: TextStyle(
                    color: hasFile ? const Color(0xFF059669) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: hasFile ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              side: const BorderSide(color: Color(0xFFC4B5FD)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onPick,
            icon: Icon(hasFile ? Icons.refresh_rounded : Icons.upload_file_rounded, size: 14),
            label: Text(hasFile ? 'Replace' : 'Upload', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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
  late final AnimationController _routeAnimController;
  Timer? _telemetryTimer;
  String? _selectedDeliveryId;
  List<LatLng>? _historyRoutePoints;
  List<LatLng>? _activeDirectionPoints;
  String? _loadedRoadDeliveryId;
  bool _isDrawerOpen = true;
  String _searchQuery = '';
  AdminOrderStatus? _statusFilter;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _routeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollTelemetry());
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _routeAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng _interpolatePoint(List<LatLng> points, double t) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points.first;
    final lengths = <double>[];
    double totalLength = 0;
    for (var i = 0; i < points.length - 1; i++) {
      final dist = math.sqrt(
        math.pow(points[i + 1].latitude - points[i].latitude, 2) +
        math.pow(points[i + 1].longitude - points[i].longitude, 2),
      );
      lengths.add(dist);
      totalLength += dist;
    }
    if (totalLength == 0) return points.first;
    final targetDist = (t % 1.0) * totalLength;
    double accumulated = 0;
    for (var i = 0; i < lengths.length; i++) {
      if (accumulated + lengths[i] >= targetDist) {
        final segT = (targetDist - accumulated) / lengths[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        return LatLng(
          p1.latitude + (p2.latitude - p1.latitude) * segT,
          p1.longitude + (p2.longitude - p1.longitude) * segT,
        );
      }
      accumulated += lengths[i];
    }
    return points.last;
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

  LatLng _getPickupPos(LiveDelivery delivery) {
    if (delivery.pickupLatitude != null && delivery.pickupLongitude != null && delivery.pickupLatitude != 0) {
      return LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!);
    }
    final name = delivery.storeName.toLowerCase();
    if (name.contains('penong')) return const LatLng(7.1125, 124.8285);
    if (name.contains('jollibee')) return const LatLng(7.1090, 124.8240);
    if (name.contains('inasal')) return const LatLng(7.1085, 124.8250);
    if (name.contains('chowking')) return const LatLng(7.1075, 124.8230);
    return const LatLng(7.1086, 124.8235);
  }

  LatLng _getDestPos(LiveDelivery delivery) {
    if (delivery.destinationLatitude != null && delivery.destinationLongitude != null && delivery.destinationLatitude != 0) {
      return LatLng(delivery.destinationLatitude!, delivery.destinationLongitude!);
    }
    return const LatLng(7.1066, 124.8292);
  }

  LatLng _getRiderPos(LiveDelivery delivery) {
    if (delivery.latitude != 0 && delivery.longitude != 0) {
      return LatLng(delivery.latitude, delivery.longitude);
    }
    final pickup = _getPickupPos(delivery);
    final dest = _getDestPos(delivery);
    return LatLng(
      (pickup.latitude + dest.latitude) / 2 + 0.0004,
      (pickup.longitude + dest.longitude) / 2 - 0.0003,
    );
  }

  void _focusDelivery(LiveDelivery delivery) {
    setState(() {
      _selectedDeliveryId = delivery.id;
      _historyRoutePoints = null;
      _activeDirectionPoints = null;
      _loadedRoadDeliveryId = null;
    });
    final pickup = _getPickupPos(delivery);
    final dest = _getDestPos(delivery);
    final rider = _getRiderPos(delivery);

    final points = [rider, dest, pickup];
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 14.5);

    _fetchRoadRoute(delivery);
  }

  void _fetchRoadRoute(LiveDelivery delivery) {
    if (_loadedRoadDeliveryId == delivery.id) return;
    _loadedRoadDeliveryId = delivery.id;
    final pickup = _getPickupPos(delivery);
    final dest = _getDestPos(delivery);
    final rider = _getRiderPos(delivery);
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

    if (delivery.status == AdminOrderStatus.onTheWay || delivery.status == AdminOrderStatus.pickedUp) {
      const RoadRouteService().getRoutePoints(
        origin: pickup,
        destination: rider,
        mapboxToken: mapboxToken,
      ).then((points) {
        if (mounted && _selectedDeliveryId == delivery.id) {
          setState(() => _historyRoutePoints = points);
        }
      });

      const RoadRouteService().getRoutePoints(
        origin: rider,
        destination: dest,
        mapboxToken: mapboxToken,
      ).then((points) {
        if (mounted && _selectedDeliveryId == delivery.id) {
          setState(() => _activeDirectionPoints = points);
        }
      });
    } else {
      const RoadRouteService().getRoutePoints(
        origin: rider,
        destination: pickup,
        mapboxToken: mapboxToken,
      ).then((points) {
        if (mounted && _selectedDeliveryId == delivery.id) {
          setState(() {
            _historyRoutePoints = null;
            _activeDirectionPoints = points;
          });
        }
      });
    }
  }

  void _fitAllRiders(List<LiveDelivery> deliveries) {
    final valid = deliveries.where((d) => d.latitude != 0 && d.longitude != 0).toList();
    if (valid.isEmpty) {
      _mapController.move(const LatLng(7.1086, 124.8235), 13.0);
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
    _mapController.move(center, 13.5);
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
        : const LatLng(7.1086, 124.8235);

    final selectedDelivery = _selectedDeliveryId == null
        ? null
        : allDeliveries.cast<LiveDelivery?>().firstWhere((d) => d?.id == _selectedDeliveryId, orElse: () => null);

    final pickupPos = selectedDelivery != null ? _getPickupPos(selectedDelivery) : null;
    final destPos = selectedDelivery != null ? _getDestPos(selectedDelivery) : null;

    if (selectedDelivery != null && _loadedRoadDeliveryId != selectedDelivery.id) {
      _fetchRoadRoute(selectedDelivery);
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _routeAnimController,
              builder: (context, _) {
                final glowPulsingWidth = 8.0 + 3.0 * math.sin(_routeAnimController.value * 2 * math.pi).abs();
                final glowPulsingAlpha = 0.22 + 0.15 * math.sin(_routeAnimController.value * 2 * math.pi).abs();

                final movingActivePoint = (_activeDirectionPoints != null && _activeDirectionPoints!.isNotEmpty)
                    ? _interpolatePoint(_activeDirectionPoints!, _routeAnimController.value)
                    : null;

                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: mapboxToken.isNotEmpty
                          ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      tileProvider: CancellableNetworkTileProvider(),
                      userAgentPackageName: 'com.mns.delivery.admin',
                    ),

                    if (_historyRoutePoints != null && _historyRoutePoints!.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _historyRoutePoints!,
                            strokeWidth: 3.5,
                            color: const Color(0xFF64748B).withValues(alpha: 0.55),
                          ),
                        ],
                      ),

                    if (_activeDirectionPoints != null && _activeDirectionPoints!.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _activeDirectionPoints!,
                            strokeWidth: glowPulsingWidth,
                            color: const Color(0xFF7C3AED).withValues(alpha: glowPulsingAlpha),
                          ),
                          Polyline(
                            points: _activeDirectionPoints!,
                            strokeWidth: 4.5,
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        if (movingActivePoint != null)
                          Marker(
                            point: movingActivePoint,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x777C3AED),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 16),
                            ),
                          ),

                        ...positioned.map((delivery) {
                          final isSelected = delivery.id == _selectedDeliveryId;
                          final isStale = delivery.stale;
                          final markerColor = isStale
                              ? const Color(0xFFEF4444)
                              : (isSelected ? const Color(0xFF7C3AED) : const Color(0xFF059669));

                          return Marker(
                            point: LatLng(delivery.latitude, delivery.longitude),
                            width: 140,
                            height: 72,
                            child: GestureDetector(
                              onTap: () => _focusDelivery(delivery),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: Text(
                                      delivery.rider,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        if (selectedDelivery != null && pickupPos != null)
                          Marker(
                            point: pickupPos,
                            width: 150,
                            height: 72,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                    border: Border.all(color: const Color(0xFF7C3AED), width: 2.5),
                                  ),
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFF7C3AED),
                                    child: Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Text(
                                    selectedDelivery.storeName.isNotEmpty ? selectedDelivery.storeName : 'Pickup Store',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (selectedDelivery != null && destPos != null)
                          Marker(
                            point: destPos,
                            width: 170,
                            height: 72,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                    border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                                  ),
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFF10B981),
                                    child: Icon(Icons.home_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Text(
                                    'Drop-off: ${selectedDelivery.customer}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            '${positioned.length} Active Riders · Live GPS & Direction Stream',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fit All Riders on Screen',
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 20, color: Color(0xFF0F172A)),
                        onPressed: () => _fitAllRiders(allDeliveries),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Sync GPS Telemetry Now',
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF7C3AED)),
                        onPressed: _isSyncing ? null : _manualSync,
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
                        icon: Icon(_isDrawerOpen ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined, size: 18),
                        label: Text(_isDrawerOpen ? 'Hide Roster' : 'Show Roster (${filteredDeliveries.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isDrawerOpen)
            Positioned(
              top: 88,
              left: 20,
              bottom: 20,
              width: 370,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
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
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${filteredDeliveries.length}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF7C3AED)),
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
                                      ? const Color(0xFFF3E8FF)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _focusDelivery(delivery),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF7C3AED)
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

          if (selectedDelivery != null)
            Positioned(
              bottom: 24,
              left: _isDrawerOpen ? 410 : 24,
              right: 100,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 640),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    selectedDelivery.rider,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    selectedDelivery.status.label,
                                    style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (selectedDelivery.etaMinutes != null && selectedDelivery.etaMinutes! > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'ETA ${selectedDelivery.etaMinutes}m',
                                      style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${selectedDelivery.storeName.isNotEmpty ? '${selectedDelivery.storeName} → ' : ''}${selectedDelivery.customer} · #${selectedDelivery.orderId.length > 8 ? selectedDelivery.orderId.substring(0, 8) : selectedDelivery.orderId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'GPS: ${selectedDelivery.latitude.toStringAsFixed(4)}, ${selectedDelivery.longitude.toStringAsFixed(4)} · Direction Active',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close details',
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                        onPressed: () => setState(() => _selectedDeliveryId = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                    tooltip: 'Center on Operations Hub',
                    icon: const Icon(Icons.my_location_rounded, color: Color(0xFF7C3AED)),
                    onPressed: () => _mapController.move(const LatLng(7.1086, 124.8235), 13.5),
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
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED),
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
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);
    Color border = const Color(0xFFE2E8F0);

    if (lower.contains('way') || lower.contains('delivered') || lower.contains('active') || lower.contains('available')) {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
      border = const Color(0xFFA7F3D0);
    } else if (lower.contains('pick') || lower.contains('confirm') || lower.contains('assign')) {
      bg = const Color(0xFFF3E8FF);
      text = const Color(0xFF7C3AED);
      border = const Color(0xFFDDD6FE);
    } else if (lower.contains('pend')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
    } else if (lower.contains('cancel')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFDC2626);
      border = const Color(0xFFFECACA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: text),
      ),
    );
  }
}

