import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/auth_repository.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignInRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final VehicleType? vehicleType;
  final File? vehiclePhoto;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.vehicleType,
    this.vehiclePhoto,
  });
}

class AuthRefreshRequested extends AuthEvent {}

class AuthResendVerificationRequested extends AuthEvent {}

class AuthSignOutRequested extends AuthEvent {}

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthEmailUnverified extends AuthState {
  final UserEntity user;
  const AuthEmailUnverified(this.user);
  @override
  List<Object?> get props => [
        user.uid,
        user.isEmailVerified,
        user.fullName,
        user.phoneNumber,
        user.profilePhotoBase64,
      ];
}

class AuthPendingApproval extends AuthState {
  final UserEntity user;
  const AuthPendingApproval(this.user);
  @override
  List<Object?> get props => [
        user.uid,
        user.isApproved,
        user.fullName,
        user.phoneNumber,
        user.profilePhotoBase64,
      ];
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [
        user.uid,
        user.role,
        user.isApproved,
        user.fullName,
        user.phoneNumber,
        user.email,
        user.profilePhotoBase64,
        user.rating,
        user.totalDeliveries,
      ];
}

class AuthFailureState extends AuthState {
  final String message;
  const AuthFailureState(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  Timer? _pollTimer;

  AuthBloc({required AuthRepository authRepository})
      : _repo = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthRefreshRequested>(_onRefresh);
    on<AuthResendVerificationRequested>(_onResend);
    on<AuthSignOutRequested>(_onSignOut);
  }

  Future<void> _onCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = await _repo.currentUser();
    _emitForUser(user, emit);
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _repo.signIn(event.email, event.password);
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitForUser(user, emit),
    );
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _repo.signUp(
      email: event.email,
      password: event.password,
      fullName: event.fullName,
      phoneNumber: event.phoneNumber,
      role: event.role,
      vehicleType: event.vehicleType,
      vehiclePhoto: event.vehiclePhoto,
    );
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitForUser(user, emit),
    );
  }

  Future<void> _onRefresh(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _repo.reloadCurrentUser();
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitForUser(user, emit),
    );
  }

  Future<void> _onResend(
    AuthResendVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.resendEmailVerification();
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _pollTimer?.cancel();
    await _repo.signOut();
    emit(AuthUnauthenticated());
  }

  void _emitForUser(UserEntity? user, Emitter<AuthState> emit) {
    _pollTimer?.cancel();
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }
    if (!user.isEmailVerified) {
      emit(AuthEmailUnverified(user));
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => add(AuthRefreshRequested()),
      );
      return;
    }
    if (!user.isApproved) {
      emit(AuthPendingApproval(user));
      _pollTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => add(AuthRefreshRequested()),
      );
      return;
    }
    emit(AuthAuthenticated(user));
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
