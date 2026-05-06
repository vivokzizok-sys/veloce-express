import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/bid_entity.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/order_repository.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();
  @override
  List<Object?> get props => [];
}

class OrderCreateRequested extends OrderEvent {
  final OrderEntity order;
  const OrderCreateRequested(this.order);
}

class OrderWatchClientOrders extends OrderEvent {
  final String clientId;
  const OrderWatchClientOrders(this.clientId);
}

class OrderWatchOpenOrders extends OrderEvent {}

class OrderWatchDriverOrders extends OrderEvent {
  final String driverId;
  const OrderWatchDriverOrders(this.driverId);
}

class OrderWatchBids extends OrderEvent {
  final String orderId;
  const OrderWatchBids(this.orderId);
}

class OrderWatchSingle extends OrderEvent {
  final String orderId;
  const OrderWatchSingle(this.orderId);
}

class OrderBidPlaceRequested extends OrderEvent {
  final String orderId;
  final UserEntity driver;
  final double amount;
  const OrderBidPlaceRequested({
    required this.orderId,
    required this.driver,
    required this.amount,
  });
}

class OrderBidAccepted extends OrderEvent {
  final String orderId;
  final BidEntity bid;
  const OrderBidAccepted({required this.orderId, required this.bid});
}

class OrderBidRejected extends OrderEvent {
  final String orderId;
  final String bidId;
  const OrderBidRejected({required this.orderId, required this.bidId});
}

class OrderDirectPriceAccepted extends OrderEvent {
  final String orderId;
  const OrderDirectPriceAccepted(this.orderId);
}

class OrderDirectPriceRejected extends OrderEvent {
  final String orderId;
  const OrderDirectPriceRejected(this.orderId);
}

class _OrdersUpdated extends OrderEvent {
  final List<OrderEntity> orders;
  const _OrdersUpdated(this.orders);
}

class _BidsUpdated extends OrderEvent {
  final List<BidEntity> bids;
  const _BidsUpdated(this.bids);
}

class _OrderUpdated extends OrderEvent {
  final OrderEntity? order;
  const _OrderUpdated(this.order);
}

abstract class OrderState extends Equatable {
  const OrderState();
  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

class OrderProcessing extends OrderState {}

class OrdersLoaded extends OrderState {
  final List<OrderEntity> orders;
  const OrdersLoaded(this.orders);
  @override
  List<Object?> get props =>
      [orders.length, orders.map((e) => e.orderId).join()];
}

class SingleOrderLoaded extends OrderState {
  final OrderEntity? order;
  const SingleOrderLoaded(this.order);
}

class BidsLoaded extends OrderState {
  final List<BidEntity> bids;
  const BidsLoaded(this.bids);
}

class OrderCreated extends OrderState {
  final OrderEntity order;
  const OrderCreated(this.order);
}

class BidPlaced extends OrderState {}

class BidActionSuccess extends OrderState {}

class DirectPriceAcceptedSuccess extends OrderState {}

class DirectPriceRejectedSuccess extends OrderState {}

class OrderError extends OrderState {
  final String message;
  const OrderError(this.message);
}

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _repo;
  StreamSubscription<List<OrderEntity>>? _ordersSub;
  StreamSubscription<List<BidEntity>>? _bidsSub;
  StreamSubscription<OrderEntity?>? _orderSub;

  OrderBloc({required OrderRepository repository})
      : _repo = repository,
        super(OrderInitial()) {
    on<OrderCreateRequested>(_onCreate);
    on<OrderWatchClientOrders>(_onWatchClientOrders);
    on<OrderWatchOpenOrders>(_onWatchOpenOrders);
    on<OrderWatchDriverOrders>(_onWatchDriverOrders);
    on<OrderWatchBids>(_onWatchBids);
    on<OrderWatchSingle>(_onWatchSingle);
    on<OrderBidPlaceRequested>(_onPlaceBid);
    on<OrderBidAccepted>(_onAcceptBid);
    on<OrderBidRejected>(_onRejectBid);
    on<OrderDirectPriceAccepted>(_onAcceptDirectPrice);
    on<OrderDirectPriceRejected>(_onRejectDirectPrice);
    on<_OrdersUpdated>((event, emit) => emit(OrdersLoaded(event.orders)));
    on<_BidsUpdated>((event, emit) => emit(BidsLoaded(event.bids)));
    on<_OrderUpdated>((event, emit) => emit(SingleOrderLoaded(event.order)));
  }

