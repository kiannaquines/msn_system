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
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Browse'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
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
    return RefreshIndicator(
      onRefresh: () => ref.refresh(storesProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delivering to', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black54)), const SizedBox(height: 2), const Row(children: [Icon(Icons.location_on, size: 18), SizedBox(width: 4), Expanded(child: Text('Home · Poblacion, Davao City', style: TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))])])),
                      Badge(label: Text('$cartCount'), isLabelVisible: cartCount > 0, child: IconButton.filledTonal(onPressed: () => context.push('/cart'), icon: const Icon(Icons.shopping_bag_outlined), tooltip: 'Open cart')),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Good day, ${profile?.name.split(' ').first ?? 'there'}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('What are you craving today?', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 20),
                  TextField(controller: _search, onChanged: (value) => setState(() => _query = value.trim().toLowerCase()), decoration: const InputDecoration(hintText: 'Search stores or food', prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFFFFE8B2), borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Freshly made. Delivered.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Cash on delivery, live tracking included.')])), Icon(Icons.delivery_dining, size: 58, color: Theme.of(context).colorScheme.primary)]),
                  ),
                  const SizedBox(height: 26),
                  Text('Nearby stores', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          stores.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (_, __) => SliverFillRemaining(child: Center(child: FilledButton.tonal(onPressed: () => ref.invalidate(storesProvider), child: const Text('Try again')))),
            data: (items) {
              final filtered = items.where((store) => _query.isEmpty || store.name.toLowerCase().contains(_query) || store.categories.any((category) => category.toLowerCase().contains(_query))).toList();
              if (filtered.isEmpty) return const SliverFillRemaining(child: Center(child: Text('No stores match your search.')));
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/store', extra: store),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 118, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF154734), Color(0xFF3E7A62)])), child: const Center(child: Icon(Icons.restaurant, size: 54, color: Colors.white))),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(store.subtitle, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 12), Row(children: [const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 19), Text(' ${store.rating}'), const SizedBox(width: 16), const Icon(Icons.schedule, size: 18), Text(' ${store.etaMinutes} min')])]))
        ]),
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
        Text('Your orders', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Track active deliveries and view receipts.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        if (orders.isEmpty) const _EmptyOrders() else ...orders.map((order) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(child: Icon(order.stage.isComplete ? Icons.check : Icons.delivery_dining)), title: Text(order.store.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${order.stage.label} · ${DateFormat('MMM d, h:mm a').format(order.createdAt)}'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/order', extra: order))))
      ],
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.receipt_long_outlined, size: 52, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 14), const Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 6), const Text('Your active deliveries and receipts will appear here.', textAlign: TextAlign.center)])));
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [CircleAvatar(radius: 28, child: Text(profile?.name.substring(0, 1).toUpperCase() ?? 'C')), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile?.name ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(profile?.email ?? '', style: const TextStyle(color: Colors.black54))]))]))),
      const SizedBox(height: 16),
      Card(child: Column(children: [ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('Saved addresses'), subtitle: const Text('Manage your delivery locations'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/addresses')), const Divider(height: 1), const ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notifications'), trailing: Icon(Icons.chevron_right)), const Divider(height: 1), ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: () async { await ref.read(sessionProvider.notifier).logout(); if (context.mounted) context.go('/login'); })])),
    ]);
  }
}
