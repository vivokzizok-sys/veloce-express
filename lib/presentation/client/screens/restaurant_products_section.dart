import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/push_notification_sender.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/validators.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class RestaurantProductsSection extends StatefulWidget {
  const RestaurantProductsSection({super.key});

  static const deliveryFee = 100.0;

  @override
  State<RestaurantProductsSection> createState() =>
      _RestaurantProductsSectionState();
}

class _RestaurantProductsSectionState extends State<RestaurantProductsSection> {
  final _search = TextEditingController();
  int _rotation = 0;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _rotationTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        if (mounted) setState(() => _rotation++);
      },
    );
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('menu_items')
          .limit(120)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _LoadFailure(
            message: context.t('products_load_error'),
            details: snap.error.toString(),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final products = _filterProducts(
          snap.data!.docs,
          wilaya: user.wilaya,
          query: _search.text,
        );
        final featured = [...products]
          ..shuffle(Random(_rotation + DateTime.now().day));
        final topProducts = products.length >= 6
            ? featured.take(3).toList()
            : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final featuredIds = topProducts.map((doc) => doc.id).toSet();
        final gridProducts = products
            .where((doc) => !featuredIds.contains(doc.id))
            .toList(growable: false);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _MarketplaceHeader(
                search: _search,
                productsCount: products.length,
              ),
            ),
            if (topProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: _FeaturedProductsRow(products: topProducts),
              ),
            if (gridProducts.isEmpty && topProducts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.restaurant_menu_outlined,
                  title: context.t('no_menu_items'),
                  subtitle: context.t('store_menu_empty'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _ProductCard(doc: gridProducts[index]),
                    childCount: gridProducts.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.54,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterProducts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String wilaya,
    required String query,
  }) {
    final normalizedQuery = _normalize(query);
    final normalizedWilaya = _normalize(wilaya);
    return docs.where((doc) {
      final data = doc.data();
      if (data['isAvailable'] == false) return false;
      final productWilaya = _normalize(data['storeWilaya'] as String? ?? '');
      if (normalizedWilaya.isNotEmpty &&
          productWilaya.isNotEmpty &&
          productWilaya != normalizedWilaya) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;

      final keywords = (data['searchKeywords'] as List<dynamic>? ?? const [])
          .map((value) => _normalize(value.toString()))
          .join(' ');
      final haystack = [
        data['name'],
        data['storeName'],
        data['description'],
        keywords,
      ].map((value) => _normalize(value?.toString() ?? '')).join(' ');
      return haystack.contains(normalizedQuery);
    }).toList();
  }
}

class _MarketplaceHeader extends StatelessWidget {
  final TextEditingController search;
  final int productsCount;

