import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_domain_models/domain_models.dart';
import 'package:mns_realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_state.dart';

final trackingDeliveryProvider = StreamProvider.family<DeliverySnapshot, String>((ref, deliveryId) async* {
  final repository = ref.watch(customerRepositoryProvider);
  final refreshes = StreamController<void>.broadcast();
  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;
  DeliveryRealtimeClient? realtimeClient;
  final timer = Timer.periodic(const Duration(seconds: 4), (_) {
    if (!refreshes.isClosed) refreshes.add(null);
  });

  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final token = repository.realtimeToken;
  if (url.isNotEmpty && publishableKey.isNotEmpty && token != null) {
    realtimeClient = DeliveryRealtimeClient(SupabaseClient(url, publishableKey));
    await realtimeClient.setAccessToken(token);
    realtimeSubscription = realtimeClient.subscribe(deliveryId).listen((_) {
      if (!refreshes.isClosed) refreshes.add(null);
    });
  }

  ref.onDispose(() {
    timer.cancel();
    realtimeSubscription?.cancel();
    realtimeClient?.close();
    refreshes.close();
  });

  DeliverySnapshot? lastSnapshot;
  while (!refreshes.isClosed) {
    try {
      lastSnapshot = await repository.deliverySnapshot(deliveryId);
      yield lastSnapshot;
    } catch (_) {
      // Keep the stream alive; the timer or next Realtime event retries the authoritative fetch.
      if (lastSnapshot != null) yield lastSnapshot;
    }
    if (refreshes.isClosed) break;
    await refreshes.stream.first;
  }
});
