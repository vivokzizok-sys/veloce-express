import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../domain/entities/user_entity.dart';
import 'shared_widgets.dart';

class SubscriptionGate extends StatelessWidget {
  static const _freeTrialDays = 30;

  final UserEntity user;
  final Widget child;

  const SubscriptionGate({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!user.isDriver && !user.isStore) return child;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return child;
        if (_canWork(data)) return child;
        return _SubscriptionBlockedScreen(user: user);
      },
    );
  }

  bool _canWork(Map<String, dynamic> data) {
    final validUntil = (data['subscriptionValidUntil'] as Timestamp?)?.toDate();
    if (validUntil != null && validUntil.isAfter(DateTime.now())) return true;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return true;
    return DateTime.now().difference(createdAt).inDays < _freeTrialDays;
  }
}

class _SubscriptionBlockedScreen extends StatefulWidget {
  final UserEntity user;

  const _SubscriptionBlockedScreen({required this.user});

  @override
  State<_SubscriptionBlockedScreen> createState() =>
      _SubscriptionBlockedScreenState();
}

class _SubscriptionBlockedScreenState
    extends State<_SubscriptionBlockedScreen> {
  String? _receiptBase64;
  bool _submitting = false;

  Future<void> _pickReceipt() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 850 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('image_too_large'))),
      );
      return;
    }
    setState(() => _receiptBase64 = base64Encode(bytes));
  }

  Future<void> _submit({
    required String baridiMobNumber,
    required double monthlyFee,
  }) async {
    if (_receiptBase64 == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('subscription_payments').add({
        'userId': widget.user.uid,
        'fullName': widget.user.fullName,
        'phoneNumber': widget.user.phoneNumber,
        'email': widget.user.email,
        'role': widget.user.role.name,
        'storeType': widget.user.storeType?.name,
        'amount': monthlyFee,
        'baridiMobNumber': baridiMobNumber,
        'receiptBase64': _receiptBase64,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('subscription_sent'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('subscription')
          .snapshots(),
      builder: (context, snap) {
        final config = snap.data?.data() ?? const <String, dynamic>{};
        final baridiMobNumber =
            config['baridiMobNumber'] as String? ?? 'ضع رقم بريدي موب';
        final monthlyFee = _subscriptionFee(config, widget.user);
        return Scaffold(
          backgroundColor: AppColors.page(context),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const SizedBox(height: 18),
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 54,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 18),
                Text(
                  context.t('subscription_required'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title2,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('subscription_required_body'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: context.t('baridimob_number'),
                        value: baridiMobNumber,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: context.t('monthly_fee'),
                        value: '${monthlyFee.toStringAsFixed(0)} DA',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickReceipt,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: _receiptBase64 == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.upload_file_rounded),
                              const SizedBox(height: 8),
                              Text(context.t('upload_payment_receipt')),
                            ],
                          )
                        : Image.memory(
                            base64Decode(_receiptBase64!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: context.t('send_subscription'),
                  isLoading: _submitting,
                  onPressed: _receiptBase64 == null
                      ? null
                      : () => _submit(
                            baridiMobNumber: baridiMobNumber,
                            monthlyFee: monthlyFee,
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

double _subscriptionFee(Map<String, dynamic> config, UserEntity user) {
  if (user.isDriver) {
    return (config['driverMonthlyFee'] as num?)?.toDouble() ??
        (config['monthlyFee'] as num?)?.toDouble() ??
        1500.0;
  }
  final storeType = user.storeType?.name ?? 'restaurant';
  return (config['${storeType}MonthlyFee'] as num?)?.toDouble() ??
      (config['storeMonthlyFee'] as num?)?.toDouble() ??
      (config['monthlyFee'] as num?)?.toDouble() ??
      1500.0;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}
