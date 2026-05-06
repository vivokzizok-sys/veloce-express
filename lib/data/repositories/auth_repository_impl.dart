import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  @override
  Stream<UserEntity?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _loadUser(user.uid, emailVerified: user.emailVerified);
    });
  }

  @override
  Future<UserEntity?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null) return null;
    return _loadUser(fresh.uid, emailVerified: fresh.emailVerified);
  }

  @override
  Future<Either<Failure, UserEntity>> signIn(
    String email,
    String password,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) return const Left(AuthFailure('Sign in failed'));
      final appUser =
          await _loadUser(user.uid, emailVerified: user.emailVerified);
      if (appUser == null) {
        return const Left(AuthFailure('User profile was not found'));
      }
      return Right(appUser);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(e.message ?? 'Sign in failed'));
    } catch (_) {
      return const Left(UnexpectedFailure('Sign in failed'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
    VehicleType? vehicleType,
    File? vehiclePhoto,
  }) async {
    if (role == UserRole.driver &&
        (vehicleType == null || vehiclePhoto == null)) {
      return const Left(
        ValidationFailure('Drivers must upload a vehicle photo'),
      );
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = cred.user;
      if (firebaseUser == null) {
        return const Left(AuthFailure('Account creation failed'));
      }

      await firebaseUser.updateDisplayName(fullName.trim());

      String? vehiclePhotoBase64;
      String? vehiclePhotoContentType;
      if (role == UserRole.driver && vehiclePhoto != null) {
        final bytes = await vehiclePhoto.readAsBytes();
        // Firestore documents are limited to roughly 1 MB. Keep the encoded
        // image comfortably below that limit with profile fields included.
        if (bytes.length > 650 * 1024) {
          return const Left(
            ValidationFailure(
              'Vehicle photo is too large. Please choose a smaller image.',
            ),
          );
        }
        vehiclePhotoBase64 = base64Encode(bytes);
        vehiclePhotoContentType = 'image/jpeg';
      }

      final model = UserModel(
        uid: firebaseUser.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: role,
        isEmailVerified: false,
        isApproved: false,
        vehicleType: vehicleType,
        vehiclePhotoBase64: vehiclePhotoBase64,
        vehiclePhotoContentType: vehiclePhotoContentType,
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        ...model.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await firebaseUser.sendEmailVerification();

      return Right(model);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(e.message ?? 'Account creation failed'));
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Account creation failed'));
    } catch (_) {
      return const Left(UnexpectedFailure('Account creation failed'));
    }
  }

  @override
  Future<Either<Failure, void>> resendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return const Left(AuthFailure('Not signed in'));
      await user.sendEmailVerification();
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(
          AuthFailure(e.message ?? 'Could not send verification email'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    await _auth.signOut();
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return const Left(AuthFailure('Not signed in'));
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null) return const Left(AuthFailure('Not signed in'));
    final loaded =
        await _loadUser(fresh.uid, emailVerified: fresh.emailVerified);
    if (loaded == null) return const Left(AuthFailure('Profile not found'));
    return Right(loaded);
  }

  @override
  Stream<UserEntity?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<UserEntity?> _loadUser(
    String uid, {
    required bool emailVerified,
  }) async {
    final ref = _firestore.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) return null;

    if ((doc.data()?['isEmailVerified'] as bool? ?? false) != emailVerified) {
      await ref.update({
        'isEmailVerified': emailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final fresh = await ref.get();
    return UserModel.fromFirestore(fresh).copyWith(
      isEmailVerified: emailVerified,
    );
  }
}
