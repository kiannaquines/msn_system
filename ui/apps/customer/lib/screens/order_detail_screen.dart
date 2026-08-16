import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:mns_domain_models/domain_models.dart' as shared;

import '../models/customer_models.dart';
import '../state/customer_state.dart';
import '../state/tracking_state.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = order.deliveryId == null ? null : ref.watch(trackingDeliveryProvider(order.deliveryId!));
    final snapshot = tracking?.asData?.value;
    final stage = snapshot == null ? order.stage : _stage(snapshot.status);
    final active = !stage.isComplete;
    final liveEta = snapshot?.etaMinutes ?? order.etaMinutes;
    return Scaffold(
      appBar: AppBar(title: Text(active ? 'Track order' : 'Order receipt')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (active) ...[
          _TrackingMap(order: order, snapshot: snapshot, etaMinutes: liveEta, connected: tracking?.hasValue ?? false),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [CircleAvatar(radius: 26, child: Text(order.riderName?.substring(0, 1) ?? 'R')), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Your rider', style: TextStyle(color: Colors.black54)), Text(order.riderName ?? 'Assigning a rider', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))])), IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.call_outlined), tooltip: 'Call rider')]))),
          const SizedBox(height: 24),
          Text('Order progress', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: _OrderTimeline(current: stage))),
          const SizedBox(height: 24),
        ],
        Text('Receipt', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(order.store.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))), _StatusTag(label: stage.label)]),
          const SizedBox(height: 4),
          Text('${order.id} · ${DateFormat('MMM d, yyyy · h:mm a').format(order.createdAt)}', style: const TextStyle(color: Colors.black54)),
          const Divider(height: 28),
          if (order.lines.isEmpty) const Text('Previous order items') else ...order.lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Text('${line.quantity}×'), const SizedBox(width: 10), Expanded(child: Text(line.item.name)), Text('₱${line.total.toStringAsFixed(0)}')]))),
          const Divider(height: 24),
          _ReceiptRow(label: 'Subtotal', value: order.subtotal),
          const SizedBox(height: 8),
          _ReceiptRow(label: 'Delivery fee', value: order.deliveryFee),
          const Divider(height: 24),
          _ReceiptRow(label: 'Cash on delivery total', value: order.total, strong: true),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.location_on_outlined, size: 20), const SizedBox(width: 8), Expanded(child: Text('${order.address.label} · ${order.address.address}'))]),
        ]))),
        const SizedBox(height: 20),
        if (stage == OrderStage.delivered) OutlinedButton.icon(onPressed: () => _showFeedback(context, ref), icon: const Icon(Icons.star_outline), label: const Text('Rate this delivery')),
      ]),
    );
  }

  OrderStage _stage(shared.OrderStatus status) => switch (status) {
        shared.OrderStatus.pending => OrderStage.pending,
        shared.OrderStatus.confirmed => OrderStage.confirmed,
        shared.OrderStatus.assigned => OrderStage.assigned,
        shared.OrderStatus.pickedUp => OrderStage.pickedUp,
        shared.OrderStatus.onTheWay => OrderStage.onTheWay,
        shared.OrderStatus.delivered => OrderStage.delivered,
        shared.OrderStatus.cancelled => OrderStage.cancelled,
      };

  Future<void> _showFeedback(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final comment = TextEditingController();
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Rate your delivery'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) => IconButton(onPressed: () => setState(() => rating = index + 1), icon: Icon(index < rating ? Icons.star : Icons.star_outline, color: const Color(0xFFF5A623)), tooltip: 'Rate ${index + 1} stars'))), const SizedBox(height: 12), TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(labelText: 'Tell us more (optional)'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { await ref.read(customerRepositoryProvider).submitFeedback(order.id, rating, comment.text); if (context.mounted) Navigator.pop(context); }, child: const Text('Submit'))],
    )));
    comment.dispose();
  }
}

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.order, required this.snapshot, required this.etaMinutes, required this.connected});
  final CustomerOrder order;
  final shared.DeliverySnapshot? snapshot;
  final int etaMinutes;
  final bool connected;
  @override
  Widget build(BuildContext context) {
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
    final rider = snapshot?.latitude == null || snapshot?.longitude == null ? null : LatLng(snapshot!.latitude!, snapshot!.longitude!);
    final destination = snapshot?.destinationLatitude == null || snapshot?.destinationLongitude == null ? null : LatLng(snapshot!.destinationLatitude!, snapshot!.destinationLongitude!);
    return Container(
    height: 230,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: const Color(0xFFE5EAE4), borderRadius: BorderRadius.circular(22)),
    child: Stack(children: [
      Positioned.fill(child: rider == null || mapboxToken.isEmpty
          ? CustomPaint(painter: _MapPainter(color: Theme.of(context).colorScheme.primary))
          : FlutterMap(
              options: MapOptions(initialCenter: rider, initialZoom: 14),
              children: [
                TileLayer(urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken'),
                if (destination != null) PolylineLayer(polylines: [Polyline(points: [rider, destination], strokeWidth: 5, color: Theme.of(context).colorScheme.primary)]),
                MarkerLayer(markers: [Marker(point: rider, width: 44, height: 44, child: const CircleAvatar(child: Icon(Icons.delivery_dining))), if (destination != null) Marker(point: destination, width: 44, height: 44, child: const CircleAvatar(child: Icon(Icons.home)))]),
              ],
            )),
      Positioned(left: 0, right: 0, bottom: 14, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)]), child: Text('${order.riderName ?? 'Your rider'} · $etaMinutes min away${connected ? ' · Live' : ''}', style: const TextStyle(fontWeight: FontWeight.w800))))),
    ]),
  );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = Colors.white..strokeWidth = 14..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final route = Paint()..color = color..strokeWidth = 5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(48, 58)..cubicTo(size.width * .30, size.height * .15, size.width * .58, size.height * .80, size.width - 52, size.height - 58);
    canvas.drawPath(path, road);
    canvas.drawPath(path, route);
  }
  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => oldDelegate.color != color;
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.current});
  final OrderStage current;
  @override
  Widget build(BuildContext context) {
    const stages = [OrderStage.pending, OrderStage.confirmed, OrderStage.assigned, OrderStage.pickedUp, OrderStage.onTheWay, OrderStage.delivered];
    final currentIndex = stages.indexOf(current);
    return Column(children: List.generate(stages.length, (index) {
      final done = current != OrderStage.cancelled && index <= currentIndex;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Column(children: [Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? const Color(0xFF16845B) : Colors.black26), if (index < stages.length - 1) Container(width: 2, height: 30, color: done && index < currentIndex ? const Color(0xFF16845B) : Colors.black12)]), const SizedBox(width: 12), Padding(padding: const EdgeInsets.only(top: 2), child: Text(stages[index].label, style: TextStyle(fontWeight: done ? FontWeight.w700 : FontWeight.normal, color: done ? Colors.black87 : Colors.black45)))]);
    }));
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(30)), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.strong = false});
  final String label;
  final double value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: strong ? const TextStyle(fontWeight: FontWeight.w800) : null), Text('₱${value.toStringAsFixed(0)}', style: strong ? const TextStyle(fontWeight: FontWeight.w800) : null)]);
}
