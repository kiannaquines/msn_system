import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mns_design_system/design_system.dart';
import 'package:mns_domain_models/domain_models.dart';
import 'package:mns_rider/src/screens/delivery_screen.dart';
import 'package:mns_rider/src/state/rider_controller.dart';

class RiderHomeScreen extends ConsumerWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderControllerProvider);
    return MnsPage(
      title: 'My deliveries',
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => ref.read(riderControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: ref.read(riderControllerProvider.notifier).refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _AvailabilityCard(state: state)),
            if (state.isTracking || state.pendingEvents > 0) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _TrackingBanner(state: state)),
            ],
            if (state.errorMessage != null) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _Notice(message: state.errorMessage!),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'Assigned to you',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Text('${state.deliveries.length} total'),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            if (state.deliveries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No assigned deliveries',
                  message:
                      'New assignments will appear here when dispatch sends them.',
                ),
              )
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 760 ? 2 : 1;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 236,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DeliveryCard(
                        delivery: state.deliveries[index],
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DeliveryScreen(
                              deliveryId: state.deliveries[index].id,
                            ),
                          ),
                        ),
                      ),
                      childCount: state.deliveries.length,
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({required this.state});
  final RiderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final selector = SegmentedButton<RiderStatus>(
                segments: const [
                  ButtonSegment(
                    value: RiderStatus.available,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Available'),
                  ),
                  ButtonSegment(
                    value: RiderStatus.offline,
                    icon: Icon(Icons.pause_circle_outline),
                    label: Text('Offline'),
                  ),
                ],
                selected: {state.availability == RiderStatus.busy
                    ? RiderStatus.available
                    : state.availability},
                onSelectionChanged: state.isTracking
                    ? null
                    : (selection) => ref
                        .read(riderControllerProvider.notifier)
                        .setAvailability(selection.first),
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AvailabilityLabel(),
                    const SizedBox(height: 16),
                    selector,
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: _AvailabilityLabel()),
                  selector,
                ],
              );
            },
          ),
        ),
      );
}

class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready for assignments?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text('Dispatch can assign orders only while you are available.'),
        ],
      );
}

class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.state});
  final RiderState state;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MnsColors.success.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MnsColors.success.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              Icon(
                state.isTracking ? Icons.location_on : Icons.cloud_upload,
                color: MnsColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.isTracking
                      ? 'Location sharing is active for your current delivery.'
                      : '${state.pendingEvents} update(s) waiting to sync.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (state.pendingEvents > 0)
                StatusPill(label: '${state.pendingEvents} queued'),
            ],
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.onOpen});
  final DeliverySnapshot delivery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
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
                          ? 'M&S Store'
                          : delivery.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusPill(label: delivery.status.label),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${delivery.orderId.substring(0, delivery.orderId.length < 8 ? delivery.orderId.length : 8)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 26),
              _IconLine(
                icon: Icons.person_outline,
                text: delivery.customerName.isEmpty
                    ? 'Customer'
                    : delivery.customerName,
              ),
              const SizedBox(height: 10),
              _IconLine(
                icon: Icons.location_on_outlined,
                text: delivery.deliveryAddress.isEmpty
                    ? 'Address available in delivery details'
                    : delivery.deliveryAddress,
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    currency.format(delivery.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Open delivery'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: MnsColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}
