import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/currency.dart';
import '../../auth/bloc/auth_bloc.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(title: Text(context.t('driver_dashboard'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('driverId', isEqualTo: user.uid)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final active = docs.where((doc) {
            final status = doc.data()['status'] as String? ?? '';
            return status == 'accepted' || status == 'inProgress';
          }).length;
          final completed =
              docs.where((doc) => doc.data()['status'] == 'delivered').toList();
          final earned = completed.fold<double>(
            0,
            (total, doc) =>
                total +
                ((doc.data()['acceptedBidAmount'] as num?)?.toDouble() ?? 0),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.t('statistics'), style: AppTextStyles.title2),
              const SizedBox(height: 14),
              _StatsGrid(items: [
                _StatItem(context.t('active_orders'), '$active',
                    Icons.navigation_outlined, AppColors.warning),
                _StatItem(context.t('completed_orders'), '${completed.length}',
                    Icons.check_circle_outline_rounded, AppColors.success),
                _StatItem(
                    context.t('total_earned'),
                    CurrencyFormatter.da(earned),
                    Icons.payments_outlined,
                    AppColors.driverRole),
                _StatItem(context.t('rating'), user.rating.toStringAsFixed(1),
                    Icons.star_rounded, AppColors.warning),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.28,
      ),
      itemBuilder: (_, index) => _StatCard(item: items[index]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 24),
          const Spacer(),
          Text(item.value, style: AppTextStyles.title2),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(this.label, this.value, this.icon, this.color);
}
