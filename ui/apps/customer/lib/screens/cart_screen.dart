import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../models/customer_models.dart';
import '../state/customer_state.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _address = TextEditingController();
  Position? _position;
  bool _placing = false;
  bool _locating = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _checkout(CartState cart) async {
    if (_address.text.trim().isEmpty || _position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an address and confirm its GPS location.')));
      return;
    }
    setState(() => _placing = true);
    try {
      final order = await ref.read(ordersProvider.notifier).place(cart, DeliveryAddress(label: 'Delivery address', address: _address.text.trim(), latitude: _position!.latitude, longitude: _position!.longitude));
      if (order != null && mounted) {
        ref.read(cartProvider.notifier).clear();
        context.go('/order', extra: order);
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Location services are disabled.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('Location permission is required.');
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: cart.lines.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shopping_bag_outlined, size: 58), const SizedBox(height: 14), const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 16), FilledButton.tonal(onPressed: () => context.go('/home'), child: const Text('Browse stores'))]))
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text(cart.store!.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: cart.lines
                      .map(
                        (line) => Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                              title: Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('₱${line.item.price.toStringAsFixed(0)} each'),
                              trailing: SizedBox(
                                width: 116,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          ref.read(cartProvider.notifier).setQuantity(line.item.id, line.quantity - 1),
                                      icon: const Icon(Icons.remove_circle_outline),
                                    ),
                                    Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    IconButton(
                                      onPressed: () =>
                                          ref.read(cartProvider.notifier).setQuantity(line.item.id, line.quantity + 1),
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (line != cart.lines.last) const Divider(height: 1),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 22),
              Text('Delivery address', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _locating ? null : _useCurrentLocation, icon: const Icon(Icons.my_location), label: Text(_position == null ? 'Use my current location' : 'Location confirmed')),
              const SizedBox(height: 22),
              Text('Payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Card(child: ListTile(leading: Icon(Icons.payments_outlined), title: Text('Cash on delivery', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('Pay the rider when your order arrives'), trailing: Icon(Icons.check_circle, color: Color(0xFF16845B)))),
              const SizedBox(height: 22),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [_AmountRow(label: 'Subtotal', value: cart.subtotal), const SizedBox(height: 10), const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Delivery fee'), Text('Calculated from route', style: TextStyle(fontWeight: FontWeight.w700))])]))),
              const SizedBox(height: 100),
            ]),
      bottomNavigationBar: cart.lines.isEmpty ? null : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: FilledButton(onPressed: _placing ? null : () => _checkout(cart), child: _placing ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Place COD order')))),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text('₱${value.toStringAsFixed(0)}')]);
}
