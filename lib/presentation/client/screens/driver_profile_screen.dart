import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../domain/entities/user_entity.dart';
import '../../shared/widgets/shared_widgets.dart';

class DriverProfileScreen extends StatelessWidget {
  final UserEntity driver;

  const DriverProfileScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/client/drivers'),
        ),
        title: Text(context.t('driver_profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.driverRole.withOpacity(0.12),
                  backgroundImage: driver.profilePhotoBase64 == null
                      ? null
                      : MemoryImage(base64Decode(driver.profilePhotoBase64!)),
                  child: driver.profilePhotoBase64 != null
                      ? null
                      : Text(
                          driver.fullName.isNotEmpty
                              ? driver.fullName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.title1.copyWith(
                            color: AppColors.driverRole,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(driver.fullName, style: AppTextStyles.title2),
                const SizedBox(height: 6),
                Text(
                  driver.phoneNumber,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStat(
                        label: context.t('vehicle'),
                        value:
                            context.t(driver.vehicleType?.name ?? 'motorcycle'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileStat(
                        label: context.t('rating'),
                        value: driver.rating.toStringAsFixed(1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: context.t('send_delivery_request'),
            icon: const Icon(Icons.send_rounded, size: 18),
            onPressed: () =>
                context.push('/client/create-order', extra: driver),
          ),
          const SizedBox(height: 24),
          Text(context.t('reviews'), style: AppTextStyles.title3),
          const SizedBox(height: 10),
          _DriverReviews(driverId: driver.uid),
        ],
      ),
    );
  }
}

class _DriverReviews extends StatelessWidget {
  final String driverId;

  const _DriverReviews({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'delivered')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final reviews = (snap.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['clientRating'] != null &&
              ((data['clientRatingComment'] as String?)?.trim().isNotEmpty ??
                  false);
        }).toList();

        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Text(
              context.t('no_reviews'),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
          );
        }

        return Column(
          children: reviews.map((doc) {
            final data = doc.data();
            final rating = (data['clientRating'] as num?)?.toDouble() ?? 0;
            final comment = data['clientRatingComment'] as String? ?? '';
            final clientName =
                data['clientName'] as String? ?? context.t('client');
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        clientName,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
