import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _dropoffAddress = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _description.dispose();
    _pickupAddress.dispose();
    _dropoffAddress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrderCreated)
          context.go('/client/order/${state.order.orderId}');
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
              onPressed: () => context.go('/client/home'),
            ),
            title: Text(context.t('create_order')),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(context.t('pickup'), style: AppTextStyles.captionMedium),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _pickupAddress,
                    hint: context.t('pickup_address'),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return context.t('field_required');
                      return text.length >= 6
                          ? null
                          : context.t('address_too_short');
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(context.t('dropoff'),
                      style: AppTextStyles.captionMedium),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _dropoffAddress,
                    hint: context.t('dropoff_address'),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return context.t('field_required');
                      if (text.length < 6)
                        return context.t('address_too_short');
                      if (text.toLowerCase() ==
                          _pickupAddress.text.trim().toLowerCase()) {
                        return context.t('addresses_must_differ');
                      }
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
                    controller: _description,
                    hint: context.t('describe_item'),
                    maxLines: 3,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.t('field_required')
                        : null,
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: context.t('publish_request'),
                    isLoading: loading,
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      final user =
                          (context.read<AuthBloc>().state as AuthAuthenticated)
                              .user;
                      context.read<OrderBloc>().add(OrderCreateRequested(
                            OrderEntity(
                              orderId: '',
                              clientId: user.uid,
                              clientName: user.fullName,
                              clientPhone: _phone.text.trim(),
                              description: _description.text.trim(),
                              pickupLocation: const LocationPoint(
                                latitude: 0,
                                longitude: 0,
                              ),
                              pickupAddress: _pickupAddress.text.trim(),
                              dropoffLocation: const LocationPoint(
                                latitude: 0,
                                longitude: 0,
                              ),
                              dropoffAddress: _dropoffAddress.text.trim(),
                              status: OrderStatus.open,
                            ),
                          ));
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
