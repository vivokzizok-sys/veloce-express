import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../shared/widgets/shared_widgets.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/client/home'),
        ),
        title: const Text('فيلوتشي إكسبرس'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .where('isApproved', isEqualTo: true)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final drivers = snap.data!.docs.map(UserModel.fromFirestore).toList()
            ..sort((a, b) => b.rating.compareTo(a.rating));
          if (drivers.isEmpty) {
            return EmptyState(
              icon: Icons.local_shipping_outlined,
              title: context.t('no_drivers'),
              subtitle: context.t('no_drivers_body'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemCount: drivers.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              if (index == 0) return const _DriversHero();
              return _DriverCard(driver: drivers[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _DriversHero extends StatelessWidget {
  const _DriversHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('choose_driver'),
            style: AppTextStyles.title1.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('choose_driver_body'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final UserEntity driver;

  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/client/driver-profile', extra: driver),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(context),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.accentLight,
                      backgroundImage: driver.profilePhotoBase64 == null
                          ? null
                          : MemoryImage(
                              base64Decode(driver.profilePhotoBase64!)),
                      child: driver.profilePhotoBase64 != null
                          ? null
                          : Text(
                              driver.fullName.isNotEmpty
                                  ? driver.fullName[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.title3.copyWith(
                                color: AppColors.accentDark,
                              ),
                            ),
                    ),
                    PositionedDirectional(
                      end: -1,
                      bottom: 1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: driver.isAvailable
                              ? AppColors.success
                              : AppColors.grey400,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName, style: AppTextStyles.title3),
                      const SizedBox(height: 4),
                      Text(
                        driver.phoneNumber,
                        style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.brandYellow,
                            size: 20,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            driver.rating.toStringAsFixed(1),
                            style: AppTextStyles.captionMedium,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context
                                  .t(driver.vehicleType?.name ?? 'motorcycle'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('/client/create-order', extra: driver),
                      icon: const Icon(Icons.local_shipping_rounded),
                      label: Text(context.t('request_driver')),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _call(driver.phoneNumber),
                      icon: const Icon(Icons.call_rounded),
                      label: Text(context.t('call')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        backgroundColor: AppColors.accentLight,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-.]'), '');
    await launchUrl(Uri(scheme: 'tel', path: normalized));
  }
}
