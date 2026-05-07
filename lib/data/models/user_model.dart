import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.fullName,
    required super.phoneNumber,
    required super.wilaya,
    required super.commune,
    required super.role,
    required super.isEmailVerified,
    required super.isApproved,
    super.vehicleType,
    super.profilePhotoBase64,
    super.vehiclePhotoBase64,
    super.vehiclePhotoContentType,
    super.storeType,
    super.storeAddress,
    super.storeDeliveryFee,
    super.isAvailable,
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
      wilaya: data['wilaya'] as String? ?? '',
      commune: data['commune'] as String? ?? '',
      role: UserRoleX.fromString(data['role'] as String? ?? 'client'),
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      isApproved: data['isApproved'] as bool? ?? false,
      vehicleType: VehicleTypeX.fromString(data['vehicleType'] as String?),
      profilePhotoBase64: data['profilePhotoBase64'] as String?,
      vehiclePhotoBase64: data['vehiclePhotoBase64'] as String?,
      vehiclePhotoContentType:
          data['vehiclePhotoContentType'] as String? ?? 'image/jpeg',
      storeType: StoreTypeX.fromString(data['storeType'] as String?),
      storeAddress: data['storeAddress'] as String?,
      storeDeliveryFee: (data['storeDeliveryFee'] as num?)?.toDouble() ?? 100,
      isAvailable: data['isAvailable'] as bool? ?? true,
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
      'wilaya': wilaya,
      'commune': commune,
      'role': role.name,
      'isEmailVerified': isEmailVerified,
      'isApproved': isApproved,
      'vehicleType': vehicleType?.name,
      'profilePhotoBase64': profilePhotoBase64,
      'vehiclePhotoBase64': vehiclePhotoBase64,
      'vehiclePhotoContentType': vehiclePhotoContentType,
      'storeType': storeType?.name,
      'storeAddress': storeAddress,
      'storeDeliveryFee': storeDeliveryFee,
      'isAvailable': isAvailable,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
