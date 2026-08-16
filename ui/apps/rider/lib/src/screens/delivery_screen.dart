import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contacting Kabacan Dispatch HQ...'), behavior: SnackBarBehavior.floating),
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
          _ModernRouteCard(delivery: delivery, route: _route!),
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

  Future<RoutePlan?> _loadRoute(DeliverySnapshot delivery) {
    if (delivery.pickupLatitude == null ||
        delivery.pickupLongitude == null ||
        delivery.destinationLatitude == null ||
        delivery.destinationLongitude == null) {
      return Future.value();
    }
    return const MapboxRouteService().loadRoute(
      LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!),
      LatLng(delivery.destinationLatitude!, delivery.destinationLongitude!),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _confirmCash(DeliverySnapshot delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Text('Confirm COD Cash', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          'Confirm that you received ${NumberFormat.currency(symbol: '₱', decimalDigits: 0).format(delivery.total)} in cash from the customer.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cash Received', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(riderControllerProvider.notifier).confirmCash(delivery);
    }
  }

  Future<void> _advance(DeliverySnapshot delivery) async {
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

class _ModernRouteCard extends StatelessWidget {
  const _ModernRouteCard({required this.delivery, required this.route});
  final DeliverySnapshot delivery;
  final Future<RoutePlan?> route;

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
        future: route,
        builder: (context, snapshot) {
          final plan = snapshot.data;
          final pickup = delivery.pickupLatitude != null && delivery.pickupLongitude != null
              ? LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!)
              : const LatLng(7.1125, 124.8285);
          final destination = delivery.destinationLatitude != null && delivery.destinationLongitude != null
              ? LatLng(delivery.destinationLatitude!, delivery.destinationLongitude!)
              : const LatLng(7.1066, 124.8292);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 240,
                child: FlutterMap(
                  options: MapOptions(initialCenter: pickup, initialZoom: 14.2),
                  children: [
                    TileLayer(
                      urlTemplate: AppConfig.mapboxPublicToken.isNotEmpty
                          ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}@2x?access_token=${AppConfig.mapboxPublicToken}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mns.rider',
                    ),
                    if (plan != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: plan.points,
                            strokeWidth: 8,
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          ),
                          Polyline(
                            points: plan.points,
                            strokeWidth: 4,
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      )
                    else
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [pickup, destination],
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
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.alt_route_rounded, color: Color(0xFF7C3AED), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        plan == null
                            ? 'Kabacan Central Route · Direct Line'
                            : '${plan.distanceKm.toStringAsFixed(1)} km · Est. ${plan.durationMinutes} mins',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            value: delivery.customerName.isEmpty ? 'Kabacan Customer' : delivery.customerName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_outlined,
            title: 'Drop-off Address',
            value: delivery.deliveryAddress.isEmpty ? 'Poblacion, Kabacan, Cotabato' : delivery.deliveryAddress,
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
