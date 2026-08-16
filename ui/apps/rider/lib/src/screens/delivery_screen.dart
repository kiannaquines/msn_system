import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mns_design_system/design_system.dart';
import 'package:mns_domain_models/domain_models.dart';
import 'package:mns_rider/src/config.dart';
import 'package:mns_rider/src/services/mapbox_route_service.dart';
import 'package:mns_rider/src/services/tracking_service.dart';
import 'package:mns_rider/src/state/rider_controller.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  Future<RoutePlan?>? _route;
  bool _hasShownAlmostTherePopup = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderControllerProvider);
    final matching = state.deliveries.where((d) => d.id == widget.deliveryId);
    if (matching.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Delivery Details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ),
        body: const Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Delivery unavailable',
            message: 'Refresh your assignments and try again.',
          ),
        ),
      );
    }
    final delivery = matching.first;
    _route ??= _loadRoute(delivery);
    final trackingThis = state.trackingDeliveryId == delivery.id;

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
        title: Text(
          'Order #${_shortId(delivery.orderId)}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            tooltip: 'Call dispatch hotline',
            icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF64748B)),
            onPressed: () {
              MnsSnackBar.show(
                context,
                title: 'Dispatch Operations',
                message: 'Connecting to Kabacan Dispatch Hotline...',
                type: MnsSnackBarType.info,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Live GPS Status Banner
          _ModernTrackingStatus(tracking: trackingThis, queued: state.pendingEvents),
          const SizedBox(height: 16),

          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Interactive Map Card
          _ModernRouteCard(
            delivery: delivery,
            route: _route!,
            onOpenAlmostThere: (delivery.status == OrderStatus.assigned ||
                    delivery.status == OrderStatus.pickedUp ||
                    delivery.status == OrderStatus.onTheWay)
                ? () => _showAlmostThereModal(context, delivery, 180)
                : null,
          ),
          const SizedBox(height: 16),

          // Order Customer & Store Details Card
          _ModernDeliveryDetails(delivery: delivery),
          const SizedBox(height: 16),

          // Step-by-Step Delivery Actions
          _ModernActionCard(
            delivery: delivery,
            tracking: trackingThis,
            onTrackingChanged: () => _toggleTracking(delivery, trackingThis),
            onConfirmCash: () => _confirmCash(delivery),
            onAdvance: () => _advance(delivery),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<RoutePlan?> _loadRoute(DeliverySnapshot delivery) async {
    LatLng? currentRiderLocation;
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        currentRiderLocation = LatLng(position.latitude, position.longitude);
      }
    } catch (_) {}

    final storePoint = delivery.pickupLatitude != null && delivery.pickupLongitude != null
        ? LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!)
        : const LatLng(7.0210, 125.4990);
    final dropoffPoint = delivery.destinationLatitude != null && delivery.destinationLongitude != null
        ? LatLng(delivery.destinationLatitude!, delivery.destinationLongitude!)
        : const LatLng(7.0280, 125.5030);

    // Direction dynamically originates from Rider's Current GPS Location!
    LatLng origin;
    LatLng destination;

    if (delivery.status == OrderStatus.assigned) {
      origin = currentRiderLocation ?? LatLng(storePoint.latitude - 0.006, storePoint.longitude - 0.006);
      destination = storePoint;
    } else {
      origin = currentRiderLocation ?? storePoint;
      destination = dropoffPoint;
    }

    final plan = await const MapboxRouteService().loadRoute(origin, destination);

    // If order is active and rider is almost there (<= 350 meters remaining), show proximity arrival pop-up
    final isActiveOrder = delivery.status == OrderStatus.assigned ||
        delivery.status == OrderStatus.pickedUp ||
        delivery.status == OrderStatus.onTheWay;

    if (isActiveOrder && plan != null && mounted) {
      final remainingMeters = plan.distanceKm * 1000;
      if (remainingMeters <= 350 && !_hasShownAlmostTherePopup) {
        _hasShownAlmostTherePopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlmostThereModal(context, delivery, remainingMeters);
        });
      }
    }

    return plan;
  }

  void _showAlmostThereModal(BuildContext context, DeliverySnapshot delivery, double distanceMeters) {
    if (delivery.status == OrderStatus.delivered || delivery.status == OrderStatus.cancelled) {
      return;
    }
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final isPickup = delivery.status == OrderStatus.assigned;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Color(0x22000000), blurRadius: 28, offset: Offset(0, -8)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),

              // Animated Target Pulse Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isPickup ? const Color(0xFFF3E8FF) : const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPickup ? const Color(0xFFC084FC) : const Color(0xFF34D399),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isPickup ? const Color(0xFF7C3AED) : const Color(0xFF10B981)).withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isPickup ? Icons.storefront_rounded : Icons.home_rounded,
                    color: isPickup ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Proximity Distance Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 5),
                        Text(
                          distanceMeters <= 50 ? 'ARRIVING NOW' : '${distanceMeters.toStringAsFixed(0)} METERS AWAY',
                          style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                isPickup ? "You're Almost at the Store! 🎯" : "You're Almost at Drop-off! 🎯",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isPickup
                    ? 'Approaching ${delivery.storeName.isNotEmpty ? delivery.storeName : "Merchant Store"}. Get ready to collect and inspect Order #${_shortId(delivery.orderId)}.'
                    : 'Approaching customer ${delivery.customerName.isNotEmpty ? delivery.customerName : "Recipient"} at ${delivery.deliveryAddress.isNotEmpty ? delivery.deliveryAddress : "Delivery Address"}. Prepare ${currency.format(delivery.total)} COD collection.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isPickup ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _advance(delivery);
                      },
                      icon: Icon(isPickup ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded, size: 18),
                      label: Text(
                        isPickup ? 'Mark Picked Up' : 'Proceed to Deliver',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTracking(DeliverySnapshot delivery, bool tracking) async {
    final controller = ref.read(riderControllerProvider.notifier);
    if (tracking) {
      await controller.stopTracking();
      return;
    }
    final result = await controller.startTracking(delivery);
    if (!mounted || result == TrackingPermissionState.ready) return;
    final message = result == TrackingPermissionState.servicesDisabled
        ? 'Turn on device location before starting tracking.'
        : 'Allow location access before starting tracking.';
    MnsSnackBar.show(context, title: 'Location Permission', message: message, type: MnsSnackBarType.warning);
  }

  Future<bool?> _confirmCash(DeliverySnapshot delivery) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, -6)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                ),
                child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 36),
              ),
              const SizedBox(height: 16),

              const Text(
                'Confirm COD Cash Collection',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Order #${_shortId(delivery.orderId)} · ${delivery.customerName.isNotEmpty ? delivery.customerName : 'Customer'}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL CASH TO COLLECT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(delivery.total),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Instructions Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF64748B), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ensure you have physically received the exact cash payment before marking this as paid.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Not Yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('✓ Cash Received', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(riderControllerProvider.notifier).confirmCash(delivery);
      if (mounted) {
        MnsSnackBar.show(
          context,
          title: 'Cash Payment Collected',
          message: '${NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(delivery.total)} COD confirmed.',
          type: MnsSnackBarType.success,
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _advance(DeliverySnapshot delivery) async {
    if (delivery.status == OrderStatus.onTheWay && delivery.paymentStatus != PaymentStatus.paid) {
      final confirmed = await _confirmCash(delivery);
      if (confirmed != true) return;
    }
    await ref.read(riderControllerProvider.notifier).advanceDelivery(delivery);
  }
}

class _ModernTrackingStatus extends StatelessWidget {
  const _ModernTrackingStatus({required this.tracking, required this.queued});
  final bool tracking;
  final int queued;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tracking ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tracking ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tracking ? const Color(0xFF10B981) : const Color(0xFF64748B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tracking ? Icons.my_location_rounded : Icons.location_disabled_rounded,
              color: tracking ? Colors.white : const Color(0xFF64748B),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking ? 'Live GPS Broadcast Active' : 'GPS Broadcast Standby',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: tracking ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  tracking ? 'Broadcasting live courier coordinates to dispatch & customer' : 'Tap start delivery to begin transmitting coordinates',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          if (queued > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(12)),
              child: Text('$queued queued', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

LatLng _interpolateRoutePoint(List<LatLng> points, double t) {
  if (points.isEmpty) return const LatLng(0, 0);
  if (points.length == 1) return points.first;
  final lengths = <double>[];
  double totalLength = 0;
  for (var i = 0; i < points.length - 1; i++) {
    final dist = math.sqrt(
      math.pow(points[i + 1].latitude - points[i].latitude, 2) +
      math.pow(points[i + 1].longitude - points[i].longitude, 2),
    );
    lengths.add(dist);
    totalLength += dist;
  }
  if (totalLength == 0) return points.first;
  final targetDist = (t % 1.0) * totalLength;
  double accumulated = 0;
  for (var i = 0; i < lengths.length; i++) {
    if (accumulated + lengths[i] >= targetDist) {
      final segT = (targetDist - accumulated) / lengths[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      return LatLng(
        p1.latitude + (p2.latitude - p1.latitude) * segT,
        p1.longitude + (p2.longitude - p1.longitude) * segT,
      );
    }
    accumulated += lengths[i];
  }
  return points.last;
}

class _ModernRouteCard extends StatefulWidget {
  const _ModernRouteCard({
    required this.delivery,
    required this.route,
    this.onOpenAlmostThere,
  });
  final DeliverySnapshot delivery;
  final Future<RoutePlan?> route;
  final VoidCallback? onOpenAlmostThere;

  @override
  State<_ModernRouteCard> createState() => _ModernRouteCardState();
}

class _ModernRouteCardState extends State<_ModernRouteCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: FutureBuilder<RoutePlan?>(
        future: widget.route,
        builder: (context, snapshot) {
          final plan = snapshot.data;
          final pickup = widget.delivery.pickupLatitude != null && widget.delivery.pickupLongitude != null
              ? LatLng(widget.delivery.pickupLatitude!, widget.delivery.pickupLongitude!)
              : const LatLng(7.1125, 124.8285);
          final destination = widget.delivery.destinationLatitude != null && widget.delivery.destinationLongitude != null
              ? LatLng(widget.delivery.destinationLatitude!, widget.delivery.destinationLongitude!)
              : const LatLng(7.1066, 124.8292);
          final points = plan != null ? plan.points : [pickup, destination];

          return AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final movingPoint = _interpolateRoutePoint(points, _anim.value);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 240,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FlutterMap(
                            options: MapOptions(initialCenter: pickup, initialZoom: 14.2),
                            children: [
                              TileLayer(
                                urlTemplate: AppConfig.mapboxPublicToken.isNotEmpty
                                    ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxPublicToken}'
                                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.mns.rider',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: points,
                                    strokeWidth: 8,
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                  ),
                                  Polyline(
                                    points: points,
                                    strokeWidth: 4,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  // Store Pin (Solid Purple)
                                  Marker(
                                    point: pickup,
                                    width: 42,
                                    height: 42,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  // Customer Pin (Solid Emerald)
                                  Marker(
                                    point: destination,
                                    width: 42,
                                    height: 42,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  // Animated Traveling Courier Indicator (Slow/Normal animation)
                                  if (points.isNotEmpty)
                                    Marker(
                                      point: movingPoint,
                                      width: 38,
                                      height: 38,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.5),
                                          boxShadow: const [
                                            BoxShadow(color: Color(0x667C3AED), blurRadius: 10, spreadRadius: 2),
                                          ],
                                        ),
                                        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Top-Left Floating Live Status Pill
                        Positioned(
                          top: 12,
                          left: 12,
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
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  plan != null
                                      ? 'LIVE ROUTE · ${plan.distanceKm.toStringAsFixed(1)} KM'
                                      : 'LIVE GPS PATH',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Top-Right Fullscreen Expand Button (White Theme)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
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
                                    builder: (_) => FullScreenRiderMapScreen(
                                      delivery: widget.delivery,
                                      route: widget.route,
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
                                child: const Icon(Icons.fullscreen_rounded, color: Color(0xFF7C3AED), size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Info & Navigation Trigger Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                widget.delivery.status == OrderStatus.assigned
                                    ? Icons.storefront_rounded
                                    : Icons.two_wheeler_rounded,
                                color: const Color(0xFF7C3AED),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.delivery.status == OrderStatus.delivered
                                        ? 'Order Delivered Successfully 🎉'
                                        : widget.delivery.status == OrderStatus.cancelled
                                            ? 'Delivery Cancelled'
                                            : widget.delivery.status == OrderStatus.assigned
                                                ? 'Head to Store for Pickup'
                                                : 'Proceed to Customer Drop-off',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.delivery.status == OrderStatus.delivered
                                        ? 'Drop-off completed at ${widget.delivery.deliveryAddress}'
                                        : plan == null
                                            ? 'Direct navigation guidance'
                                            : '${plan.distanceKm.toStringAsFixed(1)} km · Est. ${plan.durationMinutes} mins · Optimized Path',
                                    style: TextStyle(
                                      color: widget.delivery.status == OrderStatus.delivered
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF059669),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.onOpenAlmostThere != null) ...[
                              InkWell(
                                onTap: widget.onOpenAlmostThere,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFCD34D)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.near_me_rounded, size: 13, color: Color(0xFFD97706)),
                                      SizedBox(width: 4),
                                      Text('🎯 Near', style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenRiderMapScreen(
                                    delivery: widget.delivery,
                                    route: widget.route,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            label: const Text('Start Turn-by-Turn Directions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ModernDeliveryDetails extends StatelessWidget {
  const _ModernDeliveryDetails({required this.delivery});
  final DeliverySnapshot delivery;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
                  delivery.storeName.isEmpty ? 'M&S Partner Store' : delivery.storeName,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  delivery.status.label.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          _InfoRow(
            icon: Icons.person_outline_rounded,
            title: 'Customer Name',
            value: delivery.customerName.isEmpty ? 'Customer' : delivery.customerName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_outlined,
            title: 'Drop-off Address',
            value: delivery.deliveryAddress.isEmpty ? 'Toril, Davao City' : delivery.deliveryAddress,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.payments_outlined,
            title: 'COD Cash Collection',
            value: currency.format(delivery.total),
            isHighlighted: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.isHighlighted = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isHighlighted ? const Color(0xFF10B981) : const Color(0xFF7C3AED)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isHighlighted ? 15 : 13,
                  color: isHighlighted ? const Color(0xFF047857) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernActionCard extends StatelessWidget {
  const _ModernActionCard({
    required this.delivery,
    required this.tracking,
    required this.onTrackingChanged,
    required this.onConfirmCash,
    required this.onAdvance,
  });

  final DeliverySnapshot delivery;
  final bool tracking;
  final VoidCallback onTrackingChanged;
  final VoidCallback onConfirmCash;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final trackable = delivery.status == OrderStatus.pickedUp || delivery.status == OrderStatus.onTheWay;
    final nextLabel = switch (delivery.status) {
      OrderStatus.assigned => 'Confirm Pickup from Store',
      OrderStatus.pickedUp => 'Start Delivery (On The Way)',
      OrderStatus.onTheWay => 'Complete Delivery & Collect COD',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Courier Workflow Actions',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          // Primary Step Action Button (Solid)
          if (nextLabel != null) ...[
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onAdvance,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(nextLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Toggle GPS Tracking Button
          if (trackable) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: tracking ? const Color(0xFFDC2626) : const Color(0xFF059669),
                side: BorderSide(color: tracking ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onTrackingChanged,
              icon: Icon(tracking ? Icons.location_off_rounded : Icons.my_location_rounded, size: 18),
              label: Text(
                tracking ? 'Pause GPS Sharing' : 'Resume GPS Broadcast',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Cash Confirmation Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: delivery.paymentStatus == PaymentStatus.paid ? const Color(0xFF059669) : const Color(0xFF0F172A),
              side: BorderSide(color: delivery.paymentStatus == PaymentStatus.paid ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: delivery.paymentStatus == PaymentStatus.paid || delivery.status != OrderStatus.onTheWay
                ? null
                : onConfirmCash,
            icon: Icon(
              delivery.paymentStatus == PaymentStatus.paid ? Icons.check_circle_rounded : Icons.payments_outlined,
              size: 18,
            ),
            label: Text(
              delivery.paymentStatus == PaymentStatus.paid ? 'COD Cash Confirmed Paid' : 'Confirm Cash Received',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortId(String id) => id.substring(0, id.length < 8 ? id.length : 8);

class FullScreenRiderMapScreen extends StatefulWidget {
  const FullScreenRiderMapScreen({
    super.key,
    required this.delivery,
    required this.route,
  });

  final DeliverySnapshot delivery;
  final Future<RoutePlan?> route;

  @override
  State<FullScreenRiderMapScreen> createState() => _FullScreenRiderMapScreenState();
}

class _FullScreenRiderMapScreenState extends State<FullScreenRiderMapScreen> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.delivery.pickupLatitude != null && widget.delivery.pickupLongitude != null
        ? LatLng(widget.delivery.pickupLatitude!, widget.delivery.pickupLongitude!)
        : const LatLng(7.1125, 124.8285);
    final destination = widget.delivery.destinationLatitude != null && widget.delivery.destinationLongitude != null
        ? LatLng(widget.delivery.destinationLatitude!, widget.delivery.destinationLongitude!)
        : const LatLng(7.1066, 124.8292);

    return Scaffold(
      body: FutureBuilder<RoutePlan?>(
        future: widget.route,
        builder: (context, snapshot) {
          final plan = snapshot.data;
          final points = plan != null ? plan.points : [pickup, destination];

          return AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final movingPoint = _interpolateRoutePoint(points, _animController.value);

              return Stack(
                children: [
                  // Fullscreen Map Layer
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: pickup,
                        initialZoom: 14.5,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: AppConfig.mapboxPublicToken.isNotEmpty
                              ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxPublicToken}'
                              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.mns.rider',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              strokeWidth: 9,
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
                            ),
                            Polyline(
                              points: points,
                              strokeWidth: 4.5,
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            // Store Pin
                            Marker(
                              point: pickup,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                                ),
                                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                            // Customer Pin
                            Marker(
                              point: destination,
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
                            // Animated Traveling Courier Indicator (Slow/Normal animation)
                            if (points.isNotEmpty)
                              Marker(
                                point: movingPoint,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x777C3AED), blurRadius: 14, spreadRadius: 3),
                                    ],
                                  ),
                                  child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

              // Top Navigation & Direction Floating Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Action Bar with High-Contrast White Theme Back Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // High-Visibility White Back Button
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 4,
                              shadowColor: const Color(0x14000000),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Color(0xFF0F172A)),
                                      SizedBox(width: 6),
                                      Text('Back', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Order Title Pill (White Theme)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [BoxShadow(color: Color(0x0C000000), blurRadius: 8, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.navigation_rounded, size: 14, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ORDER #${_shortId(widget.delivery.id)}',
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),

                            // Recenter Location Button (White Theme)
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 4,
                              shadowColor: const Color(0x14000000),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _mapController.move(pickup, 15.0),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF7C3AED)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Turn-by-Turn Navigation Direction HUD (White Theme)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  widget.delivery.status == OrderStatus.assigned
                                      ? Icons.storefront_rounded
                                      : Icons.turn_right_rounded,
                                  color: const Color(0xFF7C3AED),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.delivery.status == OrderStatus.assigned
                                          ? 'Step 1: Head to ${widget.delivery.storeName.isNotEmpty ? widget.delivery.storeName : "Store"} for Pickup'
                                          : 'Step 2: Proceed towards ${widget.delivery.customerName.isNotEmpty ? widget.delivery.customerName : "Customer"}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      plan == null
                                          ? 'Direct Navigation Path'
                                          : 'Follow Davao-Cotabato Rd · ${plan.distanceKm.toStringAsFixed(1)} km (~${plan.durationMinutes} mins)',
                                      style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Navigation Floating Sheet
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF7C3AED), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.delivery.customerName.isNotEmpty ? widget.delivery.customerName : 'Customer',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.delivery.deliveryAddress.isNotEmpty ? widget.delivery.deliveryAddress : 'Kabacan Delivery Point',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (plan != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  '${plan.distanceKm.toStringAsFixed(1)} km · ${plan.durationMinutes}m',
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
                                widget.delivery.storeName.isNotEmpty ? widget.delivery.storeName : 'M&S Store',
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
                                widget.delivery.deliveryAddress.isNotEmpty ? widget.delivery.deliveryAddress : 'Kabacan Delivery',
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
          );
        },
      );
    },
  ),
);
  }
}
