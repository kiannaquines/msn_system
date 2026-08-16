import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_api_client/api_client.dart';
import 'package:mns_auth_session/auth_session.dart';
import 'package:mns_domain_models/domain_models.dart';
import 'package:mns_rider/src/config.dart';
import 'package:mns_rider/src/data/offline_event_queue.dart';
import 'package:mns_rider/src/services/tracking_service.dart';
import 'package:uuid/uuid.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl),
);
final authSessionProvider = Provider<AuthSession>(
  (ref) => AuthSession(ref.watch(apiClientProvider)),
);
final offlineQueueProvider = Provider<OfflineEventQueue>(
  (ref) => SqliteOfflineEventQueue(),
);
final trackingServiceProvider = Provider<TrackingService>(
  (ref) => GeolocatorTrackingService(),
);
final riderControllerProvider =
    StateNotifierProvider<RiderController, RiderState>((ref) {
  return RiderController(
    api: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
    queue: ref.watch(offlineQueueProvider),
    trackingService: ref.watch(trackingServiceProvider),
  )..restoreSession();
});

class RiderState {
  const RiderState({
    this.isRestoring = true,
    this.isAuthenticated = false,
    this.isBusy = false,
    this.availability = RiderStatus.offline,
    this.deliveries = const [],
    this.trackingDeliveryId,
    this.pendingEvents = 0,
    this.errorMessage,
    this.riderName,
    this.riderEmail,
    this.riderPhone,
  });

  final bool isRestoring;
  final bool isAuthenticated;
  final bool isBusy;
  final RiderStatus availability;
  final List<DeliverySnapshot> deliveries;
  final String? trackingDeliveryId;
  final int pendingEvents;
  final String? errorMessage;
  final String? riderName;
  final String? riderEmail;
  final String? riderPhone;

  bool get isTracking => trackingDeliveryId != null;

  RiderState copyWith({
    bool? isRestoring,
    bool? isAuthenticated,
    bool? isBusy,
    RiderStatus? availability,
    List<DeliverySnapshot>? deliveries,
    String? trackingDeliveryId,
    bool clearTracking = false,
    int? pendingEvents,
    String? errorMessage,
    bool clearError = false,
    String? riderName,
    String? riderEmail,
    String? riderPhone,
  }) =>
      RiderState(
        isRestoring: isRestoring ?? this.isRestoring,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isBusy: isBusy ?? this.isBusy,
        availability: availability ?? this.availability,
        deliveries: deliveries ?? this.deliveries,
        trackingDeliveryId:
            clearTracking ? null : trackingDeliveryId ?? this.trackingDeliveryId,
        pendingEvents: pendingEvents ?? this.pendingEvents,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        riderName: riderName ?? this.riderName,
        riderEmail: riderEmail ?? this.riderEmail,
        riderPhone: riderPhone ?? this.riderPhone,
      );
}

class RiderController extends StateNotifier<RiderState> {
  RiderController({
    required ApiClient api,
    required AuthSession session,
    required OfflineEventQueue queue,
    required TrackingService trackingService,
    Uuid uuid = const Uuid(),
  })  : _api = api,
        _session = session,
        _queue = queue,
        _trackingService = trackingService,
        _uuid = uuid,
        super(const RiderState());

  final ApiClient _api;
  final AuthSession _session;
  final OfflineEventQueue _queue;
  final TrackingService _trackingService;
  final Uuid _uuid;
  StreamSubscription<TrackingReading>? _trackingSubscription;

  Future<void> restoreSession() async {
    await _session.restore();
    if (!_session.authenticated || _session.role != UserRole.rider) {
      if (_session.authenticated) await _session.logout();
      state = state.copyWith(isRestoring: false);
      return;
    }
    try {
      await _loadDeliveries();
      state = state.copyWith(isRestoring: false, isAuthenticated: true);
    } catch (_) {
      await _session.logout();
      state = state.copyWith(isRestoring: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final tokens = await _api.login(email.trim(), password);
      if (tokens.role != UserRole.rider) {
        throw const ApiException(403, 'This account is not a rider account.');
      }
      await _session.apply(tokens);
      await _loadDeliveries();
      state = state.copyWith(isAuthenticated: true, isBusy: false);
      return true;
    } catch (_) {
      await _session.logout();
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Sign-in failed. Check your details and connection.',
      );
      return false;
    }
  }

