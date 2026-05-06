import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shared/widgets/osm_map_widgets.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../bloc/tracking_bloc.dart';

class ActiveTripScreen extends StatefulWidget {
  final OrderEntity order;
  final UserEntity otherParty;

  const ActiveTripScreen({
    super.key,
    required this.order,
    required this.otherParty,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _driverPoint;
  late final AnimationController _pulseCtrl;
  late final AnimationController _panelCtrl;
  late final Animation<double> _panelAnim;
  late final bool _isDriver;

  LatLng get _pickupPoint => LatLng(
        widget.order.pickupLocation.latitude,
        widget.order.pickupLocation.longitude,
      );

  LatLng get _dropoffPoint => LatLng(
        widget.order.dropoffLocation.latitude,
        widget.order.dropoffLocation.longitude,
      );

  List<Marker> get _markers => [
        osmPinMarker(
          point: _pickupPoint,
          color: AppColors.success,
          icon: Icons.trip_origin_rounded,
          label: 'Pickup',
        ),
        osmPinMarker(
          point: _dropoffPoint,
          color: AppColors.error,
          icon: Icons.location_on_rounded,
          label: 'Drop-off',
        ),
        if (_driverPoint != null)
          osmPinMarker(
            point: _driverPoint!,
            color: AppColors.accent,
            icon: Icons.local_shipping_outlined,
            label: _isDriver ? 'You' : widget.otherParty.fullName,
          ),
      ];

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _panelAnim =
        CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic);
    _panelCtrl.forward();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final me = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    _isDriver = me.role == UserRole.driver;
    if (_isDriver) {
      context.read<TrackingBloc>().add(TrackingStartTrip(
            orderId: widget.order.orderId,
            driverId: me.uid,
          ));
    } else {
      context
          .read<TrackingBloc>()
          .add(TrackingWatchDriver(widget.otherParty.uid));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _panelCtrl.dispose();
    super.dispose();
  }

  void _updateDriverMarker(double lat, double lng) {
    final next = LatLng(lat, lng);
    setState(() => _driverPoint = next);
    _mapController.move(next, 15);
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is TrackingActive &&
            state.driverLat != null &&
            state.driverLng != null) {
          _updateDriverMarker(state.driverLat!, state.driverLng!);
        }
        if (state is TrackingDelivered) {
          if (_isDriver) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trip completed.')),
            );
            context.go('/driver/home');
          } else {
            _showRatingSheet(context);
          }
        }
        if (state is TrackingRated) context.go('/client/home');
        if (state is TrackingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final loading = state is TrackingLoading;
        return WillPopScope(
          onWillPop: () => _confirmExit(context),
          child: Scaffold(
            body: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pickupPoint,
                    initialZoom: 14,
                  ),
                  children: [
                    const OsmTiles(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_pickupPoint, _dropoffPoint],
                          color: AppColors.accent,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopStatusBar(
                    order: widget.order,
                    pulseCtrl: _pulseCtrl,
                    onBack: () async {
                      final leave = await _confirmExit(context);
                      if (!context.mounted || !leave) return;
                      context.go(_isDriver ? '/driver/home' : '/client/home');
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_panelAnim),
                    child: _BottomPanel(
                      order: widget.order,
                      otherParty: widget.otherParty,
                      isDriver: _isDriver,
                      isLoading: loading,
                      onCall: () => _call(
                        _isDriver
                            ? widget.order.clientPhone
                            : widget.otherParty.phoneNumber,
                      ),
                      onComplete:
                          _isDriver ? () => _confirmTrip(context) : null,
                    ),
                  ),
                ),
                if (loading)
                  Container(
                    color: AppColors.black.withOpacity(0.18),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmTrip(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmTripSheet(
        onConfirm: () {
          Navigator.pop(context);
          context
              .read<TrackingBloc>()
              .add(TrackingCompleteDelivery(widget.order.orderId));
        },
      ),
    );
  }

  void _showRatingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(
        driverName: widget.otherParty.fullName,
        onSubmit: (rating, comment) {
          Navigator.pop(context);
          context.read<TrackingBloc>().add(TrackingRateDriver(
                orderId: widget.order.orderId,
                driverId: widget.otherParty.uid,
                rating: rating,
                comment: comment,
              ));
        },
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave active trip?'),
        content: const Text(
          'The trip is still in progress. You can return to it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _TopStatusBar extends StatelessWidget {
  final OrderEntity order;
  final AnimationController pulseCtrl;
  final VoidCallback onBack;

  const _TopStatusBar({
    required this.order,
    required this.pulseCtrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          AppColors.success,
                          AppColors.success.withOpacity(0.35),
                          pulseCtrl.value,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.08),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                order.status == OrderStatus.inProgress
                    ? 'In transit'
                    : 'Driver en route',
                style: AppTextStyles.captionMedium.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final OrderEntity order;
  final UserEntity otherParty;
  final bool isDriver;
  final bool isLoading;
  final VoidCallback onCall;
  final VoidCallback? onComplete;

  const _BottomPanel({
    required this.order,
    required this.otherParty,
    required this.isDriver,
    required this.isLoading,
    required this.onCall,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accentLight,
                  child: Text(
                    otherParty.fullName.isNotEmpty
                        ? otherParty.fullName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDriver ? 'Client' : 'Your Driver',
                        style: AppTextStyles.caption,
                      ),
                      Text(otherParty.fullName,
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onCall();
                  },
                  icon: const Icon(Icons.phone_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RouteRow(
              icon: Icons.trip_origin_rounded,
              color: AppColors.success,
              label: 'From',
              address: order.pickupAddress,
            ),
            const SizedBox(height: 8),
            _RouteRow(
              icon: Icons.location_on_rounded,
              color: AppColors.error,
              label: 'To',
              address: order.dropoffAddress,
            ),
            if (order.acceptedBidAmount != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Agreed Fare', style: AppTextStyles.body),
                  Text(
                    '\$${order.acceptedBidAmount!.toStringAsFixed(2)}',
                    style:
                        AppTextStyles.title3.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ],
            if (isDriver && onComplete != null) ...[
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Confirm Trip',
                onPressed: isLoading ? null : onComplete,
                isLoading: isLoading,
                backgroundColor: AppColors.success,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
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
                address,
                style: AppTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfirmTripSheet extends StatelessWidget {
  final VoidCallback onConfirm;

  const _ConfirmTripSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: AppColors.success, size: 42),
          const SizedBox(height: 16),
          Text('Confirm Trip?', style: AppTextStyles.title2),
          const SizedBox(height: 8),
          Text(
            'Confirm only after handing the item to the client.',
            style: AppTextStyles.body.copyWith(color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Yes, Completed',
            onPressed: onConfirm,
            backgroundColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
            backgroundColor: AppColors.grey50,
            foregroundColor: AppColors.grey700,
          ),
        ],
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final String driverName;
  final void Function(double rating, String? comment) onSubmit;

  const _RatingSheet({required this.driverName, required this.onSubmit});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet>
    with SingleTickerProviderStateMixin {
  double _rating = 0;
  final _commentCtrl = TextEditingController();
  late final AnimationController _starCtrl;

  @override
  void initState() {
    super.initState();
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: lottie.Lottie.asset(
              'assets/animations/success.json',
              repeat: false,
            ),
          ),
          const SizedBox(height: 16),
          Text('Rate your experience', style: AppTextStyles.title2),
          const SizedBox(height: 6),
          Text(
            'How was ${widget.driverName}?',
            style: AppTextStyles.body.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 22),
          ScaleTransition(
            scale: CurvedAnimation(parent: _starCtrl, curve: Curves.elasticOut),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = (i + 1).toDouble());
                  },
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.warning : AppColors.grey200,
                    size: 36,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Leave a comment (optional)',
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Submit Rating',
            onPressed: _rating > 0
                ? () => widget.onSubmit(
                      _rating,
                      _commentCtrl.text.trim().isEmpty
                          ? null
                          : _commentCtrl.text.trim(),
                    )
                : null,
          ),
          TextButton(
            onPressed: () => widget.onSubmit(0, null),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}
