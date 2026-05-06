import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/order_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/osm_map_widgets.dart';
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
  final _pickupAddress = TextEditingController(text: 'Pinned pickup');
  final _dropoffAddress = TextEditingController(text: 'Pinned drop-off');
  LatLng _pickup = const LatLng(6.5244, 3.3792);
  LatLng _dropoff = const LatLng(6.5350, 3.3950);
  bool _editingPickup = true;

  @override
  void initState() {
    super.initState();
    _seedLocation();
  }

  Future<void> _seedLocation() async {
    final pos = await LocationService().getCurrentPosition();
    if (pos == null || !mounted) return;
    setState(() {
      _pickup = LatLng(pos.latitude, pos.longitude);
      _dropoff = LatLng(pos.latitude + 0.01, pos.longitude + 0.01);
    });
  }

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
          appBar: AppBar(
            leading: IconButton(
              tooltip: context.t('back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/client/home'),
            ),
            title: Text(context.t('create_order')),
          ),
          body: Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _pickup,
                    initialZoom: 14,
                    onTap: (_, point) => setState(() {
                      if (_editingPickup) {
                        _pickup = point;
                        _pickupAddress.text =
                            'Pinned ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                      } else {
                        _dropoff = point;
                        _dropoffAddress.text =
                            'Pinned ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                      }
                    }),
                  ),
                  children: [
                    const OsmTiles(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_pickup, _dropoff],
                          color: AppColors.accent,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        osmPinMarker(
                          point: _pickup,
                          color: AppColors.success,
                          icon: Icons.trip_origin_rounded,
                          label: 'Pickup',
                        ),
                        osmPinMarker(
                          point: _dropoff,
                          color: AppColors.error,
                          icon: Icons.location_on_rounded,
                          label: 'Drop-off',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.grey100)),
                ),
                child: SafeArea(
                  top: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.trip_origin_rounded),
                              label: Text('Pickup'),
                            ),
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.location_on_outlined),
                              label: Text('Drop-off'),
                            ),
                          ],
                          selected: {_editingPickup},
                          onSelectionChanged: (set) =>
                              setState(() => _editingPickup = set.first),
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: _phone,
                          hint: 'Contact phone',
                          keyboardType: TextInputType.phone,
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: _description,
                          hint: 'Describe the item',
                          maxLines: 2,
                          validator: (v) =>
                              Validators.required(v, label: 'Description'),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Publish Request',
                          isLoading: loading,
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            final user = (context.read<AuthBloc>().state
                                    as AuthAuthenticated)
                                .user;
                            context.read<OrderBloc>().add(OrderCreateRequested(
                                  OrderEntity(
                                    orderId: '',
                                    clientId: user.uid,
                                    clientName: user.fullName,
                                    clientPhone: _phone.text.trim(),
                                    description: _description.text.trim(),
                                    pickupLocation: LocationPoint(
                                      latitude: _pickup.latitude,
                                      longitude: _pickup.longitude,
                                    ),
                                    pickupAddress: _pickupAddress.text.trim(),
                                    dropoffLocation: LocationPoint(
                                      latitude: _dropoff.latitude,
                                      longitude: _dropoff.longitude,
                                    ),
                                    dropoffAddress: _dropoffAddress.text.trim(),
                                    status: OrderStatus.open,
                                  ),
                                ));
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the map to set the selected pin.',
                          style: AppTextStyles.caption,
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
    );
  }
}