  Future<void> _loadDeliveries() async {
    final deliveries = await _api.listAssignedDeliveries();
    final trackedId = state.trackingDeliveryId;
    if (trackedId != null &&
        !deliveries.any((delivery) =>
            delivery.id == trackedId &&
            (delivery.status == OrderStatus.pickedUp ||
                delivery.status == OrderStatus.onTheWay))) {
      await stopTracking();
    }

    String? riderName = state.riderName;
    String? riderEmail = state.riderEmail;
    String? riderPhone = state.riderPhone;
    RiderStatus availability = state.availability;

    try {
      final meJson = await _api.me();
      riderName = meJson['full_name'] as String?;
      riderEmail = meJson['email'] as String?;
      riderPhone = meJson['phone'] as String?;
      final statusStr = meJson['rider_status'] as String?;
      if (statusStr != null) {
        availability = switch (statusStr) {
          'available' => RiderStatus.available,
          'busy' => RiderStatus.busy,
          _ => RiderStatus.offline,
        };
      }
    } catch (_) {}

    state = state.copyWith(
      deliveries: deliveries,
      pendingEvents: await _queue.count(),
      riderName: riderName,
      riderEmail: riderEmail,
      riderPhone: riderPhone,
      availability: availability,
    );
  }

  Future<void> refresh() async {
    try {
      await flushQueue();
      await _loadDeliveries();
      state = state.copyWith(clearError: true);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Could not refresh assignments.');
    }
  }

  Future<void> setAvailability(RiderStatus availability) async {
    final previous = state.availability;
    if (previous == availability) return;
    state = state.copyWith(availability: availability, clearError: true);
    try {
      await _api.setRiderAvailability(availability);
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Availability was not updated.';
      state = state.copyWith(
        availability: previous,
        errorMessage: msg,
      );
    }
  }

  Future<TrackingPermissionState> startTracking(
    DeliverySnapshot delivery,
  ) async {
    final mayTrack = delivery.status == OrderStatus.pickedUp ||
        delivery.status == OrderStatus.onTheWay;
    if (!mayTrack) return TrackingPermissionState.permissionDenied;
    final permission = await _trackingService.ensurePermission();
    if (permission != TrackingPermissionState.ready) return permission;
    await _trackingSubscription?.cancel();
    state = state.copyWith(trackingDeliveryId: delivery.id, clearError: true);
    _trackingSubscription = _trackingService.readings().listen(
      (reading) => _sendOrQueueLocation(delivery.id, reading),
      onError: (_) => state = state.copyWith(
        errorMessage: 'Location updates paused. Reconnect to resume.',
      ),
    );
    return permission;
  }

  Future<void> stopTracking() async {
    await _trackingSubscription?.cancel();
    _trackingSubscription = null;
    state = state.copyWith(clearTracking: true);
  }

  Future<void> _sendOrQueueLocation(
    String deliveryId,
    TrackingReading reading,
  ) async {
    final id = _uuid.v4();
    try {
      await _api.recordLocation(
        deliveryId,
        latitude: reading.latitude,
        longitude: reading.longitude,
        accuracyMeters: reading.accuracy,
        recordedAt: reading.capturedAt,
        idempotencyKey: id,
      );
      await flushQueue();
    } on ApiException catch (error) {
      if (error.statusCode < 500) {
        state = state.copyWith(
          errorMessage: 'Location update rejected: ${error.message}',
        );
        return;
      }
      await _queueLocation(deliveryId, reading, id);
    } catch (_) {
      await _queueLocation(deliveryId, reading, id);
    }
  }

  Future<void> _queueLocation(
    String deliveryId,
    TrackingReading reading,
    String id,
  ) async {
    await _queue.enqueue(QueuedEvent(
      id: id,
      deliveryId: deliveryId,
      type: QueuedEventType.location,
      payload: reading.toJson(),
      createdAt: DateTime.now(),
    ));
    state = state.copyWith(pendingEvents: await _queue.count());
  }

  Future<bool> advanceDelivery(DeliverySnapshot delivery) async {
    final next = _nextStatus(delivery.status);
    if (next == null) return false;
    if (next == OrderStatus.delivered &&
        delivery.paymentStatus != PaymentStatus.paid) {
      state = state.copyWith(
        errorMessage: 'Confirm cash collection before completing delivery.',
      );
      return false;
    }
    final id = _uuid.v4();
    try {
      await _api.updateDeliveryStatus(delivery.id, next, id);
    } on ApiException catch (error) {
      if (error.statusCode < 500) {
        state = state.copyWith(errorMessage: error.message);
        return false;
      }
      await _queueStatus(delivery, next, id);
    } catch (_) {
      await _queueStatus(delivery, next, id);
    }
    _replaceDelivery(_copyDelivery(delivery, status: next));
    if (next == OrderStatus.delivered) await stopTracking();
    return true;
  }

