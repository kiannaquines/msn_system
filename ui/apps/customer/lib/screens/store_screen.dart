import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mns_design_system/design_system.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.store.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Badge(
              label: Text('${cart.count}'),
              isLabelVisible: cart.count > 0,
              backgroundColor: const Color(0xFF9D65E5),
              child: IconButton(
                onPressed: () => context.push('/cart'),
                icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A)),
                tooltip: 'Open cart',
              ),
            ),
          ),
        ],
      ),
      body: menu.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
        error: (_, __) => Center(
          child: FilledButton.tonal(
            onPressed: () => ref.invalidate(menuProvider(widget.store.id)),
            child: const Text('Try again'),
          ),
        ),
        data: (items) {
          final categories = ['All', ...{...widget.store.categories, ...items.map((item) => item.category)}];
          final filtered = items.where((item) {
            final matchesCategory = _category == 'All' || item.category == _category;
            final matchesQuery = _query.isEmpty ||
                item.name.toLowerCase().contains(_query) ||
                item.description.toLowerCase().contains(_query);
            return matchesCategory && matchesQuery;
          }).toList();

          return CustomScrollView(
            slivers: [
              // Store Header Banner with Image & Overlays
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo Background
                      Image.network(
                        _getStorePhoto(widget.store.name),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getStoreGradient(widget.store.name),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),

                      // Dark Vignette Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),

                      // Store Info Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'OPEN NOW · EXPRESS DELIVERY',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.store.name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 8)]),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.store.subtitle.isNotEmpty ? widget.store.subtitle : 'Authentic Filipino cuisine',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                      const SizedBox(width: 4),
                                      Text('${widget.store.rating} Rating', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.schedule_rounded, color: Color(0xFF94A3B8), size: 13),
                                      const SizedBox(width: 4),
                                      Text('${widget.store.etaMinutes} min delivery', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                                  ),
                                  child: const Text('COD Available', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter & Search Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search in ${widget.store.name}...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, index) {
                            final category = categories[index];
                            final isSelected = category == _category;
                            return ChoiceChip(
                              showCheckmark: false,
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF7C3AED),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                              onSelected: (_) => setState(() => _category = category),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _category == 'All' ? 'Full Menu (${filtered.length})' : '$_category (${filtered.length})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No dishes match your search.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _MenuCard(store: widget.store, item: filtered[index]),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: cart.count == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => context.push('/cart'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${cart.count} item${cart.count == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                        const Row(
                          children: [
                            Text('View Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                        Text('₱${cart.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

String _getStorePhoto(String name) {
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
    return [const Color(0xFF7C3AED), const Color(0xFF9D65E5), const Color(0xFFC084FC)];
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

IconData _getItemIcon(String name, String category) {
  final text = '$name $category'.toLowerCase();
  if (text.contains('chicken') || text.contains('inasal') || text.contains('joy') || text.contains('fillet')) return Icons.restaurant_rounded;
  if (text.contains('bbq') || text.contains('liempo') || text.contains('sisig') || text.contains('pata') || text.contains('bulalo') || text.contains('salpicao') || text.contains('bulgogi')) return Icons.local_fire_department_rounded;
  if (text.contains('fish') || text.contains('tuna') || text.contains('kinilaw') || text.contains('shrimp') || text.contains('scallop') || text.contains('seafood')) return Icons.set_meal_rounded;
  if (text.contains('pasta') || text.contains('carbonara') || text.contains('noodle') || text.contains('canton')) return Icons.dinner_dining_rounded;
  if (text.contains('coffee') || text.contains('latte') || text.contains('macchiato')) return Icons.coffee_rounded;
  if (text.contains('shake') || text.contains('juice') || text.contains('tea') || text.contains('cooler') || text.contains('mocktail') || text.contains('buko')) return Icons.local_bar_rounded;
  if (text.contains('burger') || text.contains('sandwich')) return Icons.lunch_dining_rounded;
  if (text.contains('pie') || text.contains('cake') || text.contains('waffle') || text.contains('pastil') || text.contains('tinagtag') || text.contains('dessert') || text.contains('egg')) return Icons.cake_rounded;
  return Icons.fastfood_rounded;
}

List<Color> _getItemGradient(String name, String category) {
  final text = '$name $category'.toLowerCase();
  if (text.contains('chicken') || text.contains('inasal') || text.contains('joy')) {
    return [const Color(0xFF7C3AED), const Color(0xFF9D65E5), const Color(0xFFC084FC)];
  }
  if (text.contains('bbq') || text.contains('sisig') || text.contains('bulalo') || text.contains('pata') || text.contains('bulgogi')) {
    return [const Color(0xFF991B1B), const Color(0xFFDC2626), const Color(0xFFF97316)];
  }
  if (text.contains('fish') || text.contains('shrimp') || text.contains('scallop') || text.contains('seafood')) {
    return [const Color(0xFF0284C7), const Color(0xFF0EA5E9), const Color(0xFF38BDF8)];
  }
  if (text.contains('coffee') || text.contains('latte') || text.contains('macchiato')) {
    return [const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFFD97706)];
  }
  if (text.contains('pastil') || text.contains('tinagtag') || text.contains('rice')) {
    return [const Color(0xFF065F46), const Color(0xFF059669), const Color(0xFF34D399)];
  }
  if (text.contains('dessert') || text.contains('shake') || text.contains('cake') || text.contains('matcha')) {
    return [const Color(0xFF86198F), const Color(0xFFA21CAF), const Color(0xFFE879F9)];
  }
  return [const Color(0xFF1E293B), const Color(0xFF334155), const Color(0xFF64748B)];
}

class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.store, required this.item});
  final Store store;
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = _getItemGradient(item.name, item.category);
    final icon = _getItemIcon(item.name, item.category);
    final imageUrl = item.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dish Thumbnail with Vibrant Gradient Fallback
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 80,
                height: 80,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
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
                            child: Icon(icon, size: 32, color: Colors.white.withValues(alpha: 0.85)),
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
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(icon, size: 32, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: item.available ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      decoration: item.available ? null : TextDecoration.lineThrough,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description.isNotEmpty ? item.description : 'Authentic Filipino house specialty',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₱${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: item.available ? const Color(0xFF7C3AED) : Colors.grey,
                        ),
                      ),
                      if (!item.available) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Sold Out', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Add Button
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: item.available ? const Color(0xFF7C3AED) : Colors.grey.shade200,
                foregroundColor: item.available ? Colors.white : Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: item.available
                  ? () {
                      ref.read(cartProvider.notifier).add(store, item);
                      MnsSnackBar.show(
                        context,
                        title: 'Added to Cart',
                        message: '${item.name} added to your basket',
                        type: MnsSnackBarType.success,
                        duration: const Duration(milliseconds: 1400),
                      );
                    }
                  : null,
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'Add ${item.name}',
            ),
          ],
        ),
      ),
    );
  }
}
