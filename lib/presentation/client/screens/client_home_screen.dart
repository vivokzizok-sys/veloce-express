import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../order/bloc/order_bloc.dart';
import '../../shared/widgets/app_menu_button.dart';
import 'restaurant_products_section.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: AppMenuButton(user: user),
        title: const Text('Nawdli express'),
        actions: [_HeaderAvatar(user: user), const SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          _ClientActiveTripBanner(clientId: user.uid),
          const Expanded(child: RestaurantProductsSection()),
        ],
      ),
      bottomNavigationBar: _ClientBottomBar(user: user),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final UserEntity user;

  const _HeaderAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.accentLight,
      backgroundImage:
          user.profilePhotoBase64 == null || user.profilePhotoBase64!.isEmpty
              ? null
              : MemoryImage(base64Decode(user.profilePhotoBase64!)),
      child: user.profilePhotoBase64 != null &&
              user.profilePhotoBase64!.isNotEmpty
          ? null
          : Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'V',
              style: AppTextStyles.captionMedium.copyWith(
                color: AppColors.accentDark,
              ),
            ),
    );
  }
}

class _ClientBottomBar extends StatelessWidget {
  final UserEntity user;

  const _ClientBottomBar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: NavigationBar(
          height: 72,
          selectedIndex: 0,
          onDestinationSelected: (index) {
            switch (index) {
              case 1:
                context.push('/client/drivers');
              case 2:
                context.push('/client/dashboard');
              case 3:
                context.push('/client/stores');
              case 4:
                context.push('/settings');
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_rounded),
              label: context.t('home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_shipping_outlined),
              label: context.t('drivers'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_rounded),
              label: context.t('statistics'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              label: context.t('stores'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              label: context.t('menu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientActiveTripBanner extends StatelessWidget {
  final String clientId;

  const _ClientActiveTripBanner({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('clientId', isEqualTo: clientId)
          .where('status', whereIn: ['accepted', 'inProgress'])
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final order = OrderModel.fromFirestore(snap.data!.docs.first);
        if (order.driverId == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final driver = await context.read<OrderBloc>().getUser(
                    order.driverId!,
                  );
              if (driver == null || !context.mounted) return;
              context.push(
                '/active-trip',
                extra: {'order': order, 'otherParty': driver},
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.accentLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${context.t('return_active_trip')}: ${order.dropoffAddress}',
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
