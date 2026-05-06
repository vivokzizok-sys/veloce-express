import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/currency.dart';
import '../../../data/models/bid_model.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/entities/bid_entity.dart';
import '../../../domain/entities/order_entity.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots();

    return BlocListener<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (!snap.data!.exists) {
            return Scaffold(
              body: EmptyState(
                icon: Icons.search_off_rounded,
                title: context.t('order_not_found'),
                subtitle: context.t('order_missing'),
              ),
            );
          }
          final order = OrderModel.fromFirestore(snap.data!);
          return Scaffold(
            backgroundColor: AppColors.page(context),
            appBar: AppBar(
              leading: IconButton(
                tooltip: context.t('back'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/client/home'),
              ),
              title: Text(context.t('order')),
              actions: [
                IconButton(
                  tooltip: context.t('support'),
                  icon: const Icon(Icons.support_agent_rounded),
                  onPressed: () => context.push('/support', extra: {
                    'orderId': order.orderId,
                    'reportedUserId': order.driverId,
                  }),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OrderSummary(order: order),
                if (order.status == OrderStatus.open ||
                    order.status == OrderStatus.bidding) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showCancelSheet(context, order),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(context.t('cancel_order')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(context.t('bids'),
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.textPrimary(context),
                    )),
                const SizedBox(height: 10),
                _BidsList(order: order),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCancelSheet(BuildContext context, OrderEntity order) async {
    final reason = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface(context),
      builder: (_) => AppSettingsScope(
        controller: context.settings,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('cancel_order'), style: AppTextStyles.title2),
              const SizedBox(height: 14),
              AppTextField(
                controller: reason,
                hint: context.t('cancel_reason'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: context.t('cancel_order'),
                backgroundColor: AppColors.error,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.orderId)
        .update({
      'status': 'cancelled',
      'cancelReason': reason.text.trim(),
      'cancelledBy': order.clientId,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('order_cancelled'))),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final OrderEntity order;

  const _OrderSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Hero(
                tag: 'order-icon-${order.orderId}',
                child: const Icon(Icons.inventory_2_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.description,
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              StatusChip(
                label: context.statusText(order.status.value),
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(context.t('from'), style: AppTextStyles.caption),
          Text(order.pickupAddress,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary(context),
              )),
          const SizedBox(height: 10),
          Text(context.t('to'), style: AppTextStyles.caption),
          Text(order.dropoffAddress,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary(context),
              )),
          if (order.acceptedBidAmount != null) ...[
            const SizedBox(height: 14),
            Text(
              '${context.t('accepted_fare')}: ${CurrencyFormatter.da(order.acceptedBidAmount!)}',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
            ),
          ],
          if (order.status == OrderStatus.cancelled) ...[
            const SizedBox(height: 14),
            Text(
              context.t('cancelled_by'),
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _BidsList extends StatelessWidget {
  final OrderEntity order;

  const _BidsList({required this.order});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .collection('bids')
          .orderBy('amount')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final bids = snap.data!.docs
            .map((doc) =>
                BidModel.fromFirestore(orderId: order.orderId, doc: doc))
            .toList();
        if (bids.isEmpty) {
          return EmptyState(
            icon: Icons.local_offer_outlined,
            title: context.t('no_bids_yet'),
            subtitle: context.t('drivers_bid_realtime'),
          );
        }
        return Column(
          children:
              bids.map((bid) => _BidTile(order: order, bid: bid)).toList(),
        );
      },
    );
  }
}

class _BidTile extends StatelessWidget {
  final OrderEntity order;
  final BidEntity bid;

  const _BidTile({required this.order, required this.bid});

  @override
  Widget build(BuildContext context) {
    final canAct = bid.status == BidStatus.pending &&
        (order.status == OrderStatus.open ||
            order.status == OrderStatus.bidding);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bid.driverName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary(context),
                        )),
                    Text(
                      '${context.t('rating')} ${bid.driverRating.toStringAsFixed(1)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.da(bid.amount),
                style: AppTextStyles.title3.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          if (canAct) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.read<OrderBloc>().add(
                          OrderBidRejected(
                            orderId: order.orderId,
                            bidId: bid.bidId,
                          ),
                        ),
                    child: Text(context.t('reject')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      context.read<OrderBloc>().add(
                            OrderBidAccepted(orderId: order.orderId, bid: bid),
                          );
                      final driver =
                          await context.read<OrderBloc>().getUser(bid.driverId);
                      if (driver != null && context.mounted) {
                        context.go('/active-trip', extra: {
                          'order': order.copyWith(
                            status: OrderStatus.accepted,
                            driverId: bid.driverId,
                            acceptedBidId: bid.bidId,
                            acceptedBidAmount: bid.amount,
                          ),
                          'otherParty': driver,
                        });
                      }
                    },
                    child: Text(context.t('accept')),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: StatusChip(
                label: context.statusText(bid.status.value),
                color: bid.status == BidStatus.accepted
                    ? AppColors.success
                    : AppColors.grey400,
              ),
            ),
        ],
      ),
    );
  }
}
