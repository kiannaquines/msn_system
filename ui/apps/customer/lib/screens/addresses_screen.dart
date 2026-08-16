import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../state/customer_state.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: FilledButton.tonal(onPressed: () => ref.invalidate(addressesProvider), child: const Text('Try again'))),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Add an address for faster checkout.'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)), title: Text(items[index].label, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(items[index].address))),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context, ref), icon: const Icon(Icons.add), label: const Text('Add address')),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final label = TextEditingController(text: 'Home');
    final address = TextEditingController();
    Position? position;
    var locating = false;
    final created = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Add delivery address'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: label, decoration: const InputDecoration(labelText: 'Label')),
        const SizedBox(height: 12),
        TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Complete address')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: locating ? null : () async {
            setState(() => locating = true);
            try {
              var permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
              if (!await Geolocator.isLocationServiceEnabled() || permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
              final current = await Geolocator.getCurrentPosition();
              if (dialogContext.mounted) setState(() => position = current);
            } finally {
              if (dialogContext.mounted) setState(() => locating = false);
            }
          },
          icon: const Icon(Icons.my_location),
          label: Text(position == null ? 'Confirm GPS location' : 'Location confirmed'),
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: position == null ? null : () async { if (address.text.trim().isEmpty) return; await ref.read(customerRepositoryProvider).createAddress(label.text.trim(), address.text.trim(), latitude: position!.latitude, longitude: position!.longitude); if (context.mounted) Navigator.pop(context, true); }, child: const Text('Save'))],
    )));
    label.dispose();
    address.dispose();
    if (created == true) ref.invalidate(addressesProvider);
  }
}
