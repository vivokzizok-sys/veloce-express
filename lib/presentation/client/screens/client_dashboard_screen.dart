import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/currency.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    context.read<OrderBloc>().add(OrderWatchClientOrders(user.uid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.popOrGo('/client/home'),
        ),
        title: const Text('Nawdli express'),
      ),
      body: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, state) {
          final orders = state is OrdersLoaded ? state.orders : <OrderEntity>[];
          final active = orders
              .where((o) =>
                  o.status == OrderStatus.accepted ||
                  o.status == OrderStatus.inProgress)
              .length;
          final completed =
              orders.where((o) => o.status == OrderStatus.delivered).length;
          final spent = orders
              .where((o) => o.status == OrderStatus.delivered)
              .fold<double>(
                  0, (total, o) => total + (o.acceptedBidAmount ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.t('client_dashboard'),
                style: AppTextStyles.title1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('dashboard_overview'),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 14),
              _StatsGrid(items: [
                _StatItem(context.t('total_orders'), '${orders.length}',
                    Icons.receipt_long_outlined, AppColors.accent),
                _StatItem(context.t('active_orders'), '$active',
                    Icons.local_shipping_outlined, AppColors.warning),
                _StatItem(context.t('completed_orders'), '$completed',
                    Icons.check_circle_outline_rounded, AppColors.success),
                _StatItem(context.t('total_spent'), CurrencyFormatter.da(spent),
                    Icons.payments_outlined, AppColors.driverRole),
              ]),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(context.t('my_orders'),
                        style: AppTextStyles.title2),
                  ),
                  Text(
                    context.t('show_all'),
                    style: AppTextStyles.captionMedium.copyWith(
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (orders.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: context.t('no_orders'),
                  subtitle: context.t('orders_empty'),
                )
              else
                ...orders.map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DashboardOrderTile(order: order),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardOrderTile extends StatelessWidget {
  final OrderEntity order;

  const _DashboardOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final canDelete = order.status == OrderStatus.delivered ||
        order.status == OrderStatus.rejected ||
        order.status == OrderStatus.cancelled;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/client/order/${order.orderId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(context),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.accentDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.description,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.statusText(order.status.value),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                tooltip: context.t('delete'),
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.error,
                onPressed: () => FirebaseFirestore.instance
                    .collection('orders')
                    .doc(order.orderId)
                    .delete(),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
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
