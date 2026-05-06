import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
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
    _tabCtrl = TabController(length: 4, vsync: this);
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
        title: Row(children: [
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
        ]),
        actions: [
          AppMenuButton(user: user),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.grey400,
          indicatorColor: AppColors.accent,
          labelStyle:
              AppTextStyles.captionMedium.copyWith(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: context.t('approvals')),
            Tab(text: context.t('orders')),
            Tab(text: context.t('users')),
            Tab(text: context.t('tickets')),
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
            return _PendingUserCard(
              uid: uid,
              data: data,
              db: db,
            );
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

  const _PendingUserCard(
      {required this.uid, required this.data, required this.db});

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
    final photoBase64 = widget.data['vehiclePhotoBase64'] as String?;
    final vehicleType = widget.data['vehicleType'] as String?;
    final isDriver = role == 'driver';

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
            child: Row(children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDriver
                      ? AppColors.driverRole.withOpacity(0.1)
                      : AppColors.clientRole.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTextStyles.title3.copyWith(
                    color:
                        isDriver ? AppColors.driverRole : AppColors.clientRole,
                  ),
                )),
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
              )),
            ]),
          ),

          // Vehicle Photo (drivers only)
          if (isDriver && photoBase64 != null && photoBase64.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('vehicle_photo'),
                      style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w600)),
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
                border:
                    Border(top: BorderSide(color: AppColors.border(context)))),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Row(children: [
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
                    )),
                    Container(
                        width: 1, height: 44, color: AppColors.border(context)),
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
                    )),
                  ]),
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
    final color = isDriver
        ? AppColors.driverRole
        : isAdmin
            ? AppColors.textPrimary(context)
            : AppColors.clientRole;
    final roleLabel = context.t(isDriver
        ? 'driver'
        : isAdmin
            ? 'admin'
            : 'client');
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
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? AppColors.accent : AppColors.grey200),
                  ),
                  child: Text(e.value,
                      style: AppTextStyles.captionMedium.copyWith(
                        color: selected
                            ? AppColors.white
                            : AppColors.textSecondary(context),
                      )),
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
      child: Row(children: [
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
            Text('#${orderId.substring(0, 8).toUpperCase()}',
                style: AppTextStyles.captionMedium
                    .copyWith(color: AppColors.grey500)),
            Text(desc,
                style: AppTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(context.statusText(status),
                style: AppTextStyles.caption
                    .copyWith(color: statusColor, fontWeight: FontWeight.w700)),
          ),
          if (amount != null) ...[
            const SizedBox(height: 3),
            Text(CurrencyFormatter.da(amount),
                style: AppTextStyles.captionMedium
                    .copyWith(color: AppColors.success)),
          ],
        ]),
      ]),
    );
  }

  Color _statusColor(String s) => switch (s) {
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
          child: Row(children: [
            for (final entry in {
              'all': context.t('all'),
              'client': context.t('clients'),
              'driver': context.t('drivers'),
            }.entries)
              Expanded(
                  child: Padding(
                padding: EdgeInsets.only(right: entry.key != 'driver' ? 8 : 0),
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
                              : AppColors.grey200),
                    ),
                    child: Text(entry.value,
                        style: AppTextStyles.captionMedium.copyWith(
                            color: _roleFilter == entry.key
                                ? AppColors.white
                                : AppColors.textSecondary(context)),
                        textAlign: TextAlign.center),
                  ),
                ),
              )),
          ]),
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
      child: Row(children: [
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
            Text(email,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (role == 'driver')
              Text(
                  '⭐ ${rating.toStringAsFixed(1)} · $deliveries ${context.t('trips_label')}',
                  style: AppTextStyles.caption),
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
        )),

        // Approval toggle
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _RoleBadge(role: role),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => db.collection('users').doc(uid).update({
              'isApproved': !isApproved,
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isApproved
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isApproved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: isApproved ? AppColors.success : AppColors.error,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  isApproved ? context.t('approved') : context.t('blocked'),
                  style: AppTextStyles.caption.copyWith(
                    color: isApproved ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ]),
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

  const _DriverCommentsSheet({
    required this.db,
    required this.driverId,
  });

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
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
        ]),
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
      ]),
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
              Expanded(child: Text(name, style: AppTextStyles.bodyMedium)),
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
          Text(subtitle,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary(context))),
        ],
      ),
    );
  }
}
