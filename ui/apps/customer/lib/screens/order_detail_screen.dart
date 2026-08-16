import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:mns_design_system/design_system.dart';
import 'package:mns_domain_models/domain_models.dart' as shared;

import '../models/customer_models.dart';
import '../services/road_route_service.dart';
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
    final effectiveRiderName = (snapshot?.riderName != null && snapshot!.riderName!.isNotEmpty)
        ? snapshot.riderName
        : order.riderName;

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
          _TrackingMap(order: order, snapshot: snapshot, etaMinutes: liveEta, connected: tracking?.hasValue ?? false),
          const SizedBox(height: 16),

          if (active) ...[
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
                      effectiveRiderName?.isNotEmpty == true ? effectiveRiderName!.substring(0, 1).toUpperCase() : 'R',
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
                          effectiveRiderName ?? 'Assigning nearby rider...',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          effectiveRiderName != null ? 'Motorcycle Courier · Verified Fleet' : 'Pending dispatch confirmation',
                          style: TextStyle(
                            color: effectiveRiderName != null ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3E8FF),
                      foregroundColor: const Color(0xFF7C3AED),
                    ),
                    onPressed: () {
                      MnsSnackBar.show(
                        context,
                        title: 'Connecting Call',
                        message: effectiveRiderName != null ? 'Connecting to $effectiveRiderName hotline...' : 'Calling M&S customer support...',
                        type: MnsSnackBarType.info,
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
                            'Help us maintain top-tier service',
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
  List<LatLng>? _roadPoints;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchRoadPoints();
  }

  void _fetchRoadPoints() {
    final destPos = _getCustomerCoordinates();
    final riderPos = _getRiderCoordinates(destPos);
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

    const CustomerRoadRouteService().getRoutePoints(
      origin: riderPos,
      destination: destPos,
      mapboxToken: mapboxToken,
    ).then((points) {
      if (mounted) {
        setState(() => _roadPoints = points);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLat = oldWidget.snapshot?.latitude;
    final newLat = widget.snapshot?.latitude;
    final oldLng = oldWidget.snapshot?.longitude;
    final newLng = widget.snapshot?.longitude;
    if (newLat != null && newLng != null && (oldLat != newLat || oldLng != newLng)) {
      _mapController.move(LatLng(newLat, newLng), _mapController.camera.zoom);
      _fetchRoadPoints();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _getStoreCoordinates(String storeName) {
    if (widget.snapshot?.pickupLatitude != null && widget.snapshot?.pickupLongitude != null) {
      return LatLng(widget.snapshot!.pickupLatitude!, widget.snapshot!.pickupLongitude!);
    }
    final lower = storeName.toLowerCase();
    if (lower.contains('penong')) return const LatLng(7.0235, 125.5015);
    if (lower.contains('jollibee')) return const LatLng(7.0205, 125.4972);
    if (lower.contains('inasal')) return const LatLng(7.0212, 125.4988);
    if (lower.contains('kusina') || lower.contains('dabaw')) return const LatLng(7.0195, 125.4995);
    if (lower.contains('balamban') || lower.contains('liempo')) return const LatLng(7.0188, 125.4965);
    if (lower.contains('chowking')) return const LatLng(7.0208, 125.4978);
    if (lower.contains('kapewe') || lower.contains('cafe')) return const LatLng(7.0175, 125.5030);
    if (lower.contains('dencia')) return const LatLng(7.0220, 125.5020);
    return const LatLng(7.0210, 125.4990);
  }

  LatLng _getCustomerCoordinates() {
    if (widget.snapshot?.destinationLatitude != null && widget.snapshot?.destinationLongitude != null) {
      return LatLng(widget.snapshot!.destinationLatitude!, widget.snapshot!.destinationLongitude!);
    }
    if (widget.order.address.latitude != null && widget.order.address.longitude != null) {
      return LatLng(widget.order.address.latitude!, widget.order.address.longitude!);
    }
    return const LatLng(7.0245, 125.5035);
  }

  LatLng _getRiderCoordinates(LatLng dest) {
    if (widget.snapshot?.latitude != null && widget.snapshot?.longitude != null) {
      return LatLng(widget.snapshot!.latitude!, widget.snapshot!.longitude!);
    }
    if (widget.snapshot?.pickupLatitude != null && widget.snapshot?.pickupLongitude != null) {
      return LatLng(widget.snapshot!.pickupLatitude!, widget.snapshot!.pickupLongitude!);
    }
    final storePos = _getStoreCoordinates(widget.order.store.name);
    final status = widget.snapshot?.status;
    if (status == shared.OrderStatus.delivered) return dest;
    return storePos;
  }

  void _recenter(LatLng pos) {
    _mapController.move(pos, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
    final destPos = _getCustomerCoordinates();
    final riderPos = _getRiderCoordinates(destPos);
    final effectiveRiderName = (widget.snapshot?.riderName != null && widget.snapshot!.riderName!.isNotEmpty)
        ? widget.snapshot!.riderName
        : widget.order.riderName;

    final hasRider = (effectiveRiderName != null && effectiveRiderName.isNotEmpty) &&
        (widget.snapshot?.status == shared.OrderStatus.assigned ||
            widget.snapshot?.status == shared.OrderStatus.pickedUp ||
            widget.snapshot?.status == shared.OrderStatus.onTheWay ||
            widget.snapshot?.status == shared.OrderStatus.delivered ||
            widget.order.stage == OrderStage.assigned ||
            widget.order.stage == OrderStage.pickedUp ||
            widget.order.stage == OrderStage.onTheWay ||
            widget.order.stage == OrderStage.delivered);

    if (!hasRider) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF7C3AED), size: 26),
            ),
            const SizedBox(height: 12),
            const Text(
              'Finding your delivery rider...',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Your order at ${widget.order.store.name} is confirmed. Map & GPS directions will activate once a rider is assigned.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Looking for available couriers nearby',
                    style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
                      ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mns.delivery.customer',
                ),

                // Direction Route Polyline (Rider to Customer Destination)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _roadPoints ?? [riderPos, destPos],
                      strokeWidth: 8,
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    ),
                    Polyline(
                      points: _roadPoints ?? [riderPos, destPos],
                      strokeWidth: 4,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),

                // Markers (Rider Location & Customer Destination)
                MarkerLayer(
                  markers: [
                    // 1. Rider Marker
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

                    // 2. Customer Destination Marker
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

          // Top Left: Live Status Badge (White Theme)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
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
                    widget.connected ? 'LIVE GPS STREAM' : 'TRACKING FLEET',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),

          // Top Right: Actions (Recenter + Fullscreen in White Theme)
          Positioned(
            right: 12,
            top: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: const Color(0x14000000),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _recenter(riderPos),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.my_location_rounded, size: 19, color: Color(0xFF7C3AED)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: const Color(0x14000000),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenCustomerMapScreen(
                            order: widget.order,
                            snapshot: widget.snapshot,
                            etaMinutes: widget.etaMinutes,
                            connected: widget.connected,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.fullscreen_rounded, size: 19, color: Color(0xFF7C3AED)),
                    ),
                  ),
                ),
              ],
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
                          effectiveRiderName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          '🏍️ Motorcycle Courier · Verified',
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

class FullScreenCustomerMapScreen extends StatefulWidget {
  const FullScreenCustomerMapScreen({
    super.key,
    required this.order,
    required this.snapshot,
    required this.etaMinutes,
    required this.connected,
  });

  final CustomerOrder order;
  final shared.DeliverySnapshot? snapshot;
  final int etaMinutes;
  final bool connected;

  @override
  State<FullScreenCustomerMapScreen> createState() => _FullScreenCustomerMapScreenState();
}

class _FullScreenCustomerMapScreenState extends State<FullScreenCustomerMapScreen> {
  late final MapController _mapController;
  List<LatLng>? _roadPoints;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchRoadPoints();
  }

  void _fetchRoadPoints() {
    final destPos = _getCustomerCoordinates();
    final riderPos = _getRiderCoordinates(destPos);
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

    const CustomerRoadRouteService().getRoutePoints(
      origin: riderPos,
      destination: destPos,
      mapboxToken: mapboxToken,
    ).then((points) {
      if (mounted) {
        setState(() => _roadPoints = points);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _getStoreCoordinates(String storeName) {
    if (widget.snapshot?.pickupLatitude != null && widget.snapshot?.pickupLongitude != null) {
      return LatLng(widget.snapshot!.pickupLatitude!, widget.snapshot!.pickupLongitude!);
    }
    final lower = storeName.toLowerCase();
    if (lower.contains('penong')) return const LatLng(7.0235, 125.5015);
    if (lower.contains('jollibee')) return const LatLng(7.0205, 125.4972);
    if (lower.contains('inasal')) return const LatLng(7.0212, 125.4988);
    if (lower.contains('kusina') || lower.contains('dabaw')) return const LatLng(7.0195, 125.4995);
    if (lower.contains('balamban') || lower.contains('liempo')) return const LatLng(7.0188, 125.4965);
    if (lower.contains('chowking')) return const LatLng(7.0208, 125.4978);
    if (lower.contains('kapewe') || lower.contains('cafe')) return const LatLng(7.0175, 125.5030);
    if (lower.contains('dencia')) return const LatLng(7.0220, 125.5020);
    return const LatLng(7.0210, 125.4990);
  }

  LatLng _getCustomerCoordinates() {
    if (widget.snapshot?.destinationLatitude != null && widget.snapshot?.destinationLongitude != null) {
      return LatLng(widget.snapshot!.destinationLatitude!, widget.snapshot!.destinationLongitude!);
    }
    if (widget.order.address.latitude != null && widget.order.address.longitude != null) {
      return LatLng(widget.order.address.latitude!, widget.order.address.longitude!);
    }
    return const LatLng(7.0245, 125.5035);
  }

  LatLng _getRiderCoordinates(LatLng dest) {
    if (widget.snapshot?.latitude != null && widget.snapshot?.longitude != null) {
      return LatLng(widget.snapshot!.latitude!, widget.snapshot!.longitude!);
    }
    if (widget.snapshot?.pickupLatitude != null && widget.snapshot?.pickupLongitude != null) {
      return LatLng(widget.snapshot!.pickupLatitude!, widget.snapshot!.pickupLongitude!);
    }
    final storePos = _getStoreCoordinates(widget.order.store.name);
    final status = widget.snapshot?.status;
    if (status == shared.OrderStatus.delivered) return dest;
    return storePos;
  }

  void _recenter(LatLng pos) {
    _mapController.move(pos, 15.2);
  }

  @override
  Widget build(BuildContext context) {
    const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
    final destPos = _getCustomerCoordinates();
    final riderPos = _getRiderCoordinates(destPos);
    final effectiveRiderName = (widget.snapshot?.riderName != null && widget.snapshot!.riderName!.isNotEmpty)
        ? widget.snapshot!.riderName
        : widget.order.riderName;

    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen Map Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: riderPos,
                initialZoom: 14.8,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: mapboxToken.isNotEmpty
                      ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mns.delivery.customer',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _roadPoints ?? [riderPos, destPos],
                      strokeWidth: 9,
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
                    ),
                    Polyline(
                      points: _roadPoints ?? [riderPos, destPos],
                      strokeWidth: 4.5,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: riderPos,
                      width: 56,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                              blurRadius: 16,
                              spreadRadius: 3,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    Marker(
                      point: destPos,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [BoxShadow(color: Color(0x0E000000), blurRadius: 8, offset: Offset(0, 2))],
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
                            widget.connected ? 'LIVE GPS STREAM' : 'TRACKING FLEET',
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: const Color(0x14000000),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _recenter(riderPos),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Floating HUD Sheet
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x16000000), blurRadius: 20, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF7C3AED),
                          child: Text(
                            effectiveRiderName?.isNotEmpty == true ? effectiveRiderName!.substring(0, 1).toUpperCase() : 'R',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                effectiveRiderName ?? 'Assigning nearby rider...',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                effectiveRiderName != null ? '🏍️ Motorcycle Courier · Verified Driver' : 'Pending dispatch confirmation',
                                style: TextStyle(
                                  color: effectiveRiderName != null ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            '${widget.etaMinutes} mins ETA',
                            style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.order.store.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        const Icon(Icons.home_rounded, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.snapshot?.deliveryAddress.isNotEmpty == true ? widget.snapshot!.deliveryAddress : widget.order.address.address,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
