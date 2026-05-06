import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.orderId,
    required super.clientId,
    required super.clientName,
    required super.clientPhone,
    required super.description,
    required super.pickupLocation,
    required super.pickupAddress,
    required super.dropoffLocation,
    required super.dropoffAddress,
    required super.status,
    super.driverId,
    super.acceptedBidId,
    super.acceptedBidAmount,
    super.clientRating,
    super.createdAt,
  });

  factory OrderModel.fromEntity(OrderEntity order) {
    return OrderModel(
      orderId: order.orderId,
      clientId: order.clientId,
      clientName: order.clientName,
      clientPhone: order.clientPhone,
      description: order.description,
      pickupLocation: order.pickupLocation,
      pickupAddress: order.pickupAddress,
      dropoffLocation: order.dropoffLocation,
      dropoffAddress: order.dropoffAddress,
      status: order.status,
      driverId: order.driverId,
      acceptedBidId: order.acceptedBidId,
      acceptedBidAmount: order.acceptedBidAmount,
      clientRating: order.clientRating,
      createdAt: order.createdAt,
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final pickup = data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0);
    final dropoff =
        data['dropoffLocation'] as GeoPoint? ?? const GeoPoint(0, 0);
    return OrderModel(
      orderId: doc.id,
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? '',
      clientPhone: data['clientPhone'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pickupLocation:
          LocationPoint(latitude: pickup.latitude, longitude: pickup.longitude),
      pickupAddress: data['pickupAddress'] as String? ?? '',
      dropoffLocation: LocationPoint(
        latitude: dropoff.latitude,
        longitude: dropoff.longitude,
      ),
      dropoffAddress: data['dropoffAddress'] as String? ?? '',
      status: OrderStatusX.fromString(data['status'] as String? ?? 'open'),
      driverId: data['driverId'] as String?,
      acceptedBidId: data['acceptedBidId'] as String?,
      acceptedBidAmount: (data['acceptedBidAmount'] as num?)?.toDouble(),
      clientRating: (data['clientRating'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore({bool creating = false}) {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'description': description,
      'pickupLocation':
          GeoPoint(pickupLocation.latitude, pickupLocation.longitude),
      'pickupAddress': pickupAddress,
      'dropoffLocation':
          GeoPoint(dropoffLocation.latitude, dropoffLocation.longitude),
      'dropoffAddress': dropoffAddress,
      'status': status.value,
      'driverId': driverId,
      'acceptedBidId': acceptedBidId,
      'acceptedBidAmount': acceptedBidAmount,
      'clientRating': clientRating,
      'updatedAt': FieldValue.serverTimestamp(),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
