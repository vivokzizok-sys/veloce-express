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

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    context.read<OrderBloc>().add(OrderWatchClientOrders(user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        title: Text(context.t('my_orders')),
        actions: [
          IconButton(
            tooltip: context.t('open_dashboard'),
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push('/client/dashboard'),
          ),
          AppMenuButton(user: user),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/client/drivers'),
        icon: const Icon(Icons.local_shipping_outlined),
        label: Text(context.t('choose_driver')),
      ),
      body: Column(
        children: [
          _ClientActiveTripBanner(clientId: user.uid),
          Expanded(
            child: BlocBuilder<OrderBloc, OrderState>(
              builder: (context, state) {
                if (state is OrdersLoaded) {
                  if (state.orders.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: context.t('no_orders_yet'),
                      subtitle: context.t('create_first_order'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: state.orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _OrderTile(order: state.orders[index]),
                  );
                }
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientActiveTripBanner extends StatelessWidget {
  final String clientId;

  const _ClientActiveTripBanner({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('clientId', isEqualTo: clientId)
          .where('status', whereIn: ['accepted', 'inProgress', 'delivered'])
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final order = OrderModel.fromFirestore(snap.data!.docs.first);
        if (order.status == OrderStatus.delivered &&
            order.clientRating != null) {
          return const SizedBox.shrink();
        }
        if (order.driverId == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final driver =
                  await context.read<OrderBloc>().getUser(order.driverId!);
              if (driver == null || !context.mounted) return;
              context.go('/active-trip', extra: {
                'order': order,
                'otherParty': driver,
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
                      '${context.t('return_active_trip')}: ${order.dropoffAddress}',
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

class _OrderTile extends StatelessWidget {
  final OrderEntity order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return InkWell(
      onTap: () => context.go('/client/order/${order.orderId}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          border: Border.all(color: AppColors.border(context)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Hero(
                tag: 'order-icon-${order.orderId}',
                child: Icon(Icons.inventory_2_outlined, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.dropoffAddress,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(
                label: context.statusText(order.status.value), color: color),
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.requested => AppColors.info,
        OrderStatus.priced => AppColors.warning,
        OrderStatus.rejected => AppColors.error,
        OrderStatus.open => AppColors.info,
        OrderStatus.bidding => AppColors.warning,
        OrderStatus.accepted => AppColors.accent,
        OrderStatus.inProgress => AppColors.success,
        OrderStatus.delivered => AppColors.grey400,
        OrderStatus.cancelled => AppColors.error,
      };
}
