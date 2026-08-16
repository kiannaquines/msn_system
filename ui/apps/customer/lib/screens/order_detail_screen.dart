import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
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
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          active ? 'Live Order Tracking' : 'Order Receipt',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (active) ...[
            _TrackingMap(order: order, snapshot: snapshot, etaMinutes: liveEta, connected: tracking?.hasValue ?? false),
            const SizedBox(height: 16),

            // Rider Detail Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF7C3AED),
                    child: Text(
                      order.riderName?.isNotEmpty == true ? order.riderName!.substring(0, 1).toUpperCase() : 'R',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assigned Rider', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          order.riderName ?? 'Assigning nearby rider...',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text('Motorcycle Courier · Kabacan Fleet', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3E8FF),
                      foregroundColor: const Color(0xFF7C3AED),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Calling rider hotline...'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    icon: const Icon(Icons.call_rounded, size: 20),
                    tooltip: 'Call rider',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Progress Timeline Card
            const Text('Delivery Progress', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _OrderTimeline(current: stage),
            ),
            const SizedBox(height: 24),
          ],

          // Order Details & Receipt
          const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.store.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                      ),
                    ),
                    _StatusTag(label: stage.label, isComplete: stage.isComplete),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '#${order.id.substring(0, 8)} · ${DateFormat('MMM d, yyyy · h:mm a').format(order.createdAt)}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),

                if (order.lines.isEmpty)
                  const Text('Order details processing...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                else
                  ...order.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            child: Text('${line.quantity}×', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                          ),
                          Text('₱${line.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _ReceiptRow(label: 'Items Subtotal', value: order.subtotal),
                const SizedBox(height: 8),
                _ReceiptRow(label: 'Delivery Fee', value: order.deliveryFee),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _ReceiptRow(label: 'Cash on Delivery Total', value: order.total, strong: true),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${order.address.label} · ${order.address.address}',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (stage == OrderStage.delivered) ...[
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showFeedback(context, ref),
                icon: const Icon(Icons.star_rounded),
                label: const Text('Rate this delivery', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Return to Home CTA
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Back to Home',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _FeedbackDialog(orderId: order.id),
    );
  }
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog({required this.orderId});
  final String orderId;

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  int _rating = 5;
  late final TextEditingController _comment;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _comment = TextEditingController();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(customerRepositoryProvider).submitFeedback(widget.orderId, _rating, _comment.text);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E142F),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate Your Delivery',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Help us maintain top-tier service in Kabacan',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text('How was your order experience?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          onPressed: () => setState(() => _rating = index + 1),
                          icon: Icon(
                            index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: const Color(0xFFF59E0B),
                            size: 36,
                          ),
                          tooltip: 'Rate ${index + 1} stars',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _comment,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Feedback or Comments (Optional)',
                        hintText: 'e.g. Food was hot and delivered on time!',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.w800)),
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
    );
  }
}

class _TrackingMap extends StatefulWidget {
  const _TrackingMap({required this.order, required this.snapshot, required this.etaMinutes, required this.connected});
  final CustomerOrder order;
  final shared.DeliverySnapshot? snapshot;
  final int etaMinutes;
  final bool connected;

  @override
  State<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<_TrackingMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _getStoreCoordinates(String storeName) {
    final lower = storeName.toLowerCase();
    if (lower.contains('penong')) return const LatLng(7.1125, 124.8285);
    if (lower.contains('mcmillan')) return const LatLng(7.1082, 124.8210);
    if (lower.contains('bogs')) return const LatLng(7.1070, 124.8250);
    if (lower.contains('love bite')) return const LatLng(7.1095, 124.8240);
    if (lower.contains('pastil')) return const LatLng(7.1055, 124.8195);
    if (lower.contains('jollibee')) return const LatLng(7.1105, 124.8260);
    if (lower.contains('macchiato')) return const LatLng(7.1068, 124.8215);
    return const LatLng(7.1086, 124.8235);
  }

  LatLng _getCustomerCoordinates() {
    if (widget.order.address.latitude != null && widget.order.address.longitude != null) {
      return LatLng(widget.order.address.latitude!, widget.order.address.longitude!);
    }
    return const LatLng(7.1066, 124.8292);
  }

  LatLng _getRiderCoordinates(LatLng store, LatLng dest) {
    if (widget.snapshot?.latitude != null && widget.snapshot?.longitude != null) {
      return LatLng(widget.snapshot!.latitude!, widget.snapshot!.longitude!);
    }
    return LatLng(
      (store.latitude + dest.latitude) / 2 + 0.0008,
      (store.longitude + dest.longitude) / 2 - 0.0005,
    );
  }

  void _recenter(LatLng pos) {
    _mapController.move(pos, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
    final storePos = _getStoreCoordinates(widget.order.store.name);
    final destPos = _getCustomerCoordinates();
    final riderPos = _getRiderCoordinates(storePos, destPos);

    return Container(
      height: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          // Map Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: riderPos,
                initialZoom: 14.6,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: mapboxToken.isNotEmpty
                      ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}@2x?access_token=$mapboxToken'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mns.delivery.customer',
                ),

                // Glow Route
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [storePos, riderPos, destPos],
                      strokeWidth: 8,
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    ),
                    Polyline(
                      points: [storePos, riderPos, destPos],
                      strokeWidth: 4,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),

                // Markers
                MarkerLayer(
                  markers: [
                    // 1. Store Marker
                    Marker(
                      point: storePos,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                      ),
                    ),

                    // 2. Rider Marker
                    Marker(
                      point: riderPos,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 26),
                      ),
                    ),

                    // 3. Customer Destination Marker
                    Marker(
                      point: destPos,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Top Left: Live Status Badge
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E142F).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.connected ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.connected ? 'LIVE GPS · KABACAN' : 'TRACKING FLEET',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),

          // Top Right: Recenter Camera Button
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _recenter(riderPos),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF0F172A)),
                ),
              ),
            ),
          ),

          // Bottom: Rider HUD Card
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.order.riderName ?? 'Kabacan Fleet Courier',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Dispatched via Motorcycle',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '${widget.etaMinutes} mins ETA',
                      style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
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

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.current});
  final OrderStage current;

  @override
  Widget build(BuildContext context) {
    const stages = [
      OrderStage.pending,
      OrderStage.confirmed,
      OrderStage.assigned,
      OrderStage.pickedUp,
      OrderStage.onTheWay,
      OrderStage.delivered,
    ];
    final currentIndex = stages.indexOf(current);

    return Column(
      children: List.generate(stages.length, (index) {
        final done = current != OrderStage.cancelled && index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: done ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                  size: 20,
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 2,
                    height: 28,
                    color: done && index < currentIndex ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Text(
                    stages[index].label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w900 : (done ? FontWeight.w700 : FontWeight.w500),
                      fontSize: 13,
                      color: isCurrent ? const Color(0xFF0F172A) : (done ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                    ),
                  ),
                  if (isCurrent && current != OrderStage.delivered && current != OrderStage.cancelled) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(4)),
                      child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.isComplete});
  final String label;
  final bool isComplete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isComplete ? const Color(0xFFECFDF5) : const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isComplete ? const Color(0xFF047857) : const Color(0xFF7C3AED),
          ),
        ),
      );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.strong = false});
  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontSize: strong ? 15 : 13,
              color: strong ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            '₱${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              fontSize: strong ? 16 : 13,
              color: strong ? const Color(0xFF7C3AED) : const Color(0xFF0F172A),
            ),
          ),
        ],
      );
}
