import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/app_menu_button.dart';
import '../../shared/widgets/shared_widgets.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    context.read<OrderBloc>().add(OrderWatchDriverOrders(user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        title: Text(context.t('my_delivery_requests')),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                user.rating.toStringAsFixed(1),
                style: AppTextStyles.captionMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: context.t('open_dashboard'),
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push('/driver/dashboard'),
          ),
          AppMenuButton(user: user),
        ],
      ),
      body: Column(
        children: [
          _DriverActiveTripBanner(driverId: user.uid),
          Expanded(
            child: BlocBuilder<OrderBloc, OrderState>(
              builder: (context, state) {
                if (state is OrdersLoaded) {
                  if (state.orders.isEmpty) {
                    return EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: context.t('no_driver_requests'),
                      subtitle: context.t('no_driver_requests_body'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _JobTile(order: state.orders[index]),
                  );
                }
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverActiveTripBanner extends StatelessWidget {
  final String driverId;

  const _DriverActiveTripBanner({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['accepted', 'inProgress'])
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final order = OrderModel.fromFirestore(snap.data!.docs.first);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final client =
                  await context.read<OrderBloc>().getUser(order.clientId);
              if (client == null || !context.mounted) return;
              context.go('/active-trip', extra: {
                'order': order,
                'otherParty': client,
              });
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? AppColors.accent.withOpacity(0.14)
                    : AppColors.accentLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${context.t('active_trip')}: ${order.pickupAddress} -> ${order.dropoffAddress}',
                      style: AppTextStyles.captionMedium.copyWith(
                        color: AppColors.accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JobTile extends StatelessWidget {
  final OrderEntity order;

  const _JobTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/driver/bid/${order.orderId}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Expanded(
                    child:
                        Text(order.description, style: AppTextStyles.title3)),
                StatusChip(
                  label: context.statusText(order.status.value),
                  color: _statusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(context.t('pickup'), style: AppTextStyles.caption),
            Text(order.pickupAddress, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text(context.t('dropoff'), style: AppTextStyles.caption),
            Text(order.dropoffAddress, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.requested => AppColors.info,
        OrderStatus.priced => AppColors.warning,
        OrderStatus.accepted => AppColors.accent,
        OrderStatus.inProgress => AppColors.success,
        OrderStatus.delivered => AppColors.grey400,
        OrderStatus.rejected => AppColors.error,
        OrderStatus.cancelled => AppColors.error,
        OrderStatus.open => AppColors.info,
        OrderStatus.bidding => AppColors.warning,
      };
}
