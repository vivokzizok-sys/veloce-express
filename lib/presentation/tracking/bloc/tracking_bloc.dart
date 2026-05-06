import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/location_service.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/repositories/tracking_repository.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();
  @override
  List<Object?> get props => [];
}

class TrackingStartTrip extends TrackingEvent {
  final String orderId;
  final String driverId;
  const TrackingStartTrip({required this.orderId, required this.driverId});
}

class TrackingCompleteDelivery extends TrackingEvent {
  final String orderId;
  const TrackingCompleteDelivery(this.orderId);
}

class TrackingWatchDriver extends TrackingEvent {
  final String driverId;
  const TrackingWatchDriver(this.driverId);
}

class TrackingStop extends TrackingEvent {}

class TrackingRateDriver extends TrackingEvent {
  final String orderId;
  final String driverId;
  final double rating;
  final String? comment;
  const TrackingRateDriver({
    required this.orderId,
    required this.driverId,
    required this.rating,
    this.comment,
  });
}

class _TrackingLocationUpdated extends TrackingEvent {
  final double lat;
  final double lng;
  const _TrackingLocationUpdated(this.lat, this.lng);
}

abstract class TrackingState extends Equatable {
  const TrackingState();
  @override
  List<Object?> get props => [];
}

class TrackingInitial extends TrackingState {}

class TrackingLoading extends TrackingState {}

class TrackingActive extends TrackingState {
  final double? driverLat;
  final double? driverLng;
  final bool isDriver;

  const TrackingActive({
    this.driverLat,
    this.driverLng,
    required this.isDriver,
  });

  TrackingActive copyWith({double? driverLat, double? driverLng}) {
    return TrackingActive(
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      isDriver: isDriver,
    );
  }

  @override
  List<Object?> get props => [driverLat, driverLng, isDriver];
}

class TrackingDelivered extends TrackingState {}

class TrackingDeliveryConfirmed extends TrackingState {}

class TrackingRated extends TrackingState {}

class TrackingError extends TrackingState {
  final String message;
  const TrackingError(this.message);
}

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final TrackingRepository _repo;
  final LocationService _locationSvc;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<LocationPoint?>? _driverSub;

  TrackingBloc({
    required TrackingRepository trackingRepository,
    required LocationService locationService,
  })  : _repo = trackingRepository,
        _locationSvc = locationService,
        super(TrackingInitial()) {
    on<TrackingStartTrip>(_onStartTrip);
    on<TrackingCompleteDelivery>(_onCompleteDelivery);
    on<TrackingWatchDriver>(_onWatchDriver);
    on<TrackingStop>(_onStop);
    on<_TrackingLocationUpdated>(_onLocationUpdated);
    on<TrackingRateDriver>(_onRateDriver);
  }

  Future<void> _onStartTrip(
    TrackingStartTrip event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    final result = await _repo.startTrip(event.orderId);
    if (result.isLeft()) {
      emit(const TrackingError('Failed to start trip'));
      return;
    }

    await _locationSvc.startTracking();
    await _gpsSub?.cancel();
    _gpsSub = _locationSvc.positionStream.listen((pos) {
      _repo.updateDriverLocation(
        driverId: event.driverId,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      add(_TrackingLocationUpdated(pos.latitude, pos.longitude));
    });

    emit(const TrackingActive(isDriver: true));
  }

  Future<void> _onCompleteDelivery(
    TrackingCompleteDelivery event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _locationSvc.stopTracking();
    final result = await _repo.completeDelivery(event.orderId);
    result.fold(
      (failure) => emit(TrackingError(failure.message)),
      (_) => emit(TrackingDeliveryConfirmed()),
    );
  }

  Future<void> _onWatchDriver(
    TrackingWatchDriver event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    await _driverSub?.cancel();
    _driverSub = _repo.streamDriverLocation(event.driverId).listen((loc) {
      if (loc != null)
        add(_TrackingLocationUpdated(loc.latitude, loc.longitude));
    });
    emit(const TrackingActive(isDriver: false));
  }

  void _onLocationUpdated(
    _TrackingLocationUpdated event,
    Emitter<TrackingState> emit,
  ) {
    final current = state;
    if (current is TrackingActive) {
      emit(current.copyWith(driverLat: event.lat, driverLng: event.lng));
    }
  }

  Future<void> _onStop(
    TrackingStop event,
    Emitter<TrackingState> emit,
  ) async {
    await _gpsSub?.cancel();
    await _driverSub?.cancel();
    _gpsSub = null;
    _driverSub = null;
    await _locationSvc.stopTracking();
    emit(TrackingInitial());
  }

  Future<void> _onRateDriver(
    TrackingRateDriver event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    final result = await _repo.rateDriver(
      orderId: event.orderId,
      driverId: event.driverId,
      rating: event.rating,
      comment: event.comment,
    );
    result.fold(
      (failure) => emit(TrackingError(failure.message)),
      (_) => emit(TrackingRated()),
    );
  }

  @override
  Future<void> close() async {
    await _gpsSub?.cancel();
    await _driverSub?.cancel();
    await _locationSvc.stopTracking();
    return super.close();
  }
}
