import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/user_entity.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../bloc/auth_bloc.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.client;
  VehicleType _vehicleType = VehicleType.bike;
  File? _vehiclePhoto;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickVehiclePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (picked != null) setState(() => _vehiclePhoto = File(picked.path));
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
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/login'),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create account', style: AppTextStyles.title1),
                    const SizedBox(height: 20),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.client,
                          label: Text('Client'),
                          icon: Icon(Icons.person_outline_rounded),
                        ),
                        ButtonSegment(
                          value: UserRole.driver,
                          label: Text('Driver'),
                          icon: Icon(Icons.local_shipping_outlined),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (set) =>
                          setState(() => _role = set.first),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _name,
                      hint: 'Full name',
                      validator: (v) => Validators.required(v, label: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _email,
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phone,
                      hint: 'Phone number',
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _password,
                      hint: 'Password',
                      obscureText: true,
                      validator: Validators.password,
                    ),
                    if (_role == UserRole.driver) ...[
                      const SizedBox(height: 18),
                      Text('Vehicle', style: AppTextStyles.captionMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<VehicleType>(
                        value: _vehicleType,
                        items: const [
                          DropdownMenuItem(
                            value: VehicleType.bike,
                            child: Text('Bike'),
                          ),
                          DropdownMenuItem(
                            value: VehicleType.car,
                            child: Text('Car'),
                          ),
                          DropdownMenuItem(
                            value: VehicleType.truck,
                            child: Text('Truck'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setState(() => _vehicleType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickVehiclePhoto,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.grey50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.grey200),
                          ),
                          child: _vehiclePhoto == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_camera_outlined),
                                    SizedBox(height: 8),
                                    Text('Upload vehicle photo'),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    _vehiclePhoto!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Create Account',
                      isLoading: loading,
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        context.read<AuthBloc>().add(AuthSignUpRequested(
                              email: _email.text,
                              password: _password.text,
                              fullName: _name.text,
                              phoneNumber: _phone.text,
                              role: _role,
                              vehicleType: _role == UserRole.driver
                                  ? _vehicleType
                                  : null,
                              vehiclePhoto: _role == UserRole.driver
                                  ? _vehiclePhoto
                                  : null,
                            ));
                      },
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('I already have an account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
