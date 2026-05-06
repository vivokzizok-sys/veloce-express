import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/app_menu_button.dart';
import '../../shared/widgets/osm_map_widgets.dart';
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
    context.read<OrderBloc>().add(OrderWatchOpenOrders());
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('jobs_near_you')),
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
                    return const EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'No jobs available',
                      subtitle:
                          'Open Veloce Express requests will appear here.',
                    );
                  }
                  return Column(
                    children: [
                      _JobsMap(orders: state.orders),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.orders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _JobTile(order: state.orders[index]),
                        ),
                      ),
                    ],
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
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Active trip: ${order.pickupAddress} -> ${order.dropoffAddress}',
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(order.description, style: AppTextStyles.title3)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 10),
            Text('Pickup', style: AppTextStyles.caption),
            Text(order.pickupAddress, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text('Drop-off', style: AppTextStyles.caption),
            Text(order.dropoffAddress, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _JobsMap extends StatelessWidget {
  final List<OrderEntity> orders;

  const _JobsMap({required this.orders});

  @override
  Widget build(BuildContext context) {
    final first = orders.first;
    final center = LatLng(
      first.pickupLocation.latitude,
      first.pickupLocation.longitude,
    );
    final markers = <Marker>[];
    for (final order in orders.take(20)) {
      final pickup = LatLng(
        order.pickupLocation.latitude,
        order.pickupLocation.longitude,
      );
      final dropoff = LatLng(
        order.dropoffLocation.latitude,
        order.dropoffLocation.longitude,
      );
      markers
        ..add(osmPinMarker(
          point: pickup,
          color: AppColors.success,
          icon: Icons.trip_origin_rounded,
          label: 'Pickup',
        ))
        ..add(osmPinMarker(
          point: dropoff,
          color: AppColors.error,
          icon: Icons.location_on_rounded,
          label: 'Drop-off',
        ));
    }

    return SizedBox(
      height: 220,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.drag |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          const OsmTiles(),
          PolylineLayer(
            polylines: [
              for (final order in orders.take(8))
                Polyline(
                  points: [
                    LatLng(
                      order.pickupLocation.latitude,
                      order.pickupLocation.longitude,
                    ),
                    LatLng(
                      order.dropoffLocation.latitude,
                      order.dropoffLocation.longitude,
                    ),
                  ],
                  color: AppColors.accent.withOpacity(0.55),
                  strokeWidth: 3,
                ),
            ],
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
