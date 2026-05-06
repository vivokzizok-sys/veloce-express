import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../settings/app_settings.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/admin/screens/admin_dashboard_screen.dart';
import '../../presentation/auth/bloc/auth_bloc.dart';
import '../../presentation/auth/screens/email_verification_screen.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/auth/screens/pending_approval_screen.dart';
import '../../presentation/auth/screens/signup_screen.dart';
import '../../presentation/auth/screens/splash_screen.dart';
import '../../presentation/client/screens/client_home_screen.dart';
import '../../presentation/client/screens/create_order_screen.dart';
import '../../presentation/client/screens/client_dashboard_screen.dart';
import '../../presentation/client/screens/order_detail_screen.dart';
import '../../presentation/driver/screens/driver_dashboard_screen.dart';
import '../../presentation/driver/screens/driver_home_screen.dart';
import '../../presentation/driver/screens/place_bid_screen.dart';
import '../../presentation/settings/screens/settings_screen.dart';
import '../../presentation/tracking/screens/active_trip_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const emailVerify = '/verify-email';
  static const pendingApproval = '/pending-approval';

  static const clientHome = '/client/home';
  static const clientDashboard = '/client/dashboard';
  static const createOrder = '/client/create-order';
  static const orderDetail = '/client/order/:orderId';

  static const driverHome = '/driver/home';
  static const driverDashboard = '/driver/dashboard';
  static const placeBid = '/driver/bid/:orderId';

  static const activeTrip = '/active-trip';
  static const adminDashboard = '/admin/dashboard';
  static const settings = '/settings';
}

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _AuthBlocListenable(authBloc),
      redirect: (context, state) {
        final authState = authBloc.state;
        final loc = state.matchedLocation;

        if (authState is AuthInitial || authState is AuthLoading) {
          return loc == AppRoutes.splash ? null : AppRoutes.splash;
        }

        if (authState is AuthUnauthenticated || authState is AuthFailureState) {
          final free = [AppRoutes.login, AppRoutes.signup];
          return free.contains(loc) ? null : AppRoutes.login;
        }

        if (authState is AuthEmailUnverified) {
          return loc == AppRoutes.emailVerify ? null : AppRoutes.emailVerify;
        }

        if (authState is AuthPendingApproval) {
          return loc == AppRoutes.pendingApproval
              ? null
              : AppRoutes.pendingApproval;
        }

        if (authState is AuthAuthenticated) {
          final authScreens = [
            AppRoutes.splash,
            AppRoutes.login,
            AppRoutes.signup,
            AppRoutes.emailVerify,
            AppRoutes.pendingApproval,
          ];
          if (authScreens.contains(loc)) {
            return _homeForRole(authState.user.role);
          }
          if (loc.startsWith('/admin') &&
              authState.user.role != UserRole.admin) {
            return _homeForRole(authState.user.role);
          }
          if (loc.startsWith('/driver') &&
              authState.user.role != UserRole.driver) {
            return _homeForRole(authState.user.role);
          }
          if (loc.startsWith('/client') &&
              authState.user.role != UserRole.client) {
            return _homeForRole(authState.user.role);
          }
        }

        return null;
      },
      routes: [
        GoRoute(
            path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (_, state) => _fade(state, const LoginScreen()),
        ),
        GoRoute(
          path: AppRoutes.signup,
          pageBuilder: (_, state) => _slide(state, const SignupScreen()),
        ),
        GoRoute(
          path: AppRoutes.emailVerify,
          builder: (context, _) {
            final user =
                (context.read<AuthBloc>().state as AuthEmailUnverified).user;
            return EmailVerificationScreen(user: user);
          },
        ),
        GoRoute(
          path: AppRoutes.pendingApproval,
          builder: (context, _) {
            final user =
                (context.read<AuthBloc>().state as AuthPendingApproval).user;
            return PendingApprovalScreen(user: user);
          },
        ),
        GoRoute(
          path: AppRoutes.clientHome,
          pageBuilder: (_, state) => _fade(state, const ClientHomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.clientDashboard,
          pageBuilder: (_, state) =>
              _slide(state, const ClientDashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.createOrder,
          pageBuilder: (_, state) => _slide(state, const CreateOrderScreen()),
        ),
        GoRoute(
          path: AppRoutes.orderDetail,
          builder: (_, state) =>
              OrderDetailScreen(orderId: state.pathParameters['orderId']!),
        ),
        GoRoute(
          path: AppRoutes.driverHome,
          pageBuilder: (_, state) => _fade(state, const DriverHomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.driverDashboard,
          pageBuilder: (_, state) =>
              _slide(state, const DriverDashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.placeBid,
          pageBuilder: (_, state) => _slide(
            state,
            PlaceBidScreen(orderId: state.pathParameters['orderId']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.activeTrip,
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null) {
              return _fade(
                state,
                Scaffold(
                  body: Center(
                    child: Text(context.t('active_trip_missing')),
                  ),
                ),
              );
            }
            return _slide(
              state,
              ActiveTripScreen(
                order: extra['order'] as OrderEntity,
                otherParty: extra['otherParty'] as UserEntity,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.adminDashboard,
          pageBuilder: (_, state) => _fade(state, const AdminDashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (_, state) => _slide(state, const SettingsScreen()),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: Text('${context.t('page_not_found')}: ${state.error}'),
          ),
        ),
      ),
    );
  }

  static String _homeForRole(UserRole role) => switch (role) {
        UserRole.client => AppRoutes.clientHome,
        UserRole.driver => AppRoutes.driverHome,
        UserRole.admin => AppRoutes.adminDashboard,
      };

  static CustomTransitionPage _fade(GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  static CustomTransitionPage _slide(GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

class _AuthBlocListenable extends ChangeNotifier {
  late final StreamSubscription _sub;

  _AuthBlocListenable(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
