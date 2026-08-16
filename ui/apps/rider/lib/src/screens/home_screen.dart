import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mns_domain_models/domain_models.dart';
import 'package:mns_rider/src/screens/delivery_screen.dart';
import 'package:mns_rider/src/state/rider_controller.dart';

String _resolveZone(List<DeliverySnapshot> deliveries) {
  for (final d in deliveries) {
    final text = '${d.deliveryAddress} ${d.storeName}'.toLowerCase();
    if (text.contains('toril')) return 'Davao Toril';
    if (text.contains('matina')) return 'Davao Matina';
    if (text.contains('bajada')) return 'Davao Bajada';
    if (text.contains('davao')) return 'Davao City';
    if (text.contains('kabacan')) return 'Kabacan';
    if (d.deliveryAddress.isNotEmpty) {
      final parts = d.deliveryAddress.split(',');
      if (parts.length >= 2) {
        return parts[parts.length - 2].trim();
      }
    }
  }
  return 'Davao Toril';
}

class RiderHomeScreen extends ConsumerWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderControllerProvider);
    final isOnline = state.availability == RiderStatus.available;
    final zone = _resolveZone(state.deliveries);

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rider Operations', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                Text('$zone Fleet', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(riderControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF64748B)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF7C3AED),
        onRefresh: ref.read(riderControllerProvider.notifier).refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Courier Profile & Identity Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                state.riderName?.isNotEmpty == true ? state.riderName! : 'Carlo Mendoza',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 12, color: Color(0xFF059669)),
                                  SizedBox(width: 2),
                                  Text(
                                    '4.98',
                                    style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '🏍️ Honda Click 125i (DAV-842) · $zone Hub',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'View Courier Details',
                    icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 22),
                    onPressed: () => _showRiderProfileModal(context, zone, state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Duty & Shift Summary Hero Card (Solid Light Theme)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF1E142F) : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'ON DUTY · RECEIVING ORDERS' : 'OFF DUTY · OFFLINE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      // Availability Toggle Switch
                      Switch.adaptive(
                        value: isOnline,
                        activeThumbColor: const Color(0xFF7C3AED),
                        activeTrackColor: const Color(0xFFE9D5FF),
                        onChanged: state.isTracking
                            ? null
                            : (val) {
                                ref.read(riderControllerProvider.notifier).setAvailability(
                                      val ? RiderStatus.available : RiderStatus.offline,
                                    );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 14),

                  // Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          label: 'Assigned',
                          value: '${state.deliveries.length}',
                          icon: Icons.delivery_dining_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          label: 'GPS Stream',
                          value: state.isTracking ? 'Active' : (state.pendingEvents > 0 ? '${state.pendingEvents} sync' : 'Standby'),
                          icon: Icons.gps_fixed_rounded,
                          accentColor: state.isTracking ? const Color(0xFF10B981) : const Color(0xFFC4B5FD),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          label: 'Zone',
                          value: zone,
                          icon: Icons.map_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Assigned Deliveries',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.deliveries.length} Total',
                    style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Delivery List
            if (state.deliveries.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3E8FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, size: 48, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Active Deliveries',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Turn your duty status ON to receive assignments from $zone dispatch.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...state.deliveries.map(
                (delivery) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ModernDeliveryCard(
                    delivery: delivery,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeliveryScreen(deliveryId: delivery.id),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accentColor ?? const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor ?? Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernDeliveryCard extends StatelessWidget {
  const _ModernDeliveryCard({required this.delivery, required this.onOpen});

  final DeliverySnapshot delivery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF7C3AED), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  delivery.storeName.isEmpty ? 'M&S Partner Store' : delivery.storeName,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '#${delivery.orderId.substring(0, delivery.orderId.length < 8 ? delivery.orderId.length : 8)}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusTag(status: delivery.status),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                // Customer Info Line
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        delivery.customerName.isEmpty ? 'Customer' : delivery.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Delivery Destination Line
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        delivery.deliveryAddress.isEmpty ? 'Toril, Davao City' : delivery.deliveryAddress,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Bar: COD Price + Open CTA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COLLECT COD', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        Text(
                          currency.format(delivery.total),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF7C3AED)),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onOpen,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Text('Open Delivery', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final isDone = status == OrderStatus.delivered;
    final isTransit = status == OrderStatus.onTheWay || status == OrderStatus.pickedUp;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFFECFDF5)
            : isTransit
                ? const Color(0xFFF5F0FF)
                : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: isDone
              ? const Color(0xFF047857)
              : isTransit
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFFB45309),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

void _showRiderProfileModal(BuildContext context, String zone, RiderState state) {
  final name = state.riderName?.isNotEmpty == true ? state.riderName! : 'Carlo Mendoza';
  final phone = state.riderPhone?.isNotEmpty == true ? state.riderPhone! : '+63 919 555 3456';
  final email = state.riderEmail?.isNotEmpty == true ? state.riderEmail! : 'rider@mns.com';
  final isOnline = state.availability == RiderStatus.available;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fleet Courier #RD-7021 · $zone Hub',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            const Text(
              'Courier & Database Profile',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            _ProfileDetailTile(
              icon: Icons.power_settings_new_rounded,
              label: 'On-Duty Dispatch Status',
              value: isOnline ? 'ON DUTY (Receiving Orders)' : (state.availability == RiderStatus.busy ? 'BUSY (On Delivery)' : 'OFFLINE'),
            ),
            _ProfileDetailTile(icon: Icons.phone_android_rounded, label: 'Contact Phone', value: phone),
            _ProfileDetailTile(icon: Icons.alternate_email_rounded, label: 'Account Email', value: email),
            _ProfileDetailTile(icon: Icons.two_wheeler_rounded, label: 'Vehicle Transport', value: 'Honda Click 125i (DAV-842)'),
            _ProfileDetailTile(icon: Icons.location_city_rounded, label: 'Operating Dispatch Hub', value: '$zone Operations Center'),
            _ProfileDetailTile(icon: Icons.shield_rounded, label: 'Verification & Safety', value: 'Verified COD Courier · Background Passed'),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileDetailTile extends StatelessWidget {
  const _ProfileDetailTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

