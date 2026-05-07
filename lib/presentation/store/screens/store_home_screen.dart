import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/push_notification_sender.dart';
import '../../../core/settings/app_settings.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shared/widgets/app_menu_button.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/subscription_gate.dart';

class StoreHomeScreen extends StatelessWidget {
  const StoreHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return SubscriptionGate(
      user: user,
      child: Scaffold(
        backgroundColor: AppColors.page(context),
        appBar: AppBar(
          title: Text(context.t('restaurant_dashboard')),
          actions: [AppMenuButton(user: user)],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showMenuItemSheet(context, user),
          icon: const Icon(Icons.add_rounded),
          label: Text(context.t('add_menu_item')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _StoreHeader(userName: user.fullName, phone: user.phoneNumber),
            const SizedBox(height: 12),
            _StoreDeliveryFeeCard(store: user),
            const SizedBox(height: 16),
            Text(context.t('menu_items'), style: AppTextStyles.title3),
            const SizedBox(height: 8),
            _MenuItemsList(storeId: user.uid),
            const SizedBox(height: 20),
            Text(context.t('store_orders'), style: AppTextStyles.title3),
            const SizedBox(height: 8),
            _StoreOrdersList(storeId: user.uid),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenuItemSheet(
      BuildContext context, UserEntity store) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface(context),
      builder: (context) {
        return AppSettingsScope(
          controller: context.settings,
          child: _MenuItemSheet(store: store),
        );
      },
    );
  }
}

class _MenuItemSheet extends StatefulWidget {
  final UserEntity store;

  const _MenuItemSheet({required this.store});

  @override
  State<_MenuItemSheet> createState() => _MenuItemSheetState();
}

class _MenuItemSheetState extends State<_MenuItemSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  String? _imageBase64;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 650 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('image_too_large'))),
      );
      return;
    }
    setState(() => _imageBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    final parsedPrice = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty ||
        parsedPrice == null ||
        parsedPrice <= 0 ||
        _imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('field_required'))),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.store.uid)
          .get();
      final storeDeliveryFee =
          (storeSnapshot.data()?['storeDeliveryFee'] as num?)?.toDouble() ??
              widget.store.storeDeliveryFee;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.store.uid)
          .collection('menu_items')
          .add({
        'name': _name.text.trim(),
        'price': parsedPrice,
        'description': _description.text.trim(),
        'imageBase64': _imageBase64,
        'isAvailable': true,
        'storeId': widget.store.uid,
        'storeName': widget.store.fullName,
        'storePhone': widget.store.phoneNumber,
        'storeAddress': widget.store.storeAddress,
        'storeWilaya': widget.store.wilaya,
        'storeCommune': widget.store.commune,
        'storeDeliveryFee': storeDeliveryFee,
        'searchKeywords': _buildSearchKeywords(
          name: _name.text.trim(),
          restaurant: widget.store.fullName,
          description: _description.text.trim(),
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('add_menu_item'), style: AppTextStyles.title3),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: _imageBase64 == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined),
                            const SizedBox(height: 8),
                            Text(context.t('upload_product_photo')),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            base64Decode(_imageBase64!),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _name, hint: context.t('item_name')),
              const SizedBox(height: 10),
              AppTextField(
                controller: _price,
                hint: context.t('item_price'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: const Center(widthFactor: 1.4, child: Text('DA')),
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: _description,
                hint: context.t('description'),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: context.t('save_changes'),
                isLoading: _loading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final String userName;
  final String phone;

  const _StoreHeader({required this.userName, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: AppTextStyles.title3),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreDeliveryFeeCard extends StatefulWidget {
  final UserEntity store;

  const _StoreDeliveryFeeCard({required this.store});

  @override
  State<_StoreDeliveryFeeCard> createState() => _StoreDeliveryFeeCardState();
}

class _StoreDeliveryFeeCardState extends State<_StoreDeliveryFeeCard> {
  late final TextEditingController _fee;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fee = TextEditingController(
      text: widget.store.storeDeliveryFee.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_fee.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('write_clear_value'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.store.uid)
          .update({
        'storeDeliveryFee': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('delivery_fee_saved'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
          Expanded(
            child: AppTextField(
              controller: _fee,
              hint: context.t('store_delivery_fee'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: const Center(widthFactor: 1.4, child: Text('DA')),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t('save_changes')),
          ),
        ],
      ),
    );
  }
}

class _MenuItemsList extends StatelessWidget {
  final String storeId;

  const _MenuItemsList({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(storeId)
          .collection('menu_items')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.data!.docs.isEmpty) {
          return EmptyState(
            icon: Icons.restaurant_menu_outlined,
            title: context.t('no_menu_items'),
            subtitle: context.t('add_first_menu_item'),
          );
        }
        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data();
            final price = (data['price'] as num?)?.toDouble() ?? 0;
            final image = data['imageBase64'] as String?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: image == null || image.isEmpty
                            ? Container(
                                color: AppColors.surfaceAlt(context),
                                child: const Icon(Icons.fastfood_outlined),
                              )
                            : Image.memory(
                                base64Decode(image),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.surfaceAlt(context),
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] as String? ?? '',
                            style: AppTextStyles.bodyMedium,
                          ),
                          if ((data['description'] as String? ?? '').isNotEmpty)
                            Text(
                              data['description'] as String,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${price.toStringAsFixed(0)} DA',
                      style: AppTextStyles.captionMedium,
                    ),
                    IconButton(
                      tooltip: context.t('delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => doc.reference.delete(),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StoreOrdersList extends StatelessWidget {
  final String storeId;

  const _StoreOrdersList({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.data!.docs.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: context.t('no_orders'),
            subtitle: context.t('store_orders_empty'),
          );
        }
        return Column(
          children: snap.data!.docs.map((doc) {
            final order = OrderModel.fromFirestore(doc);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StoreOrderTile(order: order),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StoreOrderTile extends StatelessWidget {
  final OrderEntity order;

  const _StoreOrderTile({required this.order});

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
          Row(
            children: [
              Expanded(
                child: Text(
                  order.storeItemName ?? order.description,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              StatusChip(
                label: context.statusText(order.status.value),
                color: _statusColor(order.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${context.t('client')}: ${order.clientName}'),
          Text('${context.t('phone')}: ${order.clientPhone}'),
          if (order.quantity > 0)
            Text('${context.t('quantity')}: ${order.quantity}'),
          if (order.totalAmount != null)
            Text(
              '${context.t('total')}: ${order.totalAmount!.toStringAsFixed(0)} DA',
            ),
          Text('${context.t('delivery_address')}: ${order.dropoffAddress}'),
          if (order.status == OrderStatus.storePending) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: context.t('choose_driver'),
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: () => _showDriverSelection(context, order),
            ),
          ],
          if (order.driverId != null) ...[
            const SizedBox(height: 10),
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(order.driverId)
                  .get(),
              builder: (context, snap) {
                final driver = snap.data?.data();
                if (driver == null) return const SizedBox.shrink();
                final driverName =
                    driver['fullName'] as String? ?? context.t('driver');
                final driverPhone = driver['phoneNumber'] as String? ?? '';
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${context.t('driver')}: $driverName - $driverPhone',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('call_driver'),
                      icon: const Icon(Icons.call_rounded),
                      onPressed: driverPhone.isEmpty
                          ? null
                          : () {
                              final normalized = driverPhone.replaceAll(
                                RegExp(r'[\s\-.]'),
                                '',
                              );
                              launchUrl(Uri(scheme: 'tel', path: normalized));
                            },
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.storePending => AppColors.warning,
        OrderStatus.requested => AppColors.info,
        OrderStatus.priced => AppColors.warning,
        OrderStatus.rejected => AppColors.error,
        OrderStatus.open => AppColors.info,
        OrderStatus.bidding => AppColors.warning,
        OrderStatus.accepted => AppColors.accent,
        OrderStatus.inProgress => AppColors.success,
        OrderStatus.delivered => AppColors.grey400,
        OrderStatus.cancelled => AppColors.error,
      };
}

Future<void> _showDriverSelection(
  BuildContext context,
  OrderEntity order,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface(context),
    builder: (_) => AppSettingsScope(
      controller: context.settings,
      child: _DriverSelectionSheet(order: order),
    ),
  );
}

class _DriverSelectionSheet extends StatelessWidget {
  final OrderEntity order;

  const _DriverSelectionSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: FutureBuilder<_DriverAvailabilityData>(
          future: _loadDrivers(order.storeId),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: context.t('no_drivers'),
                    subtitle: snap.error.toString(),
                  ),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Text(context.t('choose_driver'), style: AppTextStyles.title2),
                const SizedBox(height: 12),
                if (data.drivers.isEmpty)
                  EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: context.t('no_drivers'),
                    subtitle: context.t('no_drivers_body'),
                  )
                else
                  for (final driver in data.drivers)
                    _DriverChoiceTile(
                      driver: driver,
                      busy: data.busyDriverIds.contains(driver.id),
                      onSelect: () => _assignDriver(context, driver),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_DriverAvailabilityData> _loadDrivers(String? storeId) async {
    final db = FirebaseFirestore.instance;
    final driverSnap = await db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isApproved', isEqualTo: true)
        .get();
    var busyIds = <String>{};
    try {
      var query = db
          .collection('orders')
          .where('status', whereIn: ['accepted', 'inProgress']);
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }
      final busySnap = await query.get();
      busyIds = busySnap.docs
          .map((doc) => doc.data()['driverId'] as String?)
          .whereType<String>()
          .toSet();
    } on FirebaseException {
      busyIds = <String>{};
    }
    return _DriverAvailabilityData(driverSnap.docs, busyIds);
  }

  Future<void> _assignDriver(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> driver,
  ) async {
    final data = driver.data();
    if (data['isAvailable'] == false) return;
    final db = FirebaseFirestore.instance;
    final pushTitle = context.t('store_delivery_assigned');
    final restaurantName = order.storeName ?? context.t('restaurant');
    final pushBody = '$restaurantName - ${order.dropoffAddress}';
    await db.collection('orders').doc(order.orderId).update({
      'status': 'accepted',
      'driverId': driver.id,
      'acceptedBidAmount': order.deliveryFee,
      'acceptedAt': FieldValue.serverTimestamp(),
      'assignedByStoreAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await db.collection('notifications').add({
      'userId': driver.id,
      'orderId': order.orderId,
      'type': 'store_delivery_assigned',
      'title': 'Restaurant delivery assigned',
      'body':
          '${order.storeName ?? 'Restaurant'} needs pickup to ${order.dropoffAddress}.',
      'createdBy': order.storeId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await PushNotificationSender.send(
      toUserId: driver.id,
      title: pushTitle,
      body: pushBody,
      orderId: order.orderId,
      type: 'store_delivery_assigned',
    ).catchError((_) {});
    if (context.mounted) Navigator.pop(context);
  }
}

class _DriverAvailabilityData {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers;
  final Set<String> busyDriverIds;

  const _DriverAvailabilityData(this.drivers, this.busyDriverIds);
}

List<String> _buildSearchKeywords({
  required String name,
  required String restaurant,
  required String description,
}) {
  final words = <String>{};
  for (final part in [name, restaurant, description]) {
    final normalized = _normalizeSearch(part);
    if (normalized.isEmpty) continue;
    words.add(normalized);
    words.addAll(normalized.split(' ').where((word) => word.length > 1));
  }
  return words.toList();
}

String _normalizeSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064b-\u065f]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _DriverChoiceTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> driver;
  final bool busy;
  final VoidCallback onSelect;

  const _DriverChoiceTile({
    required this.driver,
    required this.busy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final data = driver.data();
    final name = data['fullName'] as String? ?? context.t('driver');
    final phone = data['phoneNumber'] as String? ?? '';
    final photo = data['profilePhotoBase64'] as String?;
    final manuallyAvailable = data['isAvailable'] as bool? ?? true;
    final available = manuallyAvailable && !busy;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: photo == null || photo.isEmpty
                ? null
                : MemoryImage(base64Decode(photo)),
            child: photo == null || photo.isEmpty
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                Text(
                  phone,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  busy
                      ? context.t('driver_busy')
                      : manuallyAvailable
                          ? context.t('available')
                          : context.t('unavailable'),
                  style: AppTextStyles.caption.copyWith(
                    color: available ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: available ? onSelect : null,
            child: Text(context.t('choose')),
          ),
        ],
      ),
    );
  }
}
