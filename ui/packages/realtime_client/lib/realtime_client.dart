import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryRealtimeClient {
  DeliveryRealtimeClient(this._client);
  final SupabaseClient _client;
  final List<RealtimeChannel> _channels = [];

  Future<void> setAccessToken(String token) => _client.realtime.setAuth(token);

  Stream<Map<String, dynamic>> subscribe(String deliveryId) {
    final controller = StreamController<Map<String, dynamic>>();
    final locationChannel = _client
        .channel('delivery:$deliveryId:location', opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(event: 'location.updated', callback: (payload) => controller.add(Map<String, dynamic>.from(payload)))
        .subscribe();
    final statusChannel = _client
        .channel('delivery:$deliveryId:status', opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(event: 'delivery.status_changed', callback: (payload) => controller.add(Map<String, dynamic>.from(payload)))
        .onBroadcast(event: 'delivery.eta_updated', callback: (payload) => controller.add(Map<String, dynamic>.from(payload)))
        .onBroadcast(event: 'delivery.completed', callback: (payload) => controller.add(Map<String, dynamic>.from(payload)))
        .onBroadcast(event: 'delivery.cancelled', callback: (payload) => controller.add(Map<String, dynamic>.from(payload)))
        .subscribe();
    _channels.addAll([locationChannel, statusChannel]);
    controller.onCancel = close;
    return controller.stream;
  }

  Future<void> close() async {
    final channels = [..._channels];
    _channels.clear();
    for (final channel in channels) {
      await _client.removeChannel(channel);
    }
  }
}
