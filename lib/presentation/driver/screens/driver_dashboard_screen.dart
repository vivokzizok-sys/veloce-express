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
            return status == 'storeDriverPending' ||
                status == 'accepted' ||
                status == 'inProgress';
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
              ]),
              const SizedBox(height: 24),
              Text(context.t('call_logs'), style: AppTextStyles.title2),
              const SizedBox(height: 12),
              _DriverCallLogs(driverId: user.uid),
            ],
          );
        },
      ),
    );
  }
}

class _DriverCallLogs extends StatelessWidget {
  final String driverId;

  const _DriverCallLogs({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('driver_call_logs')
          .where('driverId', isEqualTo: driverId)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text(
            context.t('no_call_logs'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
          );
        }
        docs.sort((a, b) {
          final at = a.data()['createdAt'] as Timestamp?;
          final bt = b.data()['createdAt'] as Timestamp?;
          return (bt?.millisecondsSinceEpoch ?? 0)
              .compareTo(at?.millisecondsSinceEpoch ?? 0);
        });
        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_callback_outlined,
                      color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['clientName'] as String? ?? context.t('client'),
                          style: AppTextStyles.bodyMedium,
                        ),
                        Text(
                          data['clientPhone'] as String? ?? '',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    context.t('called_from_app'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary(context),
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
