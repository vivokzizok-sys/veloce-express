import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/bid_entity.dart';
import '../entities/order_entity.dart';
import '../entities/user_entity.dart';

abstract class OrderRepository {
  Future<Either<Failure, OrderEntity>> createOrder(OrderEntity order);
  Stream<List<OrderEntity>> watchClientOrders(String clientId);
  Stream<List<OrderEntity>> watchOpenOrders();
  Stream<List<OrderEntity>> watchDriverOrders(String driverId);
  Stream<OrderEntity?> watchOrder(String orderId);
  Stream<List<BidEntity>> watchBids(String orderId);
  Future<Either<Failure, void>> placeBid({
    required String orderId,
    required UserEntity driver,
    required double amount,
  });
  Future<Either<Failure, void>> acceptBid({
    required String orderId,
    required BidEntity bid,
  });
  Future<Either<Failure, void>> rejectBid({
    required String orderId,
    required String bidId,
  });
  Future<Either<Failure, void>> acceptDirectPrice(String orderId);
  Future<Either<Failure, void>> rejectDirectPrice(String orderId);
  Future<UserEntity?> getUser(String uid);
}
