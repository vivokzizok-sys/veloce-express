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
import '../../shared/widgets/shared_widgets.dart';

class PlaceBidScreen extends StatefulWidget {
  final String orderId;

  const PlaceBidScreen({super.key, required this.orderId});

  @override
  State<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends State<PlaceBidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is BidPlaced) context.go('/driver/home');
        if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final loading = state is OrderProcessing;
        return Scaffold(
          backgroundColor: AppColors.page(context),
          appBar: AppBar(
            leading: IconButton(
              tooltip: context.t('back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/driver/home'),
            ),
            title: Text(context.t('delivery_request')),
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, snap) {
              final order = snap.hasData && snap.data!.exists
                  ? OrderModel.fromFirestore(snap.data!)
                  : null;
              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (order != null) ...[
                                _OrderRouteCard(order: order),
                                const SizedBox(height: 18),
                              ],
                              if (order?.status == OrderStatus.requested) ...[
                                AppTextField(
                                  controller: _amount,
                                  hint: context.t('delivery_price'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return context.t('field_required');
                                    }
                                    final amount = double.tryParse(value);
                                    return amount != null && amount > 0
                                        ? null
                                        : context.t('valid_amount');
                                  },
                                  prefixIcon: const Center(
                                    widthFactor: 1.4,
                                    child: Text('DA'),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                PrimaryButton(
                                  label: context.t('send_price'),
                                  isLoading: loading,
                                  onPressed: () {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final driver = (context
                                            .read<AuthBloc>()
                                            .state as AuthAuthenticated)
                                        .user;
                                    context
                                        .read<OrderBloc>()
                                        .add(OrderBidPlaceRequested(
                                          orderId: widget.orderId,
                                          driver: driver,
                                          amount: double.parse(_amount.text),
                                        ));
                                  },
                                ),
                              ] else if (order?.status ==
                                      OrderStatus.accepted ||
                                  order?.status == OrderStatus.inProgress) ...[
                                PrimaryButton(
                                  label: context.t('active_trip'),
                                  onPressed: () async {
                                    final client = await context
                                        .read<OrderBloc>()
                                        .getUser(order!.clientId);
                                    if (client == null || !context.mounted) {
                                      return;
                                    }
                                    context.go('/active-trip', extra: {
                                      'order': order,
                                      'otherParty': client,
                                    });
                                  },
                                ),
                              ] else if (order?.acceptedBidAmount != null) ...[
                                Text(
                                  '${context.t('price_sent')}: ${order!.acceptedBidAmount!.toStringAsFixed(0)} DA',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _OrderRouteCard extends StatelessWidget {
  final OrderModel order;

  const _OrderRouteCard({required this.order});

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
          Text(order.description, style: AppTextStyles.title3),
          const SizedBox(height: 12),
          _RouteLine(
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            label: context.t('delivery_address'),
            value: order.dropoffAddress,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RouteLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
