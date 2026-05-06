import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/bid_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/bid_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final FirebaseFirestore _db;

  OrderRepositoryImpl({required FirebaseFirestore db}) : _db = db;

  @override
  Future<Either<Failure, OrderEntity>> createOrder(OrderEntity order) async {
    try {
      final ref = order.orderId.isEmpty
          ? _db.collection('orders').doc()
          : _db.collection('orders').doc(order.orderId);
      final model = OrderModel.fromEntity(order.copyWith(
        status: OrderStatus.open,
      ));
      await ref.set({
        ...model.toFirestore(creating: true),
        'clientId': order.clientId,
        'bidCount': 0,
      });
      final snap = await ref.get();
      return Right(OrderModel.fromFirestore(snap));
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to create order'));
    } catch (_) {
      return const Left(UnexpectedFailure('Failed to create order'));
    }
  }

  @override
  Stream<List<OrderEntity>> watchClientOrders(String clientId) {
    return _db
        .collection('orders')
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(OrderModel.fromFirestore).toList());
  }

  @override
  Stream<List<OrderEntity>> watchOpenOrders() {
    return _db
        .collection('orders')
        .where('status', whereIn: ['open', 'bidding'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(OrderModel.fromFirestore).toList());
  }

  @override
  Stream<OrderEntity?> watchOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<BidEntity>> watchBids(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .collection('bids')
        .orderBy('amount')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BidModel.fromFirestore(orderId: orderId, doc: doc))
            .toList());
  }

  @override
  Future<Either<Failure, void>> placeBid({
    required String orderId,
    required UserEntity driver,
    required double amount,
  }) async {
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      final bidRef = orderRef.collection('bids').doc(driver.uid);
      final batch = _db.batch();
      final bid = BidModel(
        bidId: driver.uid,
        orderId: orderId,
        driverId: driver.uid,
        driverName: driver.fullName,
        driverRating: driver.rating,
        amount: amount,
        status: BidStatus.pending,
      );

      batch.set(bidRef, bid.toFirestore(creating: true));
      batch.update(orderRef, {
        'status': 'bidding',
        'bidCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await _notifyOrderClient(
        orderId: orderId,
        type: 'bid_received',
        title: 'New bid received',
        body: '${driver.fullName} bid \$${amount.toStringAsFixed(2)}',
        createdBy: driver.uid,
      );
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to place bid'));
    }
  }

  @override
  Future<Either<Failure, void>> acceptBid({
    required String orderId,
    required BidEntity bid,
  }) async {
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      await _db.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) {
          throw FirebaseException(
              plugin: 'firestore', message: 'Order not found');
        }
        final orderData = orderSnap.data() as Map<String, dynamic>;
        final status = orderData['status'] as String? ?? 'open';
        if (status == 'accepted' || status == 'inProgress') {
          throw FirebaseException(
            plugin: 'firestore',
            message: 'Order already assigned',
          );
        }

        final bidsSnap = await orderRef.collection('bids').get();
        for (final doc in bidsSnap.docs) {
          tx.update(doc.reference, {
            'status': doc.id == bid.bidId ? 'accepted' : 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.update(orderRef, {
          'status': 'accepted',
          'driverId': bid.driverId,
          'acceptedBidId': bid.bidId,
          'acceptedBidAmount': bid.amount,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _db.collection('notifications').add({
        'userId': bid.driverId,
        'orderId': orderId,
        'type': 'bid_accepted',
        'title': 'Bid accepted',
        'body': 'Your bid was accepted.',
        'createdBy': (await orderRef.get()).data()?['clientId'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to accept bid'));
    }
  }

  @override
  Future<Either<Failure, void>> rejectBid({
    required String orderId,
    required String bidId,
  }) async {
    try {
      await _db
          .collection('orders')
          .doc(orderId)
          .collection('bids')
          .doc(bidId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Failed to reject bid'));
    }
  }

  @override
  Future<UserEntity?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> _notifyOrderClient({
    required String orderId,
    required String type,
    required String title,
    required String body,
    required String createdBy,
  }) async {
    final order = await _db.collection('orders').doc(orderId).get();
    final clientId = order.data()?['clientId'] as String?;
    if (clientId == null) return;
    await _db.collection('notifications').add({
      'userId': clientId,
      'orderId': orderId,
      'type': type,
      'title': title,
      'body': body,
      'createdBy': createdBy,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
