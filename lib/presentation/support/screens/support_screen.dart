import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class SupportScreen extends StatefulWidget {
  final String? orderId;
  final String? reportedUserId;

  const SupportScreen({
    super.key,
    this.orderId,
    this.reportedUserId,
  });

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _type = 'support';
  bool _loading = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'type': _type,
        'status': 'open',
        'createdBy': user.uid,
        'createdByName': user.fullName,
        'createdByRole': user.role.name,
        'orderId': widget.orderId,
        'reportedUserId': widget.reportedUserId,
        'message': _message.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('support_sent'))),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(context.t('support')),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _SupportHeader(user: user),
              const SizedBox(height: 18),
              Text(context.t('ticket_type'),
                  style: AppTextStyles.captionMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: AppColors.surface(context),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceAlt(context),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'support',
                    child: Text(context.t('support_request')),
                  ),
                  DropdownMenuItem(
                    value: 'report',
                    child: Text(context.t('report_problem')),
                  ),
                  DropdownMenuItem(
                    value: 'payment',
                    child: Text(context.t('payment_issue')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              if (widget.orderId != null) ...[
                const SizedBox(height: 14),
                _InfoPill(
                  icon: Icons.receipt_long_outlined,
                  label: '${context.t('order')}: ${widget.orderId}',
                ),
              ],
              if (widget.reportedUserId != null) ...[
                const SizedBox(height: 14),
                _InfoPill(
                  icon: Icons.person_off_outlined,
                  label:
                      '${context.t('reported_user')}: ${widget.reportedUserId}',
                ),
              ],
              const SizedBox(height: 14),
              AppTextField(
                controller: _message,
                hint: context.t('support_message'),
                maxLines: 5,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return context.t('field_required');
                  if (text.length < 12) return context.t('message_too_short');
                  return null;
                },
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: context.t('send'),
                isLoading: _loading,
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded, size: 18),
              ),
              const SizedBox(height: 24),
              _MyTickets(userId: user.uid),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyTickets extends StatelessWidget {
  final String userId;

  const _MyTickets({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('createdBy', isEqualTo: userId)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        docs.sort((a, b) {
          final at = a.data()['createdAt'] as Timestamp?;
          final bt = b.data()['createdAt'] as Timestamp?;
          return (bt?.millisecondsSinceEpoch ?? 0)
              .compareTo(at?.millisecondsSinceEpoch ?? 0);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('my_tickets'), style: AppTextStyles.title3),
            const SizedBox(height: 10),
            for (final doc in docs.take(6)) _TicketPreview(data: doc.data()),
          ],
        );
      },
    );
  }
}

class _TicketPreview extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TicketPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    final message = data['message'] as String? ?? '';
    final reply = data['adminReply'] as String?;
    final status = data['status'] as String? ?? 'open';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              context.statusText(status),
              style: AppTextStyles.captionMedium.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          Icon(
            status == 'open'
                ? Icons.hourglass_bottom_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: status == 'open' ? AppColors.warning : AppColors.success,
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        if (reply != null && reply.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            context.t('admin_reply'),
            style: AppTextStyles.captionMedium.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reply,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SupportHeader extends StatelessWidget {
  final UserEntity user;

  const _SupportHeader({required this.user});

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
          const Icon(Icons.support_agent_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('support_center'), style: AppTextStyles.title3),
                const SizedBox(height: 4),
                Text(
                  user.email,
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.captionMedium.copyWith(
                color: AppColors.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
