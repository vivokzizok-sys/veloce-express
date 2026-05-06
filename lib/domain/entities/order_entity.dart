enum OrderStatus {
  requested,
  priced,
  rejected,
  open,
  bidding,
  accepted,
  inProgress,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get value => switch (this) {
        OrderStatus.requested => 'requested',
        OrderStatus.priced => 'priced',
        OrderStatus.rejected => 'rejected',
        OrderStatus.open => 'open',
        OrderStatus.bidding => 'bidding',
        OrderStatus.accepted => 'accepted',
        OrderStatus.inProgress => 'inProgress',
        OrderStatus.delivered => 'delivered',
        OrderStatus.cancelled => 'cancelled',
      };

  static OrderStatus fromString(String value) => switch (value) {
        'requested' => OrderStatus.requested,
        'priced' => OrderStatus.priced,
        'rejected' => OrderStatus.rejected,
        'bidding' => OrderStatus.bidding,
        'accepted' => OrderStatus.accepted,
        'inProgress' => OrderStatus.inProgress,
        'delivered' => OrderStatus.delivered,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.open,
      };
}

class LocationPoint {
  final double latitude;
  final double longitude;

  const LocationPoint({required this.latitude, required this.longitude});
}

class OrderEntity {
  final String orderId;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String description;
  final LocationPoint pickupLocation;
  final String pickupAddress;
  final LocationPoint dropoffLocation;
  final String dropoffAddress;
  final OrderStatus status;
  final String? driverId;
  final String? acceptedBidId;
  final double? acceptedBidAmount;
  final double? clientRating;
  final DateTime? createdAt;

  const OrderEntity({
    required this.orderId,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.description,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.status,
    this.driverId,
    this.acceptedBidId,
    this.acceptedBidAmount,
    this.clientRating,
    this.createdAt,
  });

  OrderEntity copyWith({
    OrderStatus? status,
    String? driverId,
    String? acceptedBidId,
    double? acceptedBidAmount,
    double? clientRating,
  }) {
    return OrderEntity(
      orderId: orderId,
      clientId: clientId,
      clientName: clientName,
      clientPhone: clientPhone,
      description: description,
      pickupLocation: pickupLocation,
      pickupAddress: pickupAddress,
      dropoffLocation: dropoffLocation,
      dropoffAddress: dropoffAddress,
      status: status ?? this.status,
      driverId: driverId ?? this.driverId,
      acceptedBidId: acceptedBidId ?? this.acceptedBidId,
      acceptedBidAmount: acceptedBidAmount ?? this.acceptedBidAmount,
      clientRating: clientRating ?? this.clientRating,
      createdAt: createdAt,
    );
  }
}
