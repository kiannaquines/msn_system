import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/customer_models.dart';
import '../state/customer_state.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, required this.store});
  final Store store;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider(widget.store.id));
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        actions: [Badge(label: Text('${cart.count}'), isLabelVisible: cart.count > 0, child: IconButton(onPressed: () => context.push('/cart'), icon: const Icon(Icons.shopping_bag_outlined), tooltip: 'Open cart'))],
      ),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: FilledButton.tonal(onPressed: () => ref.invalidate(menuProvider(widget.store.id)), child: const Text('Try again'))),
        data: (items) {
          final categories = ['All', ...{...widget.store.categories, ...items.map((item) => item.category)}];
          final filtered = items.where((item) {
            final matchesCategory = _category == 'All' || item.category == _category;
            final matchesQuery = _query.isEmpty || item.name.toLowerCase().contains(_query) || item.description.toLowerCase().contains(_query);
            return matchesCategory && matchesQuery;
          }).toList();
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Container(height: 160, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF154734), Color(0xFF3E7A62)])), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.restaurant_menu, size: 52, color: Colors.white), const SizedBox(height: 10), Text(widget.store.subtitle, style: const TextStyle(color: Colors.white, fontSize: 16))]))),
            SliverPadding(padding: const EdgeInsets.all(20), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(onChanged: (value) => setState(() => _query = value.trim().toLowerCase()), decoration: const InputDecoration(hintText: 'Search the menu', prefixIcon: Icon(Icons.search))),
              const SizedBox(height: 16),
              SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: categories.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) { final category = categories[index]; return ChoiceChip(label: Text(category), selected: category == _category, onSelected: (_) => setState(() => _category = category)); })),
              const SizedBox(height: 22),
              Text('Menu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]))),
            if (filtered.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('No menu items match your search.')))
            else
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 110), sliver: SliverList.separated(itemCount: filtered.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, index) => _MenuCard(store: widget.store, item: filtered[index]))),
          ]);
        },
      ),
      bottomNavigationBar: cart.count == 0
          ? null
          : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: FilledButton(onPressed: () => context.push('/cart'), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${cart.count} item${cart.count == 1 ? '' : 's'}'), const Text('View cart'), Text('₱${cart.subtotal.toStringAsFixed(0)}')])))),
    );
  }
}

class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.store, required this.item});
  final Store store;
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 5), Text(item.description, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 12), Text('₱${item.price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary))])),
      const SizedBox(width: 12),
      IconButton.filled(onPressed: item.available ? () { ref.read(cartProvider.notifier).add(store, item); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} added'), duration: const Duration(milliseconds: 800))); } : null, icon: const Icon(Icons.add), tooltip: 'Add ${item.name}'),
    ])));
  }
}
