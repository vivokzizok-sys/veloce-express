import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
    await _notificationSvc.initialize();
    _authSub = _authBloc.stream.listen((state) async {
      if (state is AuthAuthenticated) {
        await _notificationSvc.watchUserNotifications(state.user.uid);
      } else {
        await _notificationSvc.stopWatching();
      }
    });
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
              supportedLocales: const [
                Locale('en'),
                Locale('ar'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => Directionality(
                textDirection: _settingsController.textDirection,
                child: child ?? const SizedBox.shrink(),
              ),
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
