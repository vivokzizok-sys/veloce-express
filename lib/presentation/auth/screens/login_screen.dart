import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
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
                        'Veloce Express',
                        style: AppTextStyles.largeTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to manage deliveries and bids.',
                        style: AppTextStyles.body.copyWith(
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AppTextField(
                        controller: _email,
                        hint: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _password,
                        hint: 'Password',
                        obscureText: true,
                        validator: Validators.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Sign In',
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
                        child: const Text('Create an account'),
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
