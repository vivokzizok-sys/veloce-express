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
          onPressed: () => context.pop(),
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
                  child: Text(
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileStat(
                        label: context.t('trips_label'),
                        value: '${driver.totalDeliveries}',
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
        ],
      ),
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
