import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1280), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.black54))]), Row(mainAxisSize: MainAxisSize.min, children: actions)]), const SizedBox(height: 24), child]))));
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  Widget build(BuildContext context) {
    final pending = data.orders.where((order) => order.status == AdminOrderStatus.pending).length;
    final active = data.deliveries.where((delivery) => delivery.status != AdminOrderStatus.delivered).length;
    final revenue = (data.report['cod_sales'] ?? data.orders.where((order) => order.codPaid).fold<double>(0, (sum, order) => sum + order.total)).toDouble();
    return _Page(title: 'Operations overview', subtitle: 'Current order, delivery, and cash-on-delivery performance.', child: Column(children: [
      Wrap(spacing: 14, runSpacing: 14, children: [_Kpi(label: 'Pending orders', value: '$pending', icon: Icons.pending_actions), _Kpi(label: 'Active deliveries', value: '$active', icon: Icons.delivery_dining), _Kpi(label: 'Available riders', value: '${data.riders.where((rider) => rider.status == AdminRiderStatus.available).length}', icon: Icons.badge_outlined), _Kpi(label: 'COD collected', value: '₱${revenue.toStringAsFixed(0)}', icon: Icons.payments_outlined)]),
      const SizedBox(height: 24),
      _Section(title: 'Needs attention', child: Column(children: data.orders.where((order) => order.status == AdminOrderStatus.pending).map((order) => ListTile(leading: const CircleAvatar(child: Icon(Icons.receipt_long)), title: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${order.customer} · ${order.store}'), trailing: Text('₱${order.total.toStringAsFixed(0)}'))).toList())),
      const SizedBox(height: 18),
      _Section(title: 'Recent activity', child: Column(children: data.audit.take(5).map((entry) => ListTile(leading: const Icon(Icons.history), title: Text(entry.action), subtitle: Text('${entry.actor} · ${entry.reason}'), trailing: Text(DateFormat('h:mm a').format(entry.createdAt)))).toList())),
    ]));
  }
}

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Page(
        title: 'Store catalog',
        subtitle: 'Manage stores, menu items, prices, and availability.',
        actions: [
          FilledButton.icon(
            onPressed: () => _editStore(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add store'),
          ),
        ],
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: data.stores.map((store) => SizedBox(
            width: 390,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                        Switch(
                          value: store.available,
                          onChanged: (value) async =>
                              ref.read(adminProvider.notifier).saveStore(store.copyWith(available: value)),
                        ),
                      ],
                    ),
                    Text(store.description, style: const TextStyle(color: Colors.black54)),
                    const Divider(height: 28),
                    ...store.items.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _editMenuItem(context, ref, store, item),
                          title: Text(item.name),
                          subtitle: Text(item.category),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₱${item.price.toStringAsFixed(0)}'),
                              IconButton(
                                onPressed: () async =>
                                    ref.read(adminProvider.notifier).removeMenuItem(store.id, item),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove item',
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editStore(context, ref, store),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit store'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () => _removeStore(context, ref, store),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove store',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _editMenuItem(context, ref, store),
                            icon: const Icon(Icons.add),
                            label: const Text('Menu item'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),
      );

  Future<void> _editStore(BuildContext context, WidgetRef ref, [AdminStore? current]) async {
    final name = TextEditingController(text: current?.name);
    final description = TextEditingController(text: current?.description);
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(current == null ? 'Add store' : 'Edit store'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Store name')), const SizedBox(height: 12), TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; await ref.read(adminProvider.notifier).saveStore(AdminStore(id: current?.id ?? 'new-store', name: name.text.trim(), description: description.text.trim(), items: current?.items ?? const [])); if (context.mounted) Navigator.pop(context); }, child: const Text('Save'))]));
    name.dispose(); description.dispose();
  }

  Future<void> _editMenuItem(BuildContext context, WidgetRef ref, AdminStore store, [AdminMenuItem? current]) async {
    final name = TextEditingController(text: current?.name);
    final category = TextEditingController(text: current?.category ?? 'Meals');
    final price = TextEditingController(text: current?.price.toStringAsFixed(0));
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(current == null ? 'Add menu item' : 'Edit menu item'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), const SizedBox(height: 10), TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')), const SizedBox(height: 10), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { final amount = double.tryParse(price.text); if (name.text.trim().isEmpty || amount == null) return; await ref.read(adminProvider.notifier).saveMenuItem(store.id, AdminMenuItem(id: current?.id ?? 'new-item', name: name.text.trim(), category: category.text.trim(), price: amount)); if (context.mounted) Navigator.pop(context); }, child: const Text('Save'))]));
    name.dispose(); category.dispose(); price.dispose();
  }

  Future<void> _removeStore(BuildContext context, WidgetRef ref, AdminStore store) async {
    final reason = TextEditingController();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text('Remove ${store.name}?'), content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Required audit reason')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (reason.text.trim().isEmpty) return; await ref.read(adminProvider.notifier).removeStore(store, reason.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('Remove'))]));
    reason.dispose();
  }
}

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Page(title: 'Orders', subtitle: 'Confirm, assign, review COD, or cancel with an audit reason.', child: _Section(title: 'All orders', child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Order')), DataColumn(label: Text('Customer')), DataColumn(label: Text('Store')), DataColumn(label: Text('Status')), DataColumn(label: Text('COD')), DataColumn(label: Text('Total')), DataColumn(label: Text('Actions'))], rows: data.orders.map((order) => DataRow(cells: [DataCell(Text(order.id)), DataCell(Text(order.customer)), DataCell(Text(order.store)), DataCell(_Chip(order.status.label)), DataCell(Text(order.codPaid ? 'Paid' : 'Unpaid')), DataCell(Text('₱${order.total.toStringAsFixed(0)}')), DataCell(Row(children: [if (order.status == AdminOrderStatus.pending) IconButton(onPressed: () => _assign(context, ref, order), icon: const Icon(Icons.person_add_alt), tooltip: 'Assign rider'), if (order.status != AdminOrderStatus.delivered && order.status != AdminOrderStatus.cancelled) IconButton(onPressed: () => _cancel(context, ref, order), icon: const Icon(Icons.cancel_outlined), tooltip: 'Cancel order')]))])).toList()))));

  Future<void> _assign(BuildContext context, WidgetRef ref, AdminOrder order) async {
    final available = data.riders.where((rider) => rider.status == AdminRiderStatus.available).toList();
    if (available.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No riders are currently available.'))); return; }
    AdminRider selected = available.first;
    final reason = TextEditingController(text: 'Nearest available rider');
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: Text('Assign ${order.id}'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<AdminRider>(initialValue: selected, items: available.map((rider) => DropdownMenuItem(value: rider, child: Text(rider.name))).toList(), onChanged: (value) => setState(() => selected = value!), decoration: const InputDecoration(labelText: 'Rider')), const SizedBox(height: 12), TextField(controller: reason, decoration: const InputDecoration(labelText: 'Audit reason'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { await ref.read(adminProvider.notifier).assign(order.id, selected, reason.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('Assign'))])));
    reason.dispose();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, AdminOrder order) async {
    final reason = TextEditingController();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text('Cancel ${order.id}?'), content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Required audit reason')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep order')), FilledButton(onPressed: () async { if (reason.text.trim().isEmpty) return; await ref.read(adminProvider.notifier).cancel(order.id, reason.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('Cancel order'))]));
    reason.dispose();
  }
}

class RidersPage extends ConsumerWidget {
  const RidersPage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Page(title: 'Riders', subtitle: 'Manage accounts, availability, and active assignments.', actions: [FilledButton.icon(onPressed: () => _create(context, ref), icon: const Icon(Icons.person_add), label: const Text('Create rider'))], child: _Section(title: 'Rider team', child: Column(children: data.riders.map((rider) => ListTile(leading: CircleAvatar(child: Text(rider.name.substring(0, 1))), title: Text(rider.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${rider.phone}${rider.activeDelivery == null ? '' : ' · ${rider.activeDelivery}'}'), trailing: _Chip(rider.status.name))).toList())));

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(); final email = TextEditingController(); final phone = TextEditingController(); final password = TextEditingController();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Create rider account'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')), const SizedBox(height: 10), TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 10), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')), const SizedBox(height: 10), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty || !email.text.contains('@') || password.text.length < 8) return; await ref.read(adminProvider.notifier).saveRider(name: name.text.trim(), email: email.text.trim(), password: password.text, phone: phone.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('Create'))]));
    name.dispose(); email.dispose(); phone.dispose(); password.dispose();
  }
}

class LivePage extends StatelessWidget {
  const LivePage({super.key, required this.data});
  final AdminSnapshot data;
  @override
  Widget build(BuildContext context) {
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
    final positioned = data.deliveries.where((delivery) => delivery.latitude != 0 || delivery.longitude != 0).toList();
    final center = positioned.isEmpty ? const LatLng(7.0731, 125.6128) : LatLng(positioned.first.latitude, positioned.first.longitude);
    final map = Container(
      height: 430,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: const Color(0xFFE6E9E5), borderRadius: BorderRadius.circular(18)),
      child: mapboxToken.isEmpty
          ? CustomPaint(painter: _AdminMapPainter())
          : FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken'),
                MarkerLayer(markers: positioned.map((delivery) => Marker(
                  point: LatLng(delivery.latitude, delivery.longitude),
                  width: 48,
                  height: 48,
                  child: Tooltip(
                    message: '${delivery.rider} · ${delivery.orderId}',
                    child: CircleAvatar(backgroundColor: delivery.stale ? Colors.red : Colors.green, child: const Icon(Icons.delivery_dining, color: Colors.white)),
                  ),
                )).toList()),
              ],
            ),
    );
    final list = _Section(title: 'Active tracking', child: Column(children: data.deliveries.map((delivery) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(delivery.stale ? Icons.location_off : Icons.my_location, color: delivery.stale ? Colors.red : Colors.green), title: Text('${delivery.orderId} · ${delivery.rider}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(delivery.stale ? 'Last update ${DateFormat('h:mm:ss a').format(delivery.updatedAt)} · Stale' : 'Live · updated ${DateTime.now().difference(delivery.updatedAt).inSeconds}s ago'), trailing: _Chip(delivery.status.label))).toList()));
    return _Page(title: 'Live deliveries', subtitle: 'Monitor last-known rider positions and stale updates.', child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth > 880 ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: map), const SizedBox(width: 18), Expanded(flex: 2, child: list)]) : Column(children: [map, const SizedBox(height: 18), list])));
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
    return _Page(title: 'Reports and records', subtitle: 'Filter operational results, export CSV, or print to PDF.', actions: [OutlinedButton.icon(onPressed: () => downloadCsv('mns-orders.csv', csv), icon: const Icon(Icons.download), label: const Text('Export CSV')), const SizedBox(width: 10), FilledButton.icon(onPressed: printReport, icon: const Icon(Icons.print), label: const Text('Print / PDF'))], child: Column(children: [Align(alignment: Alignment.centerLeft, child: SizedBox(width: 260, child: DropdownButtonFormField<AdminOrderStatus?>(initialValue: status, decoration: const InputDecoration(labelText: 'Order status'), items: [const DropdownMenuItem(value: null, child: Text('All statuses')), ...AdminOrderStatus.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label)))], onChanged: (value) => setState(() => status = value)))), const SizedBox(height: 18), _Section(title: 'Order report', child: Column(children: orders.map((order) => ListTile(title: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${order.store} · ${DateFormat('MMM d, h:mm a').format(order.createdAt)}'), trailing: Text('₱${order.total.toStringAsFixed(0)}'))).toList())), const SizedBox(height: 18), _Section(title: 'Customer feedback', child: Column(children: widget.data.feedback.map((entry) => ListTile(leading: CircleAvatar(child: Text('${entry.rating}★')), title: Text('${entry.orderId} · ${entry.customer}'), subtitle: Text(entry.comment), trailing: Text(DateFormat('MMM d').format(entry.createdAt)))).toList())), const SizedBox(height: 18), _Section(title: 'Audit history', child: Column(children: widget.data.audit.map((entry) => ListTile(leading: const Icon(Icons.fact_check_outlined), title: Text('${entry.action} · ${entry.target}'), subtitle: Text('${entry.actor} — ${entry.reason}'), trailing: Text(DateFormat('MMM d, h:mm a').format(entry.createdAt)))).toList()))]));
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon}); final String label; final String value; final IconData icon;
  @override Widget build(BuildContext context) => SizedBox(width: 250, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)), Text(label, style: const TextStyle(color: Colors.black54))])]))));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child}); final String title; final Widget child;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 12), child])));
}

class _Chip extends StatelessWidget {
  const _Chip(this.label); final String label;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(30)), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)));
}

class _AdminMapPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = Colors.white..strokeWidth = 5; for (var i = 1; i < 6; i++) { canvas.drawLine(Offset(0, size.height * i / 6), Offset(size.width, size.height * i / 6), paint); } for (var i = 1; i < 7; i++) { canvas.drawLine(Offset(size.width * i / 7, 0), Offset(size.width * i / 7, size.height), paint); } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
