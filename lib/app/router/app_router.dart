import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/splash/view/splash_screen.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view_model/login_cubit.dart';
import '../di.dart';
import '../session/session_cubit.dart';
import '../session/session_state.dart';
import 'app_routes.dart';
import 'placeholder_screen.dart';

/// All navigation. Access rules live in [_redirect], so screens never have
/// to check "am I logged in?" themselves:
///
///   unknown            → splash
///   logged out         → login
///   logged in, no PIN  → set PIN (mandatory, like UPI)
///   logged in + PIN    → anywhere except splash/login/set-PIN
GoRouter createRouter(SessionCubit session) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _StreamListenable(session.stream),
    redirect: (context, state) =>
        _redirect(session.state, state.matchedLocation),
    routes: [
      _route(AppRoutes.splash, (_) => const SplashScreen()),
      _route(
        AppRoutes.login,
        (_) => BlocProvider(
          create: (_) => sl<LoginCubit>(),
          child: const LoginScreen(),
        ),
      ),
      _route(
        AppRoutes.setPin,
        (_) => const PlaceholderScreen(title: 'Set PIN', showLogout: true),
      ),
      _route(
        AppRoutes.dashboard,
        (_) => const PlaceholderScreen(title: 'Dashboard', showLogout: true),
      ),
      _route(
        AppRoutes.sendMoney,
        (_) => const PlaceholderScreen(title: 'Send Money'),
      ),
      _route(
        AppRoutes.transferConfirm,
        (_) => const PlaceholderScreen(title: 'Confirm Transfer'),
      ),
      _route(
        AppRoutes.transferResult,
        (_) => const PlaceholderScreen(title: 'Transfer Result'),
      ),
      _route(
        AppRoutes.transactions,
        (_) => const PlaceholderScreen(title: 'Transactions'),
      ),
      _route(
        '/transactions/:id',
        (s) =>
            PlaceholderScreen(title: 'Transaction ${s.pathParameters['id']}'),
      ),
    ],
  );
}

String? _redirect(SessionState session, String location) {
  const entry = {AppRoutes.splash, AppRoutes.login, AppRoutes.setPin};

  switch (session.status) {
    case SessionStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.unauthenticated:
      return location == AppRoutes.login ? null : AppRoutes.login;
    case SessionStatus.authenticated:
      if (!session.pinSet) {
        return location == AppRoutes.setPin ? null : AppRoutes.setPin;
      }
      return entry.contains(location) ? AppRoutes.dashboard : null;
  }
}

/// A route using material_ui's MaterialPage (go_router would otherwise not
/// detect our MaterialApp, which now lives in the material_ui package).
GoRoute _route(String path, Widget Function(GoRouterState) builder) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      MaterialPage(key: state.pageKey, child: builder(state)),
);

/// Lets GoRouter re-run redirects whenever the session changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
