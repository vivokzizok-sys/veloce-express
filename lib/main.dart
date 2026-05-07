import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/order_repository_impl.dart';
import 'data/repositories/tracking_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/order_repository.dart';
import 'domain/repositories/tracking_repository.dart';
import 'firebase_options.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/order/bloc/order_bloc.dart';
import 'presentation/tracking/bloc/tracking_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  ));

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const VeloceExpressApp());
}

class VeloceExpressApp extends StatefulWidget {
  const VeloceExpressApp({super.key});

  @override
  State<VeloceExpressApp> createState() => _VeloceExpressAppState();
}

class _VeloceExpressAppState extends State<VeloceExpressApp> {
  late final AuthRepository _authRepo;
  late final OrderRepository _orderRepo;
  late final TrackingRepository _trackingRepo;
  late final LocationService _locationSvc;
  late final NotificationService _notificationSvc;
  late final AppSettingsController _settingsController;

  late final AuthBloc _authBloc;
  late final OrderBloc _orderBloc;
  late final TrackingBloc _trackingBloc;
  late final router = AppRouter.createRouter(_authBloc);
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    _locationSvc = LocationService();
    _notificationSvc = NotificationService();
    _settingsController = AppSettingsController();
    _settingsController.load();
    _authRepo = AuthRepositoryImpl(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
    _orderRepo = OrderRepositoryImpl(db: FirebaseFirestore.instance);
    _trackingRepo = TrackingRepositoryImpl(db: FirebaseFirestore.instance);

    _authBloc = AuthBloc(authRepository: _authRepo)..add(AuthCheckRequested());
    _orderBloc = OrderBloc(repository: _orderRepo);
    _trackingBloc = TrackingBloc(
      trackingRepository: _trackingRepo,
      locationService: _locationSvc,
    );

    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationSvc.initialize(onTap: _handleNotificationTap);
    final current = _authBloc.state;
    if (current is AuthAuthenticated) {
      await _notificationSvc.watchUserNotifications(current.user.uid);
    }
    _authSub = _authBloc.stream.listen((state) async {
      if (state is AuthAuthenticated) {
        await _notificationSvc.watchUserNotifications(state.user.uid);
      } else {
        await _notificationSvc.stopWatching();
      }
    });
  }

  void _handleNotificationTap(String? orderId) {
    if (orderId == null || orderId.isEmpty) return;
    router.go('/order/$orderId');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _authBloc.close();
    _orderBloc.close();
    _trackingBloc.close();
    _locationSvc.dispose();
    _notificationSvc.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<OrderBloc>.value(value: _orderBloc),
        BlocProvider<TrackingBloc>.value(value: _trackingBloc),
      ],
      child: AppSettingsScope(
        controller: _settingsController,
        child: AnimatedBuilder(
          animation: _settingsController,
          builder: (context, _) {
            return MaterialApp.router(
              title: 'Veloce Express',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: _settingsController.themeMode,
              locale: _settingsController.locale,
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => Directionality(
                textDirection: _settingsController.textDirection,
                child:
                    _ForceUpdateGate(child: child ?? const SizedBox.shrink()),
              ),
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}

class _ForceUpdateGate extends StatelessWidget {
  static const _currentVersion = '1.0.0';

  final Widget child;

  const _ForceUpdateGate({required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('android')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final latestVersion = data?['latestVersion'] as String?;
        final minVersion = data?['minVersion'] as String?;
        final apkUrl = data?['apkUrl'] as String?;
        final forceUpdate = data?['forceUpdate'] as bool? ?? false;
        final mustUpdate = (minVersion != null &&
                _compareVersions(_currentVersion, minVersion) < 0) ||
            (forceUpdate &&
                latestVersion != null &&
                _compareVersions(_currentVersion, latestVersion) < 0);

        if (!mustUpdate) return child;
        return Material(
          color: AppColors.page(context),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update_rounded,
                        color: AppColors.accent, size: 42),
                    const SizedBox(height: 14),
                    Text(
                      context.t('update_required'),
                      style: AppTextStyles.title2.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('update_required_body'),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: apkUrl == null
                          ? null
                          : () => launchUrl(
                                Uri.parse(apkUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(context.t('download_update')),
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

  int _compareVersions(String a, String b) {
    final left = a.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final right = b.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}
