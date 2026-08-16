enum UserRole { customer, rider, admin }

enum OrderStatus {
  pending,
  confirmed,
  assigned,
  pickedUp,
  onTheWay,
  delivered,
  cancelled;

  String get apiValue => switch (this) {
        pickedUp => 'picked_up',
        onTheWay => 'on_the_way',
        _ => name,
      };

  String get label => switch (this) {
        pickedUp => 'Picked up',
        onTheWay => 'On the way',
        _ => '${name[0].toUpperCase()}${name.substring(1)}',
      };

  static OrderStatus fromApi(String value) => switch (value) {
        'picked_up' => pickedUp,
        'on_the_way' => onTheWay,
        _ => values.firstWhere((status) => status.name == value),
      };
}

enum PaymentStatus { unpaid, paid }
enum RiderStatus { available, busy, offline }

typedef Json = Map<String, dynamic>;

double _asDouble(Object? value) => value is num ? value.toDouble() : double.parse(value.toString());

class Store {
  const Store({required this.id, required this.name, this.description = '', this.imageUrl});
  final String id;
  final String name;
  final String description;
  final String? imageUrl;

  factory Store.fromJson(Json json) => Store(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
      );
}

class MenuItem {
  const MenuItem({required this.id, required this.storeId, required this.name, required this.price, this.description = '', this.imageUrl, this.available = true});
  final String id;
  final String storeId;
  final String name;
  final double price;
  final String description;
  final String? imageUrl;
  final bool available;

  factory MenuItem.fromJson(Json json) => MenuItem(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String,
        price: _asDouble(json['price']),
        description: json['description'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        available: json['available'] as bool? ?? true,
      );
}

class CartLine {
  const CartLine({required this.item, required this.quantity});
  final MenuItem item;
  final int quantity;
  double get total => item.price * quantity;
}

class CustomerAddress {
  const CustomerAddress({required this.id, required this.label, required this.line1, required this.latitude, required this.longitude});
  final String id;
  final String label;
  final String line1;
  final double latitude;
  final double longitude;

  factory CustomerAddress.fromJson(Json json) => CustomerAddress(
        id: json['id'] as String,
        label: json['label'] as String,
        line1: json['line1'] as String,
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
      );
}

class OrderLineSummary {
  const OrderLineSummary({required this.menuItemId, required this.name, required this.unitPrice, required this.quantity});
  final String menuItemId;
  final String name;
  final double unitPrice;
  final int quantity;

  factory OrderLineSummary.fromJson(Json json) => OrderLineSummary(
        menuItemId: json['menu_item_id'] as String,
        name: json['name_snapshot'] as String,
        unitPrice: _asDouble(json['unit_price']),
        quantity: json['quantity'] as int,
      );
}

class OrderSummary {
  const OrderSummary({required this.id, required this.status, required this.paymentStatus, required this.subtotal, required this.deliveryFee, required this.total, this.storeName = '', this.createdAt, this.deliveryId, this.riderName, this.items = const []});
  final String id;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String storeName;
  final DateTime? createdAt;
  final String? deliveryId;
  final String? riderName;
  final List<OrderLineSummary> items;

  factory OrderSummary.fromJson(Json json) => OrderSummary(
        id: json['id'] as String,
        status: OrderStatus.fromApi(json['status'] as String),
        paymentStatus: PaymentStatus.values.byName(json['payment_status'] as String),
        subtotal: _asDouble(json['subtotal']),
        deliveryFee: _asDouble(json['delivery_fee']),
        total: _asDouble(json['total']),
        storeName: json['store_name'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        deliveryId: json['delivery_id'] as String?,
        riderName: json['rider_name'] as String?,
        items: ((json['items'] as List?) ?? const []).map((item) => OrderLineSummary.fromJson(item as Json)).toList(),
      );
}

class DeliverySnapshot {
  const DeliverySnapshot({
    required this.id,
    required this.orderId,
    required this.status,
    this.latitude,
    this.longitude,
    this.etaMinutes,
    this.lastLocationAt,
    this.storeName = '',
    this.customerName = '',
    this.riderName,
    this.deliveryAddress = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.total = 0,
    this.paymentStatus = PaymentStatus.unpaid,
  });
  final String id;
  final String orderId;
  final OrderStatus status;
  final double? latitude;
  final double? longitude;
  final int? etaMinutes;
  final DateTime? lastLocationAt;
  final String storeName;
  final String customerName;
  final String? riderName;
  final String deliveryAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double total;
  final PaymentStatus paymentStatus;

  bool get isStale => lastLocationAt == null || DateTime.now().difference(lastLocationAt!).inSeconds > 45;

  factory DeliverySnapshot.fromJson(Json json) => DeliverySnapshot(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        status: OrderStatus.fromApi(json['status'] as String),
        latitude: json['latitude'] == null ? null : _asDouble(json['latitude']),
        longitude: json['longitude'] == null ? null : _asDouble(json['longitude']),
        etaMinutes: json['eta_minutes'] as int?,
        lastLocationAt: DateTime.tryParse(json['last_location_at'] as String? ?? ''),
        storeName: json['store_name'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        riderName: json['rider_name'] as String?,
        deliveryAddress: json['delivery_address'] as String? ?? '',
        pickupLatitude: json['pickup_latitude'] == null ? null : _asDouble(json['pickup_latitude']),
        pickupLongitude: json['pickup_longitude'] == null ? null : _asDouble(json['pickup_longitude']),
        destinationLatitude: json['destination_latitude'] == null ? null : _asDouble(json['destination_latitude']),
        destinationLongitude: json['destination_longitude'] == null ? null : _asDouble(json['destination_longitude']),
        total: json['total'] == null ? 0 : _asDouble(json['total']),
        paymentStatus: PaymentStatus.values.byName(json['payment_status'] as String? ?? 'unpaid'),
      );
}

class RiderSummary {
  const RiderSummary({required this.id, required this.name, required this.status, this.activeDeliveryId});
  final String id;
  final String name;
  final RiderStatus status;
  final String? activeDeliveryId;
}