  Future<void> _queueStatus(
    DeliverySnapshot delivery,
    OrderStatus status,
    String id,
  ) async {
    await _queue.enqueue(QueuedEvent(
      id: id,
      deliveryId: delivery.id,
      type: QueuedEventType.status,
      payload: {'status': status.apiValue},
      createdAt: DateTime.now(),
    ));
    state = state.copyWith(
      pendingEvents: await _queue.count(),
      errorMessage: 'Status saved offline and will sync automatically.',
    );
  }

  Future<void> confirmCash(DeliverySnapshot delivery) async {
    if (delivery.paymentStatus == PaymentStatus.paid) return;
    final id = _uuid.v4();
    try {
      await _api.confirmCod(delivery.id, id);
    } on ApiException catch (error) {
      if (error.statusCode < 500) {
        state = state.copyWith(errorMessage: error.message);
        return;
      }
      await _queueCash(delivery.id, id);
    } catch (_) {
      await _queueCash(delivery.id, id);
    }
    _replaceDelivery(_copyDelivery(delivery, paymentStatus: PaymentStatus.paid));
  }

  Future<void> _queueCash(String deliveryId, String id) async {
    await _queue.enqueue(QueuedEvent(
      id: id,
      deliveryId: deliveryId,
      type: QueuedEventType.cashCollection,
      payload: const {},
      createdAt: DateTime.now(),
    ));
    state = state.copyWith(
      pendingEvents: await _queue.count(),
      errorMessage: 'Cash confirmation saved offline.',
    );
  }

  Future<void> flushQueue() async {
    for (final event in await _queue.pending()) {
      try {
        switch (event.type) {
          case QueuedEventType.location:
            await _api.recordLocation(
              event.deliveryId,
              latitude: event.payload['latitude']! as double,
              longitude: event.payload['longitude']! as double,
              accuracyMeters: event.payload['accuracy_meters']! as double,
              recordedAt: DateTime.parse(event.payload['recorded_at']! as String),
              idempotencyKey: event.id,
            );
          case QueuedEventType.status:
            await _api.updateDeliveryStatus(
              event.deliveryId,
              OrderStatus.fromApi(event.payload['status']! as String),
              event.id,
            );
          case QueuedEventType.cashCollection:
            await _api.confirmCod(event.deliveryId, event.id);
        }
        await _queue.remove(event.id);
      } on ApiException catch (error) {
        if (error.statusCode < 500) {
          await _queue.remove(event.id);
          state = state.copyWith(
            errorMessage: 'A queued update was rejected: ${error.message}',
          );
          continue;
        }
        break;
      } catch (_) {
        break;
      }
    }
    state = state.copyWith(pendingEvents: await _queue.count());
  }

  OrderStatus? _nextStatus(OrderStatus status) => switch (status) {
        OrderStatus.assigned => OrderStatus.pickedUp,
        OrderStatus.pickedUp => OrderStatus.onTheWay,
        OrderStatus.onTheWay => OrderStatus.delivered,
        _ => null,
      };

  void _replaceDelivery(DeliverySnapshot delivery) {
    state = state.copyWith(
      deliveries: [
        for (final item in state.deliveries)
          if (item.id == delivery.id) delivery else item,
      ],
    );
  }

  DeliverySnapshot _copyDelivery(
    DeliverySnapshot source, {
    OrderStatus? status,
    PaymentStatus? paymentStatus,
  }) =>
      DeliverySnapshot(
        id: source.id,
        orderId: source.orderId,
        status: status ?? source.status,
        latitude: source.latitude,
        longitude: source.longitude,
        etaMinutes: source.etaMinutes,
        lastLocationAt: source.lastLocationAt,
        storeName: source.storeName,
        customerName: source.customerName,
        deliveryAddress: source.deliveryAddress,
        pickupLatitude: source.pickupLatitude,
        pickupLongitude: source.pickupLongitude,
        destinationLatitude: source.destinationLatitude,
        destinationLongitude: source.destinationLongitude,
        total: source.total,
        paymentStatus: paymentStatus ?? source.paymentStatus,
      );

  Future<void> logout() async {
    await stopTracking();
    await _session.logout();
    state = const RiderState(isRestoring: false);
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    _api.close();
    super.dispose();
  }
}
