import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.fullName,
    required super.phoneNumber,
    required super.role,
    required super.isEmailVerified,
    required super.isApproved,
    super.vehicleType,
    super.profilePhotoBase64,
    super.vehiclePhotoBase64,
    super.vehiclePhotoContentType,
    super.rating,
    super.totalDeliveries,
    super.currentLocation,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final geo = data['currentLocation'] as GeoPoint?;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      role: UserRoleX.fromString(data['role'] as String? ?? 'client'),
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      isApproved: data['isApproved'] as bool? ?? false,
      vehicleType: VehicleTypeX.fromString(data['vehicleType'] as String?),
      profilePhotoBase64: data['profilePhotoBase64'] as String?,
      vehiclePhotoBase64: data['vehiclePhotoBase64'] as String?,
      vehiclePhotoContentType:
          data['vehiclePhotoContentType'] as String? ?? 'image/jpeg',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      totalDeliveries: (data['totalDeliveries'] as num?)?.toInt() ?? 0,
      currentLocation: geo == null
          ? null
          : LocationPoint(latitude: geo.latitude, longitude: geo.longitude),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'isEmailVerified': isEmailVerified,
      'isApproved': isApproved,
      'vehicleType': vehicleType?.name,
      'profilePhotoBase64': profilePhotoBase64,
      'vehiclePhotoBase64': vehiclePhotoBase64,
      'vehiclePhotoContentType': vehiclePhotoContentType,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
