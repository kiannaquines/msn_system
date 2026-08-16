enum AdminOrderStatus { pending, confirmed, assigned, pickedUp, onTheWay, delivered, cancelled }
enum AdminRiderStatus { available, busy, offline }

extension AdminStatusLabel on AdminOrderStatus {
  String get label => switch (this) {
        AdminOrderStatus.pickedUp => 'Picked up',
        AdminOrderStatus.onTheWay => 'On the way',
        _ => '${name[0].toUpperCase()}${name.substring(1)}',
      };
}

class AdminStore {
  const AdminStore({required this.id, required this.name, required this.description, this.available = true, this.items = const []});
  final String id;
  final String name;
  final String description;
  final bool available;
  final List<AdminMenuItem> items;
  AdminStore copyWith({String? name, String? description, bool? available, List<AdminMenuItem>? items}) => AdminStore(id: id, name: name ?? this.name, description: description ?? this.description, available: available ?? this.available, items: items ?? this.items);
}

class AdminMenuItem {
  const AdminMenuItem({required this.id, required this.name, required this.category, required this.price, this.available = true});
  final String id;
  final String name;
  final String category;
  final double price;
  final bool available;
  AdminMenuItem copyWith({String? name, String? category, double? price, bool? available}) => AdminMenuItem(id: id, name: name ?? this.name, category: category ?? this.category, price: price ?? this.price, available: available ?? this.available);
}

class AdminOrder {
  const AdminOrder({required this.id, required this.customer, required this.store, required this.total, required this.status, required this.createdAt, this.rider, this.codPaid = false});
  final String id;
  final String customer;
  final String store;
  final double total;
  final AdminOrderStatus status;
  final DateTime createdAt;
  final String? rider;
  final bool codPaid;
  AdminOrder copyWith({AdminOrderStatus? status, String? rider, bool? codPaid}) => AdminOrder(id: id, customer: customer, store: store, total: total, status: status ?? this.status, createdAt: createdAt, rider: rider ?? this.rider, codPaid: codPaid ?? this.codPaid);
}

class AdminRider {
  const AdminRider({required this.id, required this.name, required this.phone, required this.status, this.activeDelivery});
  final String id;
  final String name;
  final String phone;
  final AdminRiderStatus status;
  final String? activeDelivery;
  AdminRider copyWith({String? name, String? phone, AdminRiderStatus? status, String? activeDelivery}) => AdminRider(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        status: status ?? this.status,
        activeDelivery: activeDelivery ?? this.activeDelivery,
      );
}

class LiveDelivery {
  const LiveDelivery({
    required this.id,
    required this.orderId,
    required this.rider,
    required this.customer,
    required this.status,
    required this.updatedAt,
    required this.latitude,
    required this.longitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.storeName = '',
    this.deliveryAddress = '',
    this.etaMinutes,
  });
  final String id;
  final String orderId;
  final String rider;
  final String customer;
  final AdminOrderStatus status;
  final DateTime updatedAt;
  final double latitude;
  final double longitude;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String storeName;
  final String deliveryAddress;
  final int? etaMinutes;
  bool get stale => DateTime.now().difference(updatedAt) > const Duration(seconds: 45);
}

class AuditEntry {
  const AuditEntry({required this.action, required this.actor, required this.target, required this.reason, required this.createdAt});
  final String action;
  final String actor;
  final String target;
  final String reason;
  final DateTime createdAt;
}

class FeedbackEntry {
  const FeedbackEntry({required this.orderId, required this.customer, required this.rating, required this.comment, required this.createdAt});
  final String orderId;
  final String customer;
  final int rating;
  final String comment;
  final DateTime createdAt;
}
