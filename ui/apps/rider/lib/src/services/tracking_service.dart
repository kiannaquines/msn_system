import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum TrackingPermissionState { ready, servicesDisabled, permissionDenied }

class TrackingReading {
  const TrackingReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.speedMetersPerSecond,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final double speedMetersPerSecond;

  Map<String, Object?> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracy,
        'recorded_at': capturedAt.toUtc().toIso8601String(),
        'speed_meters_per_second': speedMetersPerSecond,
      };
}

abstract interface class TrackingService {
  Future<TrackingPermissionState> ensurePermission();
  Stream<TrackingReading> readings();
}

class GeolocatorTrackingService implements TrackingService {
  @override
  Future<TrackingPermissionState> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return TrackingPermissionState.servicesDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse &&
        defaultTargetPlatform == TargetPlatform.android) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        (permission == LocationPermission.whileInUse &&
            defaultTargetPlatform == TargetPlatform.android)) {
      return TrackingPermissionState.permissionDenied;
    }
    return TrackingPermissionState.ready;
  }

  @override
  Stream<TrackingReading> readings() {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = const AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: Duration(seconds: 10),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'M&S delivery tracking',
          notificationText: 'Your location is shared for the active delivery.',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      settings = const AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => TrackingReading(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            capturedAt: position.timestamp,
            speedMetersPerSecond: position.speed,
          ),
    );
  }
}
