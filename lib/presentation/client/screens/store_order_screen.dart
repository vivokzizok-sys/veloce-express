import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class StoreOrderScreen extends StatefulWidget {
  final UserEntity store;
  final Map<String, dynamic> item;

  const StoreOrderScreen({super.key, required this.store, required this.item});

  @override
  State<StoreOrderScreen> createState() => _StoreOrderScreenState();
}

class _StoreOrderScreenState extends State<StoreOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.item['name'] as String? ?? '';
    final itemPrice = (widget.item['price'] as num?)?.toDouble() ?? 0;
    final productsTotal = itemPrice * _quantity;
    final deliveryFee = widget.store.storeDeliveryFee;
    final total = productsTotal + deliveryFee;
    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrderCreated) {
          context.go('/client/order/${state.order.orderId}');
        }
        if (state is OrderError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
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
              onPressed: () =>
                  context.go('/client/store-profile', extra: widget.store),
            ),
            title: Text(context.t('store_order')),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _SelectedItemCard(
                  storeName: widget.store.fullName,
                  itemName: itemName,
                  itemPrice: itemPrice,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _address,
                  hint: context.t('delivery_address_hint'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return context.t('field_required');
                    if (text.length < 6) return context.t('address_too_short');
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _phone,
                  hint: context.t('contact_phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => Validators.phone(v) == null
                      ? null
                      : context.t('algerian_phone_error'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _notes,
                  hint: context.t('order_notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(context.t('quantity'),
                        style: AppTextStyles.bodyMedium),
                    const Spacer(),
                    IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Text('$_quantity', style: AppTextStyles.bodyMedium),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _OrderTotalBox(
                  productsTotal: productsTotal,
                  deliveryFee: deliveryFee,
                  total: total,
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: context.t('send_store_order'),
                  isLoading: loading,
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final user =
                        (context.read<AuthBloc>().state as AuthAuthenticated)
                            .user;
                    final description = [
                      itemName,
                      if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
                    ].join(' - ');
                    context.read<OrderBloc>().add(
                          OrderCreateRequested(
                            OrderEntity(
                              orderId: '',
                              clientId: user.uid,
                              clientName: user.fullName,
                              clientPhone: _phone.text.trim(),
                              description: description,
                              pickupLocation: const LocationPoint(
                                latitude: 0,
                                longitude: 0,
                              ),
                              pickupAddress: widget.store.storeAddress ??
                                  widget.store.fullName,
                              dropoffLocation: const LocationPoint(
                                latitude: 0,
                                longitude: 0,
                              ),
                              dropoffAddress: _address.text.trim(),
                              status: OrderStatus.storePending,
                              sourceType: 'store',
                              storeId: widget.store.uid,
                              storeName: widget.store.fullName,
                              storePhone: widget.store.phoneNumber,
                              storeItemName: itemName,
                              storeItemPrice: itemPrice,
                              quantity: _quantity,
                              deliveryFee: deliveryFee,
                              productsTotal: productsTotal,
                              totalAmount: total,
                            ),
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderTotalBox extends StatelessWidget {
  final double productsTotal;
  final double deliveryFee;
  final double total;

  const _OrderTotalBox({
    required this.productsTotal,
    required this.deliveryFee,
    required this.total,
  });

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
          _TotalRow(label: context.t('products_total'), value: productsTotal),
          const SizedBox(height: 6),
          _TotalRow(label: context.t('delivery_fee'), value: deliveryFee),
          const Divider(height: 18),
          _TotalRow(label: context.t('total'), value: total, strong: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool strong;

  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = strong ? AppTextStyles.bodyMedium : AppTextStyles.body;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('${value.toStringAsFixed(0)} DA', style: style),
      ],
    );
  }
}

class _SelectedItemCard extends StatelessWidget {
  final String storeName;
  final String itemName;
  final double itemPrice;

  const _SelectedItemCard({
    required this.storeName,
    required this.itemName,
    required this.itemPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 3),
                Text(
                  storeName,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${itemPrice.toStringAsFixed(0)} DA',
            style: AppTextStyles.captionMedium,
          ),
        ],
      ),
    );
  }
}
