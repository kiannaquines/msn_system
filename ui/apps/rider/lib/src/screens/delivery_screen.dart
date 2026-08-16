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
    final matching = state.deliveries.where((item) => item.id == widget.deliveryId);
    if (matching.isEmpty) {
      return const MnsPage(
        title: 'Delivery',
        child: EmptyState(
          icon: Icons.search_off,
          title: 'Delivery unavailable',
          message: 'Refresh your assignments and try again.',
        ),
      );
    }
    final delivery = matching.first;
    _route ??= _loadRoute(delivery);
    final trackingThis = state.trackingDeliveryId == delivery.id;
    return MnsPage(
      title: 'Order #${_shortId(delivery.orderId)}',
      child: ListView(
        children: [
          _TrackingStatus(
            tracking: trackingThis,
            queued: state.pendingEvents,
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(state.errorMessage!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _RouteCard(delivery: delivery, route: _route!),
          const SizedBox(height: 16),
          _DeliveryDetails(delivery: delivery),
          const SizedBox(height: 16),
          _ActionCard(
            delivery: delivery,
            tracking: trackingThis,
            onTrackingChanged: () => _toggleTracking(delivery, trackingThis),
            onConfirmCash: () => _confirmCash(delivery),
            onAdvance: () => _advance(delivery),
          ),
          const SizedBox(height: 24),
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

  Future<void> _toggleTracking(
    DeliverySnapshot delivery,
    bool tracking,
  ) async {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCash(DeliverySnapshot delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm cash collection?'),
        content: Text(
          'Confirm that you received ${NumberFormat.currency(symbol: '₱').format(delivery.total)} from the customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cash received'),
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

class _TrackingStatus extends StatelessWidget {
  const _TrackingStatus({required this.tracking, required this.queued});
  final bool tracking;
  final int queued;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tracking
                ? MnsColors.success.withValues(alpha: .12)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                tracking ? Icons.my_location : Icons.location_disabled,
                color: tracking ? MnsColors.success : Colors.black54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tracking
                      ? 'Location sharing is active'
                      : 'Location sharing is stopped',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (queued > 0) StatusPill(label: '$queued queued'),
            ],
          ),
        ),
      );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.delivery, required this.route});
  final DeliverySnapshot delivery;
  final Future<RoutePlan?> route;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<RoutePlan?>(
          future: route,
          builder: (context, snapshot) {
            final plan = snapshot.data;
            final pickup = delivery.pickupLatitude != null &&
                    delivery.pickupLongitude != null
                ? LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!)
                : null;
            final destination = delivery.destinationLatitude != null &&
                    delivery.destinationLongitude != null
                ? LatLng(
                    delivery.destinationLatitude!,
                    delivery.destinationLongitude!,
                  )
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 280,
                  child: pickup == null || destination == null
                      ? const Center(child: Text('Route coordinates unavailable'))
                      : FlutterMap(
                          options: MapOptions(initialCenter: pickup, initialZoom: 13),
                          children: [
                            if (AppConfig.mapboxPublicToken.isNotEmpty)
                              TileLayer(
                                urlTemplate:
                                    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxPublicToken}',
                                userAgentPackageName: 'com.mns.rider',
                              ),
                            if (plan != null)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: plan.points,
                                    strokeWidth: 5,
                                    color: MnsColors.orange,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pickup,
                                  width: 48,
                                  height: 48,
                                  child: const _MapPin(
                                    icon: Icons.store,
                                    color: MnsColors.navy,
                                  ),
                                ),
                                Marker(
                                  point: destination,
                                  width: 48,
                                  height: 48,
                                  child: const _MapPin(
                                    icon: Icons.home,
                                    color: MnsColors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route, color: MnsColors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              plan == null
                                  ? 'Route guidance unavailable'
                                  : '${plan.distanceKm.toStringAsFixed(1)} km • ${plan.durationMinutes} min',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (plan?.instructions.isNotEmpty ?? false) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Next: ${plan!.instructions.first}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white),
      );
}

class _DeliveryDetails extends StatelessWidget {
  const _DeliveryDetails({required this.delivery});
  final DeliverySnapshot delivery;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      delivery.storeName.isEmpty
                          ? 'Pickup details'
                          : delivery.storeName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  StatusPill(label: delivery.status.label),
                ],
              ),
              const Divider(height: 28),
              _DetailLine(
                icon: Icons.person_outline,
                title: 'Customer',
                value: delivery.customerName,
              ),
              const SizedBox(height: 14),
              _DetailLine(
                icon: Icons.location_on_outlined,
                title: 'Drop-off',
                value: delivery.deliveryAddress,
              ),
              const SizedBox(height: 14),
              _DetailLine(
                icon: Icons.payments_outlined,
                title: 'Cash to collect',
                value: NumberFormat.currency(symbol: '₱').format(delivery.total),
              ),
            ],
          ),
        ),
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MnsColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'Not provided' : value),
              ],
            ),
          ),
        ],
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    final trackable = delivery.status == OrderStatus.pickedUp ||
        delivery.status == OrderStatus.onTheWay;
    final nextLabel = switch (delivery.status) {
      OrderStatus.assigned => 'Confirm pickup',
      OrderStatus.pickedUp => 'Start delivery',
      OrderStatus.onTheWay => 'Complete delivery',
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delivery actions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: trackable ? onTrackingChanged : null,
              icon: Icon(tracking ? Icons.location_off : Icons.my_location),
              label: Text(tracking ? 'Stop location sharing' : 'Share location'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: delivery.paymentStatus == PaymentStatus.paid ||
                      delivery.status != OrderStatus.onTheWay
                  ? null
                  : onConfirmCash,
              icon: const Icon(Icons.payments_outlined),
              label: Text(delivery.paymentStatus == PaymentStatus.paid
                  ? 'Cash collected'
                  : 'Confirm cash collection'),
            ),
            if (nextLabel != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onAdvance,
                icon: const Icon(Icons.arrow_forward),
                label: Text(nextLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _shortId(String id) => id.substring(0, id.length < 8 ? id.length : 8);
