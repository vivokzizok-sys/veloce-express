import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/push_notification_sender.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/currency.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
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
  double? _driverLat;
  double? _driverLng;
  late final AnimationController _pulseCtrl;
  late final bool _isDriver;

  @override
  void initState() {
    super.initState();
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
      if (widget.order.status == OrderStatus.delivered &&
          widget.order.clientRating == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showRatingSheet(context);
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _updateDriverMarker(double lat, double lng) {
    setState(() {
      _driverLat = lat;
      _driverLng = lng;
    });
  }

  Future<void> _call(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-.]'), '');
    final uri = Uri(scheme: 'tel', path: normalized);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        if (state is TrackingDeliveryConfirmed) {
          if (_isDriver) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.t('trip_completed'))),
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
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            context.go(_isDriver ? '/driver/home' : '/client/home');
          },
          child: Scaffold(
            backgroundColor: AppColors.page(context),
            body: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: _TopStatusBar(
                          order: widget.order,
                          pulseCtrl: _pulseCtrl,
                          onBack: () => context
                              .go(_isDriver ? '/driver/home' : '/client/home'),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(18),
                          children: [
                            _TripRouteOverview(
                              order: widget.order,
                              driverLat: _driverLat,
                              driverLng: _driverLng,
                              isDriver: _isDriver,
                            ),
                          ],
                        ),
                      ),
                      _BottomPanel(
                        order: widget.order,
                        otherParty: widget.otherParty,
                        isDriver: _isDriver,
                        isLoading: loading,
                        onCall: () => _call(
                          _isDriver
                              ? widget.order.clientPhone
                              : widget.otherParty.phoneNumber,
                        ),
                        onChat: () => _showChatSheet(context),
                        onComplete:
                            _isDriver ? () => _confirmTrip(context) : null,
                      ),
                    ],
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

  void _showChatSheet(BuildContext context) {
    final me = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface(context),
      builder: (_) => AppSettingsScope(
        controller: context.settings,
        child: _TripChatSheet(
          order: widget.order,
          me: me,
          otherParty: widget.otherParty,
        ),
      ),
    );
  }

  void _confirmTrip(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmTripSheet(
        isDriver: _isDriver,
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
        onSkip: () async {
          Navigator.pop(context);
          await _deleteTripChat();
          if (context.mounted) context.go('/client/home');
        },
      ),
    );
  }

  Future<void> _deleteTripChat() async {
    final messages = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.orderId)
        .collection('messages')
        .limit(200)
        .get();
    if (messages.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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
                  color: AppColors.surface(context),
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
                      context.t('live'),
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
                color: AppColors.surface(context),
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
                    ? context.t('in_transit')
                    : context.t('driver_en_route'),
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

class _TripRouteOverview extends StatelessWidget {
  final OrderEntity order;
  final double? driverLat;
  final double? driverLng;
  final bool isDriver;

  const _TripRouteOverview({
    required this.order,
    required this.driverLat,
    required this.driverLng,
    required this.isDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('return_active_trip'), style: AppTextStyles.title2),
          const SizedBox(height: 18),
          _RouteRow(
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            label: context.t('delivery_address'),
            address: order.dropoffAddress,
          ),
          if (driverLat != null && driverLng != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${isDriver ? context.t('you') : context.t('driver')}: '
                    '${driverLat!.toStringAsFixed(5)}, ${driverLng!.toStringAsFixed(5)}',
                    style: AppTextStyles.captionMedium.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
  final VoidCallback onChat;
  final VoidCallback? onComplete;

  const _BottomPanel({
    required this.order,
    required this.otherParty,
    required this.isDriver,
    required this.isLoading,
    required this.onCall,
    required this.onChat,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppColors.border(context),
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
                        isDriver
                            ? context.t('client')
                            : context.t('your_driver'),
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
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onChat();
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RouteRow(
              icon: Icons.location_on_rounded,
              color: AppColors.error,
              label: context.t('delivery_address'),
              address: order.dropoffAddress,
            ),
            if (order.acceptedBidAmount != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.t('agreed_fare'), style: AppTextStyles.body),
                  Text(
                    CurrencyFormatter.da(order.acceptedBidAmount!),
                    style:
                        AppTextStyles.title3.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => context.push('/support', extra: {
                'orderId': order.orderId,
                'reportedUserId': otherParty.uid,
              }),
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: Text(context.t('report_problem')),
            ),
            if (onComplete != null) ...[
              const SizedBox(height: 18),
              PrimaryButton(
                label: isDriver
                    ? context.t('confirm_trip')
                    : context.t('confirm_delivery_received'),
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

class _TripChatSheet extends StatefulWidget {
  final OrderEntity order;
  final UserEntity me;
  final UserEntity otherParty;

  const _TripChatSheet({
    required this.order,
    required this.me,
    required this.otherParty,
  });

  @override
  State<_TripChatSheet> createState() => _TripChatSheetState();
}

class _TripChatSheetState extends State<_TripChatSheet> {
  final _messageCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _db
          .collection('orders')
          .doc(widget.order.orderId)
          .collection('messages')
          .add({
        'senderId': widget.me.uid,
        'senderName': widget.me.fullName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('notifications').add({
        'userId': widget.otherParty.uid,
        'orderId': widget.order.orderId,
        'type': 'chat_message',
        'title': widget.me.fullName,
        'body': text,
        'createdBy': widget.me.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await PushNotificationSender.send(
        toUserId: widget.otherParty.uid,
        title: widget.me.fullName,
        body: text,
        orderId: widget.order.orderId,
        type: 'chat_message',
      ).catchError((_) {});
      _messageCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.otherParty.fullName,
                        style: AppTextStyles.title3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection('orders')
                      .doc(widget.order.orderId)
                      .collection('messages')
                      .orderBy('createdAt')
                      .limit(100)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          context.t('no_messages_yet'),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final mine = data['senderId'] == widget.me.uid;
                        return Align(
                          alignment: mine
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.accent
                                  : AppColors.surfaceAlt(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              data['text'] as String? ?? '',
                              style: AppTextStyles.body.copyWith(
                                color: mine
                                    ? AppColors.white
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: context.t('write_message'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmTripSheet extends StatelessWidget {
  final bool isDriver;
  final VoidCallback onConfirm;

  const _ConfirmTripSheet({required this.isDriver, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: AppColors.success, size: 42),
          const SizedBox(height: 16),
          Text(
            isDriver
                ? context.t('confirm_trip_question')
                : context.t('confirm_delivery_received'),
            style: AppTextStyles.title2,
          ),
          const SizedBox(height: 8),
          Text(
            isDriver
                ? context.t('confirm_trip_body')
                : context.t('confirm_delivery_body'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: context.t('yes_completed'),
            onPressed: onConfirm,
            backgroundColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: context.t('cancel'),
            onPressed: () => Navigator.pop(context),
            backgroundColor: AppColors.surfaceAlt(context),
            foregroundColor: AppColors.textPrimary(context),
          ),
        ],
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final String driverName;
  final void Function(double rating, String? comment) onSubmit;
  final Future<void> Function() onSkip;

  const _RatingSheet({
    required this.driverName,
    required this.onSubmit,
    required this.onSkip,
  });

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
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(context.t('rate_experience'), style: AppTextStyles.title2),
          const SizedBox(height: 6),
          Text(
            '${context.t('how_was')} ${widget.driverName}?',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
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
            decoration: InputDecoration(
              hintText: context.t('leave_comment'),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: context.t('submit_rating'),
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
            onPressed: widget.onSkip,
            child: Text(context.t('skip')),
          ),
        ],
      ),
    );
  }
}
