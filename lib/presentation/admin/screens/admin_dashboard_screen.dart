import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/push_notification_sender.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/currency.dart';
import '../../../presentation/auth/bloc/auth_bloc.dart';
import '../../../presentation/shared/widgets/app_menu_button.dart';
import '../../../presentation/shared/widgets/shared_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.t('admin').toUpperCase(),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(context.t('dashboard')),
          ],
        ),
        actions: [AppMenuButton(user: user)],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.grey400,
          indicatorColor: AppColors.accent,
          labelStyle: AppTextStyles.captionMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(text: context.t('approvals')),
            Tab(text: context.t('orders')),
            Tab(text: context.t('users')),
            Tab(text: context.t('tickets')),
            Tab(text: context.t('banners')),
            Tab(text: context.t('payments')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ApprovalsTab(db: _db),
          _OrdersTab(db: _db),
          _UsersTab(db: _db),
          _TicketsTab(db: _db),
          _BannersTab(db: _db),
          _PaymentsTab(db: _db),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 1: APPROVALS
// ══════════════════════════════════════════════════════════════

class _ApprovalsTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _ApprovalsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('users')
          .where('isApproved', isEqualTo: false)
          .where('isEmailVerified', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyAdminState(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            title: context.t('all_caught_up'),
            subtitle: context.t('no_pending_approvals'),
          );
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            return _PendingUserCard(uid: uid, data: data, db: db);
          },
        );
      },
    );
  }
}

class _PendingUserCard extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;

  const _PendingUserCard({
    required this.uid,
    required this.data,
    required this.db,
  });

  @override
  State<_PendingUserCard> createState() => _PendingUserCardState();
}

class _PendingUserCardState extends State<_PendingUserCard> {
  bool _loading = false;

