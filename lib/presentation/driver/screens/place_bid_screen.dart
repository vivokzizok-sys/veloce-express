import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/osm_map_widgets.dart';
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
          appBar: AppBar(
            leading: IconButton(
              tooltip: context.t('back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/driver/home'),
            ),
            title: Text(context.t('place_bid')),
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
                    if (order != null) _OrderRouteMap(order: order),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (order != null) ...[
                                Text(order.description,
                                    style: AppTextStyles.title3),
                                const SizedBox(height: 8),
                                Text(
                                  '${order.pickupAddress} -> ${order.dropoffAddress}',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 18),
                              ],
                              AppTextField(
                                controller: _amount,
                                hint: 'Bid amount',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  final base = Validators.required(value,
                                      label: 'Amount');
                                  if (base != null) return base;
                                  final amount = double.tryParse(value!);
                                  return amount != null && amount > 0
                                      ? null
                                      : 'Enter a valid amount';
                                },
                                prefixIcon:
                                    const Icon(Icons.attach_money_rounded),
                              ),
                              const SizedBox(height: 18),
                              PrimaryButton(
                                label: 'Send Bid',
                                isLoading: loading,
                                onPressed: () {
                                  if (!_formKey.currentState!.validate())
                                    return;
                                  final driver = (context.read<AuthBloc>().state
                                          as AuthAuthenticated)
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

class _OrderRouteMap extends StatelessWidget {
  final OrderEntity order;

  const _OrderRouteMap({required this.order});

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(
      order.pickupLocation.latitude,
      order.pickupLocation.longitude,
    );
    final dropoff = LatLng(
      order.dropoffLocation.latitude,
      order.dropoffLocation.longitude,
    );
    return SizedBox(
      height: 260,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: pickup,
          initialZoom: 14,
        ),
        children: [
          const OsmTiles(),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [pickup, dropoff],
                color: AppColors.accent,
                strokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              osmPinMarker(
                point: pickup,
                color: AppColors.success,
                icon: Icons.trip_origin_rounded,
                label: 'Pickup',
              ),
              osmPinMarker(
                point: dropoff,
                color: AppColors.error,
                icon: Icons.location_on_rounded,
                label: 'Drop-off',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
