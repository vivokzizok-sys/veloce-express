import 'order_entity.dart';

enum UserRole { client, driver, admin }

enum VehicleType { bike, car, truck }

extension UserRoleX on UserRole {
  String get name => switch (this) {
        UserRole.client => 'client',
        UserRole.driver => 'driver',
        UserRole.admin => 'admin',
      };

  static UserRole fromString(String value) => switch (value) {
        'driver' => UserRole.driver,
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

class UserEntity {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final bool isEmailVerified;
  final bool isApproved;
  final VehicleType? vehicleType;
  final String? vehiclePhotoBase64;
  final String? vehiclePhotoContentType;
  final double rating;
  final int totalDeliveries;
  final LocationPoint? currentLocation;
  final String? fcmToken;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.isEmailVerified,
    required this.isApproved,
    this.vehicleType,
    this.vehiclePhotoBase64,
    this.vehiclePhotoContentType,
    this.rating = 0,
    this.totalDeliveries = 0,
    this.currentLocation,
    this.fcmToken,
  });

  bool get isDriver => role == UserRole.driver;
  bool get isAdmin => role == UserRole.admin;

  UserEntity copyWith({
    bool? isEmailVerified,
    bool? isApproved,
    LocationPoint? currentLocation,
    String? fcmToken,
  }) {
    return UserEntity(
      uid: uid,
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isApproved: isApproved ?? this.isApproved,
      vehicleType: vehicleType,
      vehiclePhotoBase64: vehiclePhotoBase64,
      vehiclePhotoContentType: vehiclePhotoContentType,
      rating: rating,
      totalDeliveries: totalDeliveries,
      currentLocation: currentLocation ?? this.currentLocation,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
