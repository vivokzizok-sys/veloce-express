import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/currency.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';

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
      appBar: AppBar(title: Text(context.t('client_dashboard'))),
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
              Text(context.t('statistics'), style: AppTextStyles.title2),
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