  Future<void> _setApproval(bool approved) async {
    setState(() => _loading = true);
    try {
      await widget.db.collection('users').doc(widget.uid).update({
        'isApproved': approved,
      });

      // Log admin action
      await widget.db.collection('admin_logs').add({
        'action': approved ? 'user_approved' : 'user_rejected',
        'targetUserId': widget.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['fullName'] as String? ?? context.t('unknown');
    final email = widget.data['email'] as String? ?? '';
    final role = widget.data['role'] as String? ?? 'client';
    final photoBase64 = role == 'store'
        ? widget.data['profilePhotoBase64'] as String?
        : widget.data['vehiclePhotoBase64'] as String?;
    final vehicleType = widget.data['vehicleType'] as String?;
    final isDriver = role == 'driver';
    final isStore = role == 'store';
    final roleColor = isDriver
        ? AppColors.driverRole
        : isStore
            ? AppColors.accent
            : AppColors.clientRole;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDriver
                        ? AppColors.driverRole.withOpacity(0.1)
                        : isStore
                            ? AppColors.accent.withOpacity(0.1)
                            : AppColors.clientRole.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTextStyles.title3.copyWith(color: roleColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodyMedium),
                      Text(email, style: AppTextStyles.caption),
                      const SizedBox(height: 3),
                      _RoleBadge(role: role, vehicleType: vehicleType),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if ((isDriver || isStore) &&
              photoBase64 != null &&
              photoBase64.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDriver
                        ? context.t('vehicle_photo')
                        : context.t('store_photo'),
                    style: AppTextStyles.captionMedium.copyWith(
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(photoBase64),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        width: double.infinity,
                        color: AppColors.surfaceAlt(context),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.grey300,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border(context))),
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      // Reject
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _setApproval(false),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(context.t('reject')),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 44,
                        color: AppColors.border(context),
                      ),
                      // Approve
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _setApproval(true),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(context.t('approve')),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: AppTextStyles.buttonSmall,
                          ),
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

class _RoleBadge extends StatelessWidget {
  final String role;
  final String? vehicleType;

  const _RoleBadge({required this.role, this.vehicleType});

  @override
  Widget build(BuildContext context) {
    final isDriver = role == 'driver';
    final isAdmin = role == 'admin';
    final isStore = role == 'store';
    final color = isDriver
        ? AppColors.driverRole
        : isStore
            ? AppColors.accent
            : isAdmin
                ? AppColors.textPrimary(context)
                : AppColors.clientRole;
    final roleLabel = context.t(
      isDriver
          ? 'driver'
          : isStore
              ? 'store'
              : isAdmin
                  ? 'admin'
                  : 'client',
    );
    final vehicleLabel = vehicleType == null ? null : context.t(vehicleType!);
    final label = isDriver
        ? '$roleLabel${vehicleLabel != null ? ' · $vehicleLabel' : ''}'
        : roleLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 2: ORDERS
// ══════════════════════════════════════════════════════════════

class _OrdersTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _OrdersTab({required this.db});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  String _filter = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = {
      'all': context.t('all'),
      'storePending': context.statusText('storePending'),
      'requested': context.statusText('requested'),
      'priced': context.statusText('priced'),
      'open': context.statusText('open'),
      'bidding': context.statusText('bidding'),
      'accepted': context.statusText('accepted'),
      'inProgress': context.statusText('inProgress'),
      'delivered': context.statusText('delivered'),
      'cancelled': context.statusText('cancelled'),
      'rejected': context.statusText('rejected'),
    };
    Query query = widget.db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(50);

    if (_filter != 'all') {
      query = query.where('status', isEqualTo: _filter);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.t('search'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: filters.entries.map((e) {
              final selected = _filter == e.key;
              return GestureDetector(
                onTap: () => setState(() => _filter = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.grey200,
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: AppTextStyles.captionMedium.copyWith(
                      color: selected
                          ? AppColors.white
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Orders list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return _EmptyAdminState(
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.grey400,
                  title: context.t('no_orders'),
                  subtitle: context.t('no_orders_filter'),
                );
              }

              final search = _search.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (search.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final text =
                    '${doc.id} ${data['description']} ${data['dropoffAddress']} ${data['clientName']}'
                        .toLowerCase();
                return text.contains(search);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final id = docs[i].id;
                  return _AdminOrderRow(orderId: id, data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminOrderRow extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const _AdminOrderRow({required this.orderId, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'open';
    final desc = data['description'] as String? ?? '';
    final amount = (data['acceptedBidAmount'] as num?)?.toDouble();
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${orderId.substring(0, 8).toUpperCase()}',
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.grey500,
                  ),
                ),
                Text(
                  desc,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.statusText(status),
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (amount != null) ...[
                const SizedBox(height: 3),
                Text(
                  CurrencyFormatter.da(amount),
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'storePending' => AppColors.warning,
        'requested' => AppColors.info,
        'priced' => AppColors.warning,
        'rejected' => AppColors.error,
        'open' => AppColors.info,
        'bidding' => AppColors.warning,
        'accepted' => AppColors.accent,
        'inProgress' => AppColors.success,
        'delivered' => AppColors.grey400,
        'cancelled' => AppColors.error,
        _ => AppColors.grey400,
      };
}

// ══════════════════════════════════════════════════════════════
// TAB 3: USERS
// ══════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _UsersTab({required this.db});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _roleFilter = 'all';

  @override
  Widget build(BuildContext context) {
    Query query = _roleFilter == 'all'
        ? widget.db
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(150)
        : widget.db
            .collection('users')
            .where('role', isEqualTo: _roleFilter)
            .limit(150);

    return Column(
      children: [
        // Role filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              for (final entry in {
                'all': context.t('all'),
                'client': context.t('clients'),
                'driver': context.t('drivers'),
                'store': context.t('stores'),
              }.entries)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key != 'store' ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _roleFilter = entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _roleFilter == entry.key
                              ? AppColors.accent
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _roleFilter == entry.key
                                ? AppColors.accent
                                : AppColors.grey200,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          style: AppTextStyles.captionMedium.copyWith(
                            color: _roleFilter == entry.key
                                ? AppColors.white
                                : AppColors.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return _EmptyAdminState(
                  icon: Icons.people_outline_rounded,
                  color: AppColors.grey400,
                  title: context.t('no_users'),
                  subtitle: context.t('no_users_found'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _UserRow(uid: doc.id, data: data, db: widget.db);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;

  const _UserRow({required this.uid, required this.data, required this.db});

  @override
  Widget build(BuildContext context) {
    final name = data['fullName'] as String? ?? context.t('unknown');
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? 'client';
    final isApproved = data['isApproved'] as bool? ?? false;
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final deliveries = data['totalDeliveries'] as int? ?? 0;
    final profilePhotoBase64 = data['profilePhotoBase64'] as String?;

    final roleColor = role == 'driver'
        ? AppColors.driverRole
        : role == 'store'
            ? AppColors.accent
            : role == 'admin'
                ? AppColors.adminRole
                : AppColors.clientRole;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withOpacity(0.1),
            backgroundImage:
                profilePhotoBase64 == null || profilePhotoBase64.isEmpty
                    ? null
                    : MemoryImage(base64Decode(profilePhotoBase64)),
            child: profilePhotoBase64 != null && profilePhotoBase64.isNotEmpty
                ? null
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.bodyMedium.copyWith(color: roleColor),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                Text(
                  email,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role == 'driver')
                  Text(
                    '⭐ ${rating.toStringAsFixed(1)} · $deliveries ${context.t('trips_label')}',
                    style: AppTextStyles.caption,
                  ),
                if (role == 'driver')
                  TextButton.icon(
                    onPressed: () => _showDriverComments(context, db, uid),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: Text(context.t('comments')),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Approval toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoleBadge(role: role),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => db.collection('users').doc(uid).update({
                  'isApproved': !isApproved,
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isApproved
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isApproved ? AppColors.success : AppColors.error,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isApproved
                            ? context.t('approved')
                            : context.t('blocked'),
                        style: AppTextStyles.caption.copyWith(
                          color:
                              isApproved ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Empty State ────────────────────────────────────────

void _showDriverComments(
  BuildContext context,
  FirebaseFirestore db,
  String driverId,
) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface(context),
    builder: (_) => AppSettingsScope(
      controller: context.settings,
      child: _DriverCommentsSheet(db: db, driverId: driverId),
    ),
  );
}

class _DriverCommentsSheet extends StatelessWidget {
  final FirebaseFirestore db;
  final String driverId;

  const _DriverCommentsSheet({required this.db, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('orders')
              .where('driverId', isEqualTo: driverId)
              .where('status', isEqualTo: 'delivered')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = (snap.data?.docs ?? []).where((doc) {
              final data = doc.data();
              return ((data['clientRatingComment'] as String?)
                      ?.trim()
                      .isNotEmpty ??
                  false);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Text(context.t('comments'), style: AppTextStyles.title2),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  Text(
                    context.t('no_comments'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  )
                else
                  for (final doc in docs)
                    _AdminCommentRow(
                      orderId: doc.id,
                      data: doc.data(),
                      onDelete: () =>
                          db.collection('orders').doc(doc.id).update({
                        'clientRatingComment': null,
                        'commentDeletedByAdmin': true,
                        'commentDeletedAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      }),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminCommentRow extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  const _AdminCommentRow({
    required this.orderId,
    required this.data,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final comment = data['clientRatingComment'] as String? ?? '';
    final clientName = data['clientName'] as String? ?? context.t('client');
    final rating = (data['clientRating'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$clientName - ${rating.toStringAsFixed(1)}',
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.t('delete_comment'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.error,
              ),
            ],
          ),
          Text(
            comment,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${context.t('order')}: ${orderId.substring(0, 8).toUpperCase()}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  final FirebaseFirestore db;

  const _TicketsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('support_tickets')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyAdminState(
            icon: Icons.support_agent_rounded,
            color: AppColors.grey400,
            title: context.t('no_tickets'),
            subtitle: context.t('all_caught_up'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            return _TicketCard(ticketId: doc.id, data: doc.data(), db: db);
          },
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String ticketId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;

  const _TicketCard({
    required this.ticketId,
    required this.data,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'support';
    final status = data['status'] as String? ?? 'open';
    final name = data['createdByName'] as String? ?? context.t('unknown');
    final email = data['createdByEmail'] as String?;
    final createdBy = data['createdBy'] as String?;
    final message = data['message'] as String? ?? '';
    final orderId = data['orderId'] as String?;
    final reportedUserId = data['reportedUserId'] as String?;
    final adminReply = data['adminReply'] as String?;
    final isOpen = status == 'open';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Icon(
                type == 'report'
                    ? Icons.report_problem_outlined
                    : Icons.support_agent_rounded,
                color: isOpen ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.bodyMedium),
                    if (email != null && email.isNotEmpty)
                      Text(
                        email,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
              StatusChip(
                label:
                    isOpen ? context.statusText('open') : context.t('closed'),
                color: isOpen ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          if (orderId != null || reportedUserId != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (orderId != null)
                  _MiniMeta(label: '${context.t('order')}: $orderId'),
                if (reportedUserId != null)
                  _MiniMeta(
                    label: '${context.t('reported_user')}: $reportedUserId',
                  ),
              ],
            ),
          ],
          if (createdBy != null) ...[
            const SizedBox(height: 8),
            _MiniMeta(label: '${context.t('reported_by')}: $createdBy'),
          ],
          if (adminReply != null && adminReply.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('admin_reply'),
                    style: AppTextStyles.captionMedium.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    adminReply,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isOpen) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: createdBy == null
                      ? null
                      : () => _replyToTicket(
                            context,
                            db,
                            ticketId: ticketId,
                            userId: createdBy,
                          ),
                  icon: const Icon(Icons.reply_rounded),
                  label: Text(context.t('reply')),
                ),
                TextButton.icon(
                  onPressed: () =>
                      db.collection('support_tickets').doc(ticketId).update({
                    'status': 'closed',
                    'closedAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(context.t('close_ticket')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _replyToTicket(
  BuildContext context,
  FirebaseFirestore db, {
  required String ticketId,
  required String userId,
}) async {
  final controller = TextEditingController();
  final reply = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AppSettingsScope(
      controller: context.settings,
      child: AlertDialog(
        title: Text(context.t('reply')),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(hintText: context.t('admin_reply')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.t('send')),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (reply == null || reply.isEmpty) return;

  await db.collection('support_tickets').doc(ticketId).update({
    'adminReply': reply,
    'adminRepliedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  await db.collection('notifications').add({
    'userId': userId,
    'type': 'support_reply',
    'title': 'Support reply',
    'body': reply,
    'createdBy': 'admin',
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
  await PushNotificationSender.send(
    toUserId: userId,
    title: 'Support reply',
    body: reply,
  ).catchError((_) {});
}

class _BannersTab extends StatefulWidget {
  final FirebaseFirestore db;

  const _BannersTab({required this.db});

  @override
  State<_BannersTab> createState() => _BannersTabState();
}

class _PaymentsTab extends StatelessWidget {
  final FirebaseFirestore db;

  const _PaymentsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('subscription_payments')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final docs = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            if (index == 0) {
              return _PaymentConfigCard(db: db, empty: docs.isEmpty);
            }
            return _PaymentCard(db: db, doc: docs[index - 1]);
          },
        );
      },
    );
  }
}

class _PaymentConfigCard extends StatefulWidget {
  final FirebaseFirestore db;
  final bool empty;

  const _PaymentConfigCard({required this.db, required this.empty});

  @override
  State<_PaymentConfigCard> createState() => _PaymentConfigCardState();
}

class _PaymentConfigCardState extends State<_PaymentConfigCard> {
  final _baridiMob = TextEditingController();
  final _fee = TextEditingController(text: '1500');
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _baridiMob.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fee = double.tryParse(_fee.text.trim());
    if (_baridiMob.text.trim().isEmpty || fee == null || fee <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.db.collection('app_config').doc('subscription').set({
        'baridiMobNumber': _baridiMob.text.trim(),
        'monthlyFee': fee,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          widget.db.collection('app_config').doc('subscription').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (!_loaded && data != null) {
          _baridiMob.text = data['baridiMobNumber'] as String? ?? '';
          _fee.text = ((data['monthlyFee'] as num?)?.toDouble() ?? 1500)
              .toStringAsFixed(0);
          _loaded = true;
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('subscription_settings'),
                      style: AppTextStyles.title3),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _baridiMob,
                    hint: context.t('baridimob_number'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _fee,
                    hint: context.t('monthly_fee'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon:
                        const Center(widthFactor: 1.4, child: Text('DA')),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: context.t('save_changes'),
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            if (widget.empty) ...[
              const SizedBox(height: 18),
              _EmptyAdminState(
                icon: Icons.payments_outlined,
                color: AppColors.accent,
                title: context.t('no_payments'),
                subtitle: context.t('no_payments_body'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final FirebaseFirestore db;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _PaymentCard({required this.db, required this.doc});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final data = widget.doc.data();
      final userId = data['userId'] as String?;
      if (userId == null) return;
      final validUntil = DateTime.now().add(const Duration(days: 31));
      final batch = widget.db.batch();
      batch.update(widget.doc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(widget.db.collection('users').doc(userId), {
        'subscriptionStatus': 'active',
        'subscriptionValidUntil': Timestamp.fromDate(validUntil),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await widget.doc.reference.update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final status = data['status'] as String? ?? 'pending';
    final receipt = data['receiptBase64'] as String?;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['fullName'] as String? ?? context.t('unknown'),
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              StatusChip(
                label: status,
                color: status == 'approved'
                    ? AppColors.success
                    : status == 'rejected'
                        ? AppColors.error
                        : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${data['role'] ?? ''} - ${data['phoneNumber'] ?? ''}'),
          Text('${context.t('total')}: ${amount.toStringAsFixed(0)} DA'),
          const SizedBox(height: 10),
          if (receipt != null && receipt.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(receipt),
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: AppColors.surfaceAlt(context),
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(context.t('reject')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _approve,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(context.t('approve')),
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

class _BannersTabState extends State<_BannersTab> {
  bool _loading = false;

  Future<void> _addBanner() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 720,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 750 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('image_too_large'))),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.db.collection('app_banners').add({
        'imageBase64': base64Encode(bytes),
        'isActive': true,
        'sortOrder': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PrimaryButton(
          label: context.t('add_banner'),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          isLoading: _loading,
          onPressed: _addBanner,
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.db
              .collection('app_banners')
              .orderBy('sortOrder')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return _EmptyAdminState(
                icon: Icons.image_outlined,
                color: AppColors.accent,
                title: context.t('no_banners'),
                subtitle: context.t('add_first_banner'),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final data = doc.data();
                final image = data['imageBase64'] as String? ?? '';
                final active = data['isActive'] as bool? ?? true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: image.isEmpty
                            ? Container(color: AppColors.surfaceAlt(context))
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
                      SwitchListTile.adaptive(
                        value: active,
                        title: Text(context.t('show_banner')),
                        onChanged: (value) => doc.reference.update({
                          'isActive': value,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }),
                        secondary: IconButton(
                          tooltip: context.t('delete'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => doc.reference.delete(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final String label;

  const _MiniMeta({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _EmptyAdminState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _EmptyAdminState({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.title3),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