  Future<void> _onCreate(
    OrderCreateRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderProcessing());
    final result = await _repo.createOrder(event.order);
    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (order) => emit(OrderCreated(order)),
    );
  }

  Future<void> _onWatchClientOrders(
    OrderWatchClientOrders event,
    Emitter<OrderState> emit,
  ) async {
    await _ordersSub?.cancel();
    _ordersSub = _repo.watchClientOrders(event.clientId).listen(
          (orders) => add(_OrdersUpdated(orders)),
          onError: (_) => add(const _OrdersUpdated([])),
        );
  }

  Future<void> _onWatchOpenOrders(
    OrderWatchOpenOrders event,
    Emitter<OrderState> emit,
  ) async {
    await _ordersSub?.cancel();
    _ordersSub = _repo.watchOpenOrders().listen(
          (orders) => add(_OrdersUpdated(orders)),
          onError: (_) => add(const _OrdersUpdated([])),
        );
  }

  Future<void> _onWatchDriverOrders(
    OrderWatchDriverOrders event,
    Emitter<OrderState> emit,
  ) async {
    await _ordersSub?.cancel();
    _ordersSub = _repo.watchDriverOrders(event.driverId).listen(
          (orders) => add(_OrdersUpdated(orders)),
          onError: (_) => add(const _OrdersUpdated([])),
        );
  }

  Future<void> _onWatchBids(
    OrderWatchBids event,
    Emitter<OrderState> emit,
  ) async {
    await _bidsSub?.cancel();
    _bidsSub = _repo.watchBids(event.orderId).listen(
          (bids) => add(_BidsUpdated(bids)),
          onError: (_) => add(const _BidsUpdated([])),
        );
  }

  Future<void> _onWatchSingle(
    OrderWatchSingle event,
    Emitter<OrderState> emit,
  ) async {
    await _orderSub?.cancel();
    _orderSub = _repo.watchOrder(event.orderId).listen(
          (order) => add(_OrderUpdated(order)),
          onError: (_) => add(const _OrderUpdated(null)),
        );
  }

  Future<void> _onPlaceBid(
    OrderBidPlaceRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderProcessing());
    final result = await _repo.placeBid(
      orderId: event.orderId,
      driver: event.driver,
      amount: event.amount,
    );
    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (_) => emit(BidPlaced()),
    );
  }

  Future<void> _onAcceptBid(
    OrderBidAccepted event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderProcessing());
    final result =
        await _repo.acceptBid(orderId: event.orderId, bid: event.bid);
    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (_) => emit(DirectPriceAcceptedSuccess()),
    );
  }

  Future<void> _onRejectBid(
    OrderBidRejected event,
    Emitter<OrderState> emit,
  ) async {
    final result = await _repo.rejectBid(
      orderId: event.orderId,
      bidId: event.bidId,
    );
    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (_) => emit(DirectPriceRejectedSuccess()),
    );
  }

  Future<void> _onAcceptDirectPrice(
    OrderDirectPriceAccepted event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderProcessing());
    final result = await _repo.acceptDirectPrice(event.orderId);
    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (_) => emit(BidActionSuccess()),
    );
  }

  Future<void> _onRejectDirectPrice(
    OrderDirectPriceRejected event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderProcessing());
    final result = await _repo.rejectDirectPrice(event.orderId);
    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (_) => emit(BidActionSuccess()),
    );
  }

  Future<UserEntity?> getUser(String uid) => _repo.getUser(uid);

  @override
  Future<void> close() async {
    await _ordersSub?.cancel();
    await _bidsSub?.cancel();
    await _orderSub?.cancel();
    return super.close();
  }
}