  const _MarketplaceHeader({
    required this.search,
    required this.productsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('restaurant_products'),
                        style: AppTextStyles.title2.copyWith(
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productsCount == 0
                            ? context.t('discover_restaurants')
                            : '${context.t('available_products')}: $productsCount',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const _RestaurantBanners(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                hintText: context.t('search_food_or_restaurant'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.t('cancel'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: search.clear,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantBanners extends StatefulWidget {
  const _RestaurantBanners();

  @override
  State<_RestaurantBanners> createState() => _RestaurantBannersState();
}

class _RestaurantBannersState extends State<_RestaurantBanners> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || !mounted) return;
      _controller.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_banners')
          .limit(12)
          .snapshots(),
      builder: (context, snap) {
        final banners = [...snap.data?.docs ?? const []]
          ..removeWhere((doc) => doc.data()['isActive'] == false)
          ..sort((a, b) {
            final left = (a.data()['sortOrder'] as num?)?.toInt() ?? 0;
            final right = (b.data()['sortOrder'] as num?)?.toInt() ?? 0;
            return left.compareTo(right);
          });
        if (snap.hasError || banners.isEmpty) return const _FallbackBanner();
        return SizedBox(
          height: 164,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (value) => _index = value % banners.length,
            itemBuilder: (context, index) {
              final data = banners[index % banners.length].data();
              final image = data['imageBase64'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: image.isEmpty
                        ? const _FallbackBanner(inCarousel: true)
                        : Image.memory(
                            base64Decode(image),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) =>
                                const _FallbackBanner(inCarousel: true),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  final bool inCarousel;

  const _FallbackBanner({this.inCarousel = false});

  @override
  Widget build(BuildContext context) {
    final banner = Container(
      height: 154,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.brandRed,
        borderRadius: BorderRadius.circular(inCarousel ? 0 : 22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            end: -28,
            bottom: -26,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: AppColors.brandYellow.withValues(alpha: 0.34),
                shape: BoxShape.circle,
              ),
            ),
          ),
          PositionedDirectional(
            start: -18,
            top: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.24),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.t('fresh_restaurants'),
                  style: AppTextStyles.title2.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 230,
                  child: Text(
                    context.t('fresh_restaurants_body'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.white.withValues(alpha: 0.86),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (inCarousel) return banner;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: banner,
    );
  }
}

class _FeaturedProductsRow extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> products;

  const _FeaturedProductsRow({required this.products});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final doc = products[index];
          final data = doc.data();
          final image = data['imageBase64'] as String?;
          final price = (data['price'] as num?)?.toDouble() ?? 0;
          return InkWell(
            onTap: () => _showRestaurantOrderSheet(context, doc),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 252,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 114,
                    height: double.infinity,
                    child: _ProductImage(image: image),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data['name'] as String? ?? '',
                            style: AppTextStyles.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['storeName'] as String? ??
                                context.t('restaurant'),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${price.toStringAsFixed(0)} DA',
                            style: AppTextStyles.captionMedium.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _ProductCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final image = data['imageBase64'] as String?;
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final name = data['name'] as String? ?? '';
    final restaurant = data['storeName'] as String? ?? context.t('restaurant');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: constraints.maxHeight * 0.56,
                width: double.infinity,
                child: _ProductImage(image: image),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.textPrimary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        restaurant,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${price.toStringAsFixed(0)} DA',
                              style: AppTextStyles.captionMedium.copyWith(
                                color: AppColors.accent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: FilledButton(
                              onPressed: () =>
                                  _showRestaurantOrderSheet(context, doc),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(Icons.add_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? image;

  const _ProductImage({this.image});

  @override
  Widget build(BuildContext context) {
    if (image == null || image!.isEmpty) {
      return Container(
        color: AppColors.surfaceAlt(context),
        child: Icon(
          Icons.fastfood_outlined,
          color: AppColors.textSecondary(context),
        ),
      );
    }
    return Image.memory(
      base64Decode(image!),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.surfaceAlt(context),
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final String message;
  final String details;

  const _LoadFailure({
    required this.message,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: context.t('no_menu_items'),
      subtitle: '$message\n$details',
    );
  }
}

Future<void> _showRestaurantOrderSheet(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> productDoc,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface(context),
    builder: (_) => AppSettingsScope(
      controller: context.settings,
      child: _RestaurantOrderSheet(productDoc: productDoc),
    ),
  );
}

class _RestaurantOrderSheet extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> productDoc;

  const _RestaurantOrderSheet({required this.productDoc});

  @override
  State<_RestaurantOrderSheet> createState() => _RestaurantOrderSheetState();
}

class _RestaurantOrderSheetState extends State<_RestaurantOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _address = TextEditingController();
  int _quantity = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    _name = TextEditingController(text: user.fullName);
    _phone = TextEditingController(text: user.phoneNumber);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.productDoc.data();
    final name = data['name'] as String? ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final productsTotal = price * _quantity;
    final total = productsTotal + RestaurantProductsSection.deliveryFee;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.title2),
                const SizedBox(height: 4),
                Text(
                  '${context.t('delivery_fee')}: ${RestaurantProductsSection.deliveryFee.toStringAsFixed(0)} DA',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _name,
                  hint: context.t('full_name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.t('field_required')
                      : null,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _phone,
                  hint: context.t('contact_phone'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => Validators.phone(value) == null
                      ? null
                      : context.t('algerian_phone_error'),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _address,
                  hint: context.t('delivery_address_hint'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return context.t('field_required');
                    if (text.length < 6) return context.t('address_too_short');
                    return null;
                  },
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
                    SizedBox(
                      width: 34,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _TotalRow(
                        label: context.t('products_total'),
                        value: productsTotal,
                      ),
                      const SizedBox(height: 6),
                      _TotalRow(
                        label: context.t('delivery_fee'),
                        value: RestaurantProductsSection.deliveryFee,
                      ),
                      const Divider(height: 18),
                      _TotalRow(
                        label: context.t('total'),
                        value: total,
                        strong: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: context.t('send_store_order'),
                  isLoading: _loading,
                  onPressed: () => _submit(productsTotal: productsTotal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit({required double productsTotal}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final product = widget.productDoc.data();
      final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
      final productRef = widget.productDoc.reference;
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final notificationRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      final price = (product['price'] as num?)?.toDouble() ?? 0;
      final total = productsTotal + RestaurantProductsSection.deliveryFee;
      final storeId =
          product['storeId'] as String? ?? productRef.parent.parent?.id;
      if (storeId == null) return;

      final batch = FirebaseFirestore.instance.batch();
      batch.set(orderRef, {
        'clientId': user.uid,
        'clientName': _name.text.trim(),
        'clientPhone': _phone.text.trim(),
        'description': product['name'] as String? ?? '',
        'pickupLocation': const GeoPoint(0, 0),
        'pickupAddress': product['storeAddress'] as String? ?? '',
        'dropoffLocation': const GeoPoint(0, 0),
        'dropoffAddress': _address.text.trim(),
        'status': 'storePending',
        'sourceType': 'store',
        'storeId': storeId,
        'storeName': product['storeName'],
        'storePhone': product['storePhone'],
        'storeItemName': product['name'],
        'storeItemPrice': price,
        'quantity': _quantity,
        'deliveryFee': RestaurantProductsSection.deliveryFee,
        'productsTotal': productsTotal,
        'totalAmount': total,
        'wilaya': user.wilaya,
        'commune': user.commune,
        'bidCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final title = context.t('new_restaurant_order');
      final body = '${_name.text.trim()} - ${product['name']}';
      batch.set(notificationRef, {
        'userId': storeId,
        'orderId': orderRef.id,
        'type': 'store_order',
        'title': title,
        'body': body,
        'createdBy': user.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await PushNotificationSender.send(
        toUserId: storeId,
        title: title,
        body: body,
      ).catchError((_) {});

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('order_sent_to_restaurant'))),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064b-\u065f]'), '')
      .replaceAll('\u0623', '\u0627')
      .replaceAll('\u0625', '\u0627')
      .replaceAll('\u0622', '\u0627')
      .replaceAll('\u0629', '\u0647')
      .replaceAll(RegExp(r'\s+'), ' ');
}
