import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/customer_models.dart';
import '../state/customer_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ordersProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const _BrowseTab(), const _OrdersTab(), const _ProfileTab()];
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFB89CE5).withValues(alpha: 0.2),
        elevation: 8,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined, color: Color(0xFF64748B)),
            selectedIcon: Icon(Icons.storefront_rounded, color: Color(0xFF9D65E5)),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B)),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF9D65E5)),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF9D65E5)),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _BrowseTab extends ConsumerStatefulWidget {
  const _BrowseTab();

  @override
  ConsumerState<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends ConsumerState<_BrowseTab> {
  final _search = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  static const _foodCategories = [
    {'name': 'All', 'icon': '🍽️'},
    {'name': 'Chicken & Inasal', 'icon': '🍗'},
    {'name': 'Grilled & BBQ', 'icon': '🥩'},
    {'name': 'Silog Meals', 'icon': '🍳'},
    {'name': 'Noodles & Pancit', 'icon': '🍜'},
    {'name': 'Seafood', 'icon': '🐟'},
    {'name': 'Beverages', 'icon': '🧋'},
    {'name': 'Desserts', 'icon': '🍧'},
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider);
    final profile = ref.watch(sessionProvider).profile;
    final cartCount = ref.watch(cartProvider).count;
    final addressesAsync = ref.watch(addressesProvider);
    final addressText = addressesAsync.maybeWhen(
      data: (list) => list.isNotEmpty ? '${list.first.label} · ${list.first.address}' : 'Home · Poblacion, Kabacan',
      orElse: () => 'Home · Poblacion, Kabacan',
    );

    return RefreshIndicator(
      color: const Color(0xFF7C3AED),
      onRefresh: () => ref.refresh(storesProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Location & Cart Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELIVERING TO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () => context.push('/addresses'),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      addressText,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Badge(
                        label: Text('$cartCount'),
                        isLabelVisible: cartCount > 0,
                        backgroundColor: const Color(0xFFFF5216),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFF8FAFC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => context.push('/cart'),
                            icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A)),
                            tooltip: 'Open cart',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Greeting Title
                  Text(
                    'Mabuhay, ${profile?.name.split(' ').first ?? 'there'}! 👋',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'What authentic Filipino dish are you craving?',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Live Search Field with Soft Gradient Shadow
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search inasal, sisig, silog, halo-halo...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Food Category Pills Horizontal List
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _foodCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _foodCategories[index];
                        final name = cat['name']!;
                        final icon = cat['icon']!;
                        final isSelected = _selectedCategory == name;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : const Color(0xFFE5DEEE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(icon, style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 6),
                                Text(
                                  name,
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
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Promo Banner (Solid)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CASH ON DELIVERY',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Fresh & Hot Delivery in Kabacan',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Fast fleet dispatches with live GPS tracking.',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delivery_dining_rounded, size: 40, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stores Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Nearby Restaurants',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCategory == 'All' ? 'Kabacan Hub' : _selectedCategory,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9D65E5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          stores.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF9D65E5)),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              child: Center(
                child: FilledButton.tonal(
                  onPressed: () => ref.invalidate(storesProvider),
                  child: const Text('Try again'),
                ),
              ),
            ),
            data: (items) {
              final filtered = items.where((store) {
                final matchQuery = _query.isEmpty ||
                    store.name.toLowerCase().contains(_query) ||
                    store.subtitle.toLowerCase().contains(_query) ||
                    store.categories.any((cat) => cat.toLowerCase().contains(_query));
                final matchCat = _selectedCategory == 'All' ||
                    store.categories.any((cat) => cat.toLowerCase().contains(_selectedCategory.toLowerCase())) ||
                    store.name.toLowerCase().contains(_selectedCategory.toLowerCase());
                return matchQuery && matchCat;
              }).toList();

              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_outlined, size: 48, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 12),
                          Text('No restaurants match your search.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                          SizedBox(height: 6),
                          Text('Try selecting another category or clear search.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) => _StoreCard(store: filtered[index]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _getStorePhotoUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('penong')) return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80';
  if (lower.contains('mcmillan')) return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80';
  if (lower.contains('bogs bugoy')) return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80';
  if (lower.contains('love bite')) return 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=600&q=80';
  if (lower.contains('pastil')) return 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=600&q=80';
  if (lower.contains('jollibee')) return 'https://images.unsplash.com/photo-1513639776629-7b61b0ac49cb?w=600&q=80';
  if (lower.contains('macchiato') || lower.contains('cafe')) return 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&q=80';
  return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80';
}

List<Color> _getStoreGradient(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('penong') || lower.contains('inasal')) {
    return [const Color(0xFFE11D48), const Color(0xFFFF6B24), const Color(0xFFFBBF24)];
  }
  if (lower.contains('pastil') || lower.contains('native')) {
    return [const Color(0xFF047857), const Color(0xFF10B981), const Color(0xFF6EE7B7)];
  }
  if (lower.contains('mcmillan') || lower.contains('pasta')) {
    return [const Color(0xFF4338CA), const Color(0xFF6366F1), const Color(0xFFA5B4FC)];
  }
  if (lower.contains('bogs') || lower.contains('gastropub')) {
    return [const Color(0xFF881337), const Color(0xFF9F1239), const Color(0xFFFB7185)];
  }
  if (lower.contains('jollibee') || lower.contains('chicken')) {
    return [const Color(0xFFDC2626), const Color(0xFFEF4444), const Color(0xFFF97316)];
  }
  if (lower.contains('macchiato') || lower.contains('cafe')) {
    return [const Color(0xFF78350F), const Color(0xFFB45309), const Color(0xFFF59E0B)];
  }
  return [const Color(0xFF0F172A), const Color(0xFF334155), const Color(0xFF64748B)];
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final photoUrl = _getStorePhotoUrl(store.name);
    final gradient = _getStoreGradient(store.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/store', extra: store),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Photo Banner with Gradient Overlay
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo with Gradient Fallback
                  Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.restaurant_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                  ),

                  // Dark Tint Overlay for Text Contrast
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Header Badges Overlay
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'OPEN',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '${store.rating}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Title on Banner
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Store Details & Metadata
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.subtitle.isNotEmpty ? store.subtitle : 'Authentic Filipino cuisine in Kabacan',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  '${store.etaMinutes} mins',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '₱39 Delivery',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF065F46)),
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                    ],
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

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Your Orders',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        const Text('Track active deliveries and view COD receipts.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        const SizedBox(height: 20),

        if (orders.isEmpty)
          const _EmptyOrders()
        else
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: order.stage.isComplete ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFFF6B24).withValues(alpha: 0.15),
                      child: Icon(
                        order.stage.isComplete ? Icons.check_circle_rounded : Icons.delivery_dining_rounded,
                        color: order.stage.isComplete ? const Color(0xFF10B981) : const Color(0xFFFF6B24),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            order.store.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₱${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: order.stage.isComplete ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.stage.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: order.stage.isComplete ? const Color(0xFF065F46) : const Color(0xFFC2410C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d · h:mm a').format(order.createdAt),
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () => context.push('/order', extra: order),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B24).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFFF6B24)),
            ),
            const SizedBox(height: 16),
            const Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text('Your active deliveries and cash receipts will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 20),

        // Profile Avatar Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFFF6B24),
                child: Text(
                  profile?.name.isNotEmpty == true ? profile!.name.substring(0, 1).toUpperCase() : 'C',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.name ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(profile?.email ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action Links Card
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Color(0xFF0F172A)),
                  title: const Text('Saved addresses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Manage your delivery locations in Kabacan', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () => context.push('/addresses'),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const ListTile(
                  leading: Icon(Icons.payment_rounded, color: Color(0xFF0F172A)),
                  title: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('Cash on Delivery (COD) Enabled', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                  trailing: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444))),
                  onTap: () async {
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

