import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/tracking_repository.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  final FirebaseFirestore _db;
  final Logger _log;

  TrackingRepositoryImpl({
    required FirebaseFirestore db,
    Logger? logger,
  })  : _db = db,
        _log = logger ?? Logger();

  @override
  Future<Either<Failure, void>> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _db.collection('users').doc(driverId).update({
        'currentLocation': GeoPoint(latitude, longitude),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Location update failed'));
    }
  }

  @override
  Stream<LocationPoint?> streamDriverLocation(String driverId) {
    return _db.collection('users').doc(driverId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data()!;
      final geoPoint = data['currentLocation'] as GeoPoint?;
      if (geoPoint == null) return null;
      return LocationPoint(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
      );
    }).handleError((Object error) {
      _log.e('streamDriverLocation error: $error');
      return null;
    });
  }

  @override
  Future<Either<Failure, void>> startTrip(String orderId) async {
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      await orderRef.update({
        'status': 'inProgress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final order = await orderRef.get();
      final data = order.data();
      final clientId = data?['clientId'] as String?;
      final driverId = data?['driverId'] as String?;
      if (clientId != null) {
        await _db.collection('notifications').add({
          'userId': clientId,
          'orderId': orderId,
          'type': 'trip_started',
          'title': 'Delivery started',
          'body': 'Your driver started the delivery.',
          'createdBy': driverId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to start trip'));
    }
  }

  @override
  Future<Either<Failure, void>> completeDelivery(String orderId) async {
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      await orderRef.update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final order = await orderRef.get();
      final data = order.data();
      final clientId = data?['clientId'] as String?;
      final driverId = data?['driverId'] as String?;
      if (clientId != null) {
        await _db.collection('notifications').add({
          'userId': clientId,
          'orderId': orderId,
          'type': 'delivered',
          'title': 'Delivery completed',
          'body': 'Your order was marked as delivered. Please rate the driver.',
          'createdBy': driverId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to complete trip'));
    }
  }

  @override
  Future<Either<Failure, void>> rateDriver({
    required String orderId,
    required String driverId,
    required double rating,
    String? comment,
  }) async {
    try {
      await _db.runTransaction((tx) async {
        final orderRef = _db.collection('orders').doc(orderId);
        final driverRef = _db.collection('users').doc(driverId);
        final snap = await tx.get(driverRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final oldRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        final count = (data['totalDeliveries'] as num?)?.toInt() ?? 0;
        final newCount = count + 1;
        final newRating = (oldRating * count + rating) / newCount;

        tx.update(driverRef, {
          'rating': newRating,
          'totalDeliveries': newCount,
          'lastRatingOrderId': orderId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(orderRef, {
          'clientRating': rating,
          'clientRatingComment': comment,
          'ratedAt': FieldValue.serverTimestamp(),
        });
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to submit rating'));
    } catch (_) {
      return const Left(UnexpectedFailure('Rating failed'));
    }
  }
}
