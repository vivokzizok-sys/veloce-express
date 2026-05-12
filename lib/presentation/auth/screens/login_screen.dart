import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nawdli express',
                        style: AppTextStyles.largeTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('sign_in_subtitle'),
                        style: AppTextStyles.body.copyWith(
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 28),
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
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _password,
                        hint: context.t('password'),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return context.t('field_required');
                          }
                          return v.length >= 6
                              ? null
                              : context.t('password_length');
                        },
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: context.t('sign_in'),
                        isLoading: loading,
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          context.read<AuthBloc>().add(AuthSignInRequested(
                                email: _email.text,
                                password: _password.text,
                              ));
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: Text(context.t('create_account')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
