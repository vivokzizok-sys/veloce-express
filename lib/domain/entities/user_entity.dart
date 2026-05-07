import 'order_entity.dart';

enum UserRole { client, driver, store, admin }

enum VehicleType { bike, car, truck }

enum StoreType { restaurant, grocery, other }

extension UserRoleX on UserRole {
  String get name => switch (this) {
        UserRole.client => 'client',
        UserRole.driver => 'driver',
        UserRole.store => 'store',
        UserRole.admin => 'admin',
      };

  static UserRole fromString(String value) => switch (value) {
        'driver' => UserRole.driver,
        'store' => UserRole.store,
        'admin' => UserRole.admin,
        _ => UserRole.client,
      };
}

extension VehicleTypeX on VehicleType {
  String get name => switch (this) {
        VehicleType.bike => 'bike',
        VehicleType.car => 'car',
        VehicleType.truck => 'truck',
      };

  static VehicleType? fromString(String? value) => switch (value) {
        'bike' => VehicleType.bike,
        'car' => VehicleType.car,
        'truck' => VehicleType.truck,
        _ => null,
      };
}

extension StoreTypeX on StoreType {
  String get name => switch (this) {
        StoreType.restaurant => 'restaurant',
        StoreType.grocery => 'grocery',
        StoreType.other => 'other',
      };

  static StoreType? fromString(String? value) => switch (value) {
        'restaurant' => StoreType.restaurant,
        'grocery' => StoreType.grocery,
        'other' => StoreType.other,
        _ => null,
      };
}

class UserEntity {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String wilaya;
  final String commune;
  final UserRole role;
  final bool isEmailVerified;
  final bool isApproved;
  final VehicleType? vehicleType;
  final String? profilePhotoBase64;
  final String? vehiclePhotoBase64;
  final String? vehiclePhotoContentType;
  final StoreType? storeType;
  final String? storeAddress;
  final double storeDeliveryFee;
  final bool isAvailable;
  final double rating;
  final int totalDeliveries;
  final LocationPoint? currentLocation;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.wilaya,
    required this.commune,
    required this.role,
    required this.isEmailVerified,
    required this.isApproved,
    this.vehicleType,
    this.profilePhotoBase64,
    this.vehiclePhotoBase64,
    this.vehiclePhotoContentType,
    this.storeType,
    this.storeAddress,
    this.storeDeliveryFee = 100,
    this.isAvailable = true,
    this.rating = 0,
    this.totalDeliveries = 0,
    this.currentLocation,
  });

  bool get isDriver => role == UserRole.driver;
  bool get isStore => role == UserRole.store;
  bool get isAdmin => role == UserRole.admin;

  UserEntity copyWith({
    bool? isEmailVerified,
    bool? isApproved,
    LocationPoint? currentLocation,
  }) {
    return UserEntity(
      uid: uid,
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      wilaya: wilaya,
      commune: commune,
      role: role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isApproved: isApproved ?? this.isApproved,
      vehicleType: vehicleType,
      profilePhotoBase64: profilePhotoBase64,
      vehiclePhotoBase64: vehiclePhotoBase64,
      vehiclePhotoContentType: vehiclePhotoContentType,
      storeType: storeType,
      storeAddress: storeAddress,
      storeDeliveryFee: storeDeliveryFee,
      isAvailable: isAvailable,
      rating: rating,
      totalDeliveries: totalDeliveries,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}
