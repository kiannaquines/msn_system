enum OrderStage {
  pending,
  confirmed,
  assigned,
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
}

extension OrderStageLabel on OrderStage {
  String get label => switch (this) {
        OrderStage.pending => 'Order placed',
        OrderStage.confirmed => 'Confirmed',
        OrderStage.assigned => 'Rider assigned',
        OrderStage.pickedUp => 'Picked up',
        OrderStage.onTheWay => 'On the way',
        OrderStage.delivered => 'Delivered',
        OrderStage.cancelled => 'Cancelled',
      };

  bool get isComplete => this == OrderStage.delivered || this == OrderStage.cancelled;
}

class CustomerProfile {
  const CustomerProfile({required this.name, required this.email});
  final String name;
  final String email;
}

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.categories,
    required this.rating,
    required this.etaMinutes,
  });
  final String id;
  final String name;
  final String subtitle;
  final List<String> categories;
  final double rating;
  final int etaMinutes;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.available = true,
  });
  final String id;
  final String storeId;
  final String name;
  final String description;
  final String category;
  final double price;
  final bool available;
}

class CartLine {
  const CartLine({required this.item, required this.quantity});
  final MenuItem item;
  final int quantity;
  double get total => item.price * quantity;
  CartLine copyWith({int? quantity}) => CartLine(item: item, quantity: quantity ?? this.quantity);
}

class DeliveryAddress {
  const DeliveryAddress({this.id, required this.label, required this.address, this.latitude, this.longitude});
  final String? id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.store,
    required this.lines,
    required this.address,
    required this.stage,
    required this.createdAt,
    required this.deliveryFee,
    required this.etaMinutes,
    this.deliveryId,
    this.riderName,
    this.subtotalAmount,
    this.totalAmount,
  });
  final String id;
  final Store store;
  final List<CartLine> lines;
  final DeliveryAddress address;
  final OrderStage stage;
  final DateTime createdAt;
  final double deliveryFee;
  final int etaMinutes;
  final String? deliveryId;
  final String? riderName;
  final double? subtotalAmount;
  final double? totalAmount;
  double get subtotal => subtotalAmount ?? lines.fold(0, (sum, line) => sum + line.total);
  double get total => totalAmount ?? subtotal + deliveryFee;
}
