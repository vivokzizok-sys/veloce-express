import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import 'shared_widgets.dart';

class AppMenuButton extends StatelessWidget {
  final UserEntity user;

  const AppMenuButton({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.t('menu'),
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => _showMenu(context),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => AppSettingsScope(
        controller: context.settings,
        child: _SettingsSheet(user: user),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final UserEntity user;

  const _SettingsSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    final dark = settings.themeMode == ThemeMode.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('settings'), style: AppTextStyles.title2),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(context.t('account_settings')),
              subtitle: Text(user.email,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                _showAccountSettings(context, user);
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text(context.t('appearance')),
              subtitle: Text(dark ? context.t('dark') : context.t('light')),
              value: dark,
              onChanged: (value) => settings.setThemeMode(
                value ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            const SizedBox(height: 8),
            Text(context.t('language'), style: AppTextStyles.captionMedium),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
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
              onSelectionChanged: (set) => settings.setLanguage(set.first),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<AuthBloc>().add(AuthSignOutRequested());
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(context.t('sign_out')),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSettings(BuildContext context, UserEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AppSettingsScope(
        controller: context.settings,
        child: _AccountSettingsSheet(user: user),
      ),
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
                      ? context.t('full_name')
                      : null,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _email,
                  hint: context.t('email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v != null && v.contains('@') ? null : context.t('email'),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _phone,
                  hint: context.t('phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _password,
                  hint: context.t('new_password'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    return v.length >= 6 ? null : context.t('new_password');
                  },
                ),
                const SizedBox(height: 6),
                Text(context.t('leave_blank'), style: AppTextStyles.caption),
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
