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
import '../../shared/widgets/subscription_gate.dart';

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
    return SubscriptionGate(
      user: user,
      child: Scaffold(
        backgroundColor: AppColors.page(context),
        appBar: AppBar(
          title: const Text('Veloce Express'),
          leading: AppMenuButton(user: user),
        ),
        body: Column(
          children: [
            _DriverStatusPanel(userId: user.uid),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                      itemCount: state.orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        bottomNavigationBar: const _DriverBottomBar(),
      ),
    );
  }
}

class _DriverStatusPanel extends StatelessWidget {
  final String userId;

  const _DriverStatusPanel({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final available = data?['isAvailable'] as bool? ?? true;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.speed_rounded,
                  label: context.t('driver_availability'),
                  value: available
                      ? context.t('available')
                      : context.t('unavailable'),
                  color: available ? AppColors.success : AppColors.grey500,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow(context),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      available
                          ? context.t('available')
                          : context.t('unavailable'),
                      style: AppTextStyles.captionMedium,
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: available,
                      activeColor: AppColors.accent,
                      onChanged: (value) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .update({
                          'isAvailable': value,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(value,
                    style: AppTextStyles.bodyMedium.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverBottomBar extends StatelessWidget {
  const _DriverBottomBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: NavigationBar(
          height: 72,
          selectedIndex: 0,
          onDestinationSelected: (index) {
            switch (index) {
              case 1:
                context.push('/driver/dashboard');
              case 2:
                context.push('/settings');
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.local_shipping_rounded),
              label: context.t('orders'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_rounded),
              label: context.t('statistics'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              label: context.t('menu'),
            ),
          ],
        ),
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
              context.push('/active-trip', extra: {
                'order': order,
                'otherParty': client,
              });
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.accentLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${context.t('active_trip')}: ${order.dropoffAddress}',
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
    final isStoreDriverRequest = order.status == OrderStatus.storeDriverPending;
    final canOpenBid = order.sourceType != 'store' && !isStoreDriverRequest;
    return InkWell(
      onTap: canOpenBid
          ? () => context.push('/driver/bid/${order.orderId}')
          : null,
      borderRadius: BorderRadius.circular(20),
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
            if (order.sourceType == 'store') ...[
              Text('${context.t('store')}: ${order.storeName ?? ''}'),
              if (order.storeItemName != null)
                Text('${context.t('item_name')}: ${order.storeItemName}'),
              if (order.productsTotal != null)
                Text(
                  '${context.t('products_total')}: ${order.productsTotal!.toStringAsFixed(0)} DA',
                ),
              Text(
                '${context.t('delivery_fee')}: ${order.deliveryFee.toStringAsFixed(0)} DA',
              ),
              if (order.totalAmount != null)
                Text(
                  '${context.t('total')}: ${order.totalAmount!.toStringAsFixed(0)} DA',
                ),
              const SizedBox(height: 10),
            ],
            Text(context.t('delivery_address'), style: AppTextStyles.caption),
            Text(order.dropoffAddress, style: AppTextStyles.bodyMedium),
            if (isStoreDriverRequest) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectStoreDelivery(context),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(context.t('reject')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _acceptStoreDelivery(context),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.t('accept')),
                    ),
                  ),
                ],
              ),
            ],
            if (order.status == OrderStatus.storeDriverRejected) ...[
              const SizedBox(height: 10),
              Text(
                context.t('you_rejected_order'),
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.storePending => AppColors.warning,
        OrderStatus.storeDriverPending => AppColors.info,
        OrderStatus.storeDriverRejected => AppColors.error,
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

  Future<void> _acceptStoreDelivery(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.orderId)
        .update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'driverRespondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _rejectStoreDelivery(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.orderId)
        .update({
      'status': 'storeDriverRejected',
      'driverRespondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (order.storeId == null) return;
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': order.storeId,
      'orderId': order.orderId,
      'type': 'store_driver_rejected',
      'title': 'Driver rejected order',
      'body': '${order.storeName ?? 'Store'} delivery was rejected.',
      'createdBy': order.driverId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
