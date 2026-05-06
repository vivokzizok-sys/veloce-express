import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
          onPressed: () => context.pop(),
        ),
        title: Text(context.t('choose_driver')),
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
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _DriverCard(driver: drivers[index]),
          );
        },
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
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/client/driver-profile', extra: driver),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.driverRole.withOpacity(0.12),
              child: Text(
                driver.fullName.isNotEmpty
                    ? driver.fullName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.driverRole,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.fullName, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 3),
                  Text(
                    '${context.t(driver.vehicleType?.name ?? 'motorcycle')} · ${driver.phoneNumber}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${context.t('rating')} ${driver.rating.toStringAsFixed(1)} · ${driver.totalDeliveries} ${context.t('trips_label')}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
