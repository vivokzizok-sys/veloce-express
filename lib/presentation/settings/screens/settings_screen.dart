import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shared/widgets/shared_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final settings = context.settings;
    final dark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(context.t('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 18),
          _SettingsSection(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(context.t('account_settings')),
                subtitle: Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showAccountSettings(context, user),
              ),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(context.t('appearance')),
                subtitle: Text(dark ? context.t('dark') : context.t('light')),
                value: dark,
                onChanged: (value) => settings.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('language'),
                        style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.textSecondary(context),
                        )),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppLanguage>(
                        segments: [
                          ButtonSegment(
                            value: AppLanguage.en,
                            label: Text(context.t('english')),
                          ),
                          ButtonSegment(
                            value: AppLanguage.ar,
                            label: Text(context.t('arabic')),
                          ),
                        ],
                        selected: {settings.language},
                        onSelectionChanged: (set) =>
                            settings.setLanguage(set.first),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent_rounded),
                title: Text(context.t('support')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/support'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(context.t('privacy_policy')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(context.t('terms')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/terms'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.logout_rounded, color: AppColors.error),
                title: Text(
                  context.t('sign_out'),
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  context.read<AuthBloc>().add(AuthSignOutRequested());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountSettings(BuildContext context, UserEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface(context),
      builder: (_) => AppSettingsScope(
        controller: context.settings,
        child: _AccountSettingsSheet(user: user),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserEntity user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final roleColor = user.role == UserRole.driver
        ? AppColors.driverRole
        : user.role == UserRole.admin
            ? AppColors.adminRole
            : AppColors.clientRole;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: roleColor.withOpacity(0.12),
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: AppTextStyles.title2.copyWith(color: roleColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppTextStyles.title3),
                const SizedBox(height: 3),
                Text(
                  user.phoneNumber,
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

class _SettingsSection extends StatelessWidget {
  final List<Widget> children;

  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(children: children),
    );
  }
}

class _AccountSettingsSheet extends StatefulWidget {
  final UserEntity user;

  const _AccountSettingsSheet({required this.user});

  @override
  State<_AccountSettingsSheet> createState() => _AccountSettingsSheetState();
}

class _AccountSettingsSheetState extends State<_AccountSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.fullName);
    _email = TextEditingController(text: widget.user.email);
    _phone = TextEditingController(text: widget.user.phoneNumber);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      final savedText = context.t('saved');
      final authUser = FirebaseAuth.instance.currentUser;
      final uid = authUser?.uid ?? widget.user.uid;
      final newEmail = _email.text.trim();
      final newPassword = _password.text.trim();

      if (authUser != null && newEmail != authUser.email) {
        await authUser.verifyBeforeUpdateEmail(newEmail);
      }
      if (authUser != null && newPassword.isNotEmpty) {
        await authUser.updatePassword(newPassword);
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _name.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(savedText)));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? context.t('reauth_required')
          : e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('account_info'), style: AppTextStyles.title2),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _name,
                  hint: context.t('full_name'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? context.t('field_required')
                      : null,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _email,
                  hint: context.t('email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.t('field_required');
                    }
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(v.trim())
                        ? null
                        : context.t('valid_email');
                  },
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _phone,
                  hint: context.t('phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final compact = v.replaceAll(RegExp(r'[\s\-.]'), '');
                    return RegExp(r'^(?:0|\+213|00213)[567]\d{8}$')
                            .hasMatch(compact)
                        ? null
                        : context.t('algerian_phone_error');
                  },
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _password,
                  hint: context.t('new_password'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    return v.length >= 6 ? null : context.t('password_length');
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('leave_blank'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: context.t('save_changes'),
                  isLoading: _loading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
