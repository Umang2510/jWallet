import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/activity/view/activity_screen.dart';
import '../../features/activity/view_model/activity_cubit.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view_model/login_cubit.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/home/view_model/home_cubit.dart';
import '../../features/security/view/biometric_setup_screen.dart';
import '../../features/security/view/pin_setup_screen.dart';
import '../../features/security/view_model/biometric_setup_cubit.dart';
import '../../features/security/view_model/pin_setup_cubit.dart';
import '../../features/splash/view/splash_screen.dart';
import '../../features/transactions/data/transaction_details.dart';
import '../../features/transactions/view/transaction_details_screen.dart';
import '../../features/transactions/view_model/transaction_details_cubit.dart';
import '../../features/transfer/data/recipient.dart';
import '../../features/transfer/data/transfer_models.dart';
import '../../features/transfer/view/confirm_transfer_screen.dart';
import '../../features/transfer/view/send_money_screen.dart';
import '../../features/transfer/view_model/send_money_cubit.dart';
import '../../features/transfer/view_model/transfer_cubit.dart';
import '../di.dart';
import '../session/session_cubit.dart';
import '../session/session_state.dart';
import 'app_routes.dart';
import 'main_shell.dart';

/// All navigation. Access rules live in [_redirect], so screens never have
/// to check "am I logged in?" themselves:
///
///   unknown            → splash
///   logged out         → login
///   logged in, no PIN  → set PIN (mandatory, like UPI)
///   PIN just created   → optional biometric setup
///   logged in + PIN    → anywhere except splash/login/set-PIN/set-biometric
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
        (_) => BlocProvider(
          create: (_) => sl<PinSetupCubit>(),
          child: const PinSetupScreen(),
        ),
      ),
      _route(
        AppRoutes.setBiometric,
        (_) => BlocProvider(
          create: (_) => sl<BiometricSetupCubit>()..checkAvailability(),
          child: const BiometricSetupScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => MaterialPage(
          key: state.pageKey,
          child: MainShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              _route(
                AppRoutes.dashboard,
                (_) => BlocProvider(
                  create: (_) => sl<HomeCubit>()..load(),
                  child: Builder(
                    builder: (context) => HomeScreen(
                      onSend: (contact) => context.push(
                        AppRoutes.sendMoney,
                        extra: contact == null
                            ? null
                            : Recipient.fromContact(contact),
                      ),
                      onActivity: () => context.go(AppRoutes.transactions),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                AppRoutes.transactions,
                (_) => BlocProvider(
                  create: (_) => sl<ActivityCubit>()..load(),
                  child: Builder(
                    builder: (context) => ActivityScreen(
                      onOpen: (item) => context.push(
                        AppRoutes.transactionDetails(item.id),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      _route(
        AppRoutes.sendMoney,
        (s) => BlocProvider(
          create: (_) => SendMoneyCubit(
            sl(),
            recipient: s.extra is Recipient ? s.extra as Recipient : null,
          )..load(),
          child: Builder(
            builder: (context) => SendMoneyScreen(
              onReview: (draft) =>
                  context.push(AppRoutes.transferConfirm, extra: draft),
            ),
          ),
        ),
      ),
      _route(
        AppRoutes.transferConfirm,
        // Opened without a draft (for example after the app was restored):
        // start again from the amount screen.
        redirect: (state) =>
            state.extra is TransferDraft ? null : AppRoutes.sendMoney,
        (s) {
          final draft = s.extra! as TransferDraft;
          return BlocProvider(
            create: (_) => TransferCubit(sl(), draft)..prepare(),
            child: Builder(
              builder: (context) => ConfirmTransferScreen(
                draft: draft,
                // pushReplacement keeps the Hero flight from the coin.
                onDone: (receipt) => context.pushReplacement(
                  AppRoutes.transactionDetails(receipt.transactionId),
                  extra: TransactionDetailsArgs(
                    initial: TransactionDetails.fromReceipt(receipt),
                    fromTransfer: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      _route('/transactions/:id', (s) {
        final args = s.extra is TransactionDetailsArgs
            ? s.extra as TransactionDetailsArgs
            : null;
        final fromTransfer = args?.fromTransfer ?? false;
        return BlocProvider(
          create: (_) => TransactionDetailsCubit(
            sl(),
            s.pathParameters['id']!,
            initial: args?.initial,
          )..load(),
          child: Builder(
            builder: (context) {
              // After a transfer, "back" means Home, not the amount screen.
              void done() => fromTransfer
                  ? context.go(AppRoutes.dashboard)
                  : Navigator.of(context).maybePop();
              return PopScope(
                canPop: !fromTransfer,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) done();
                },
                child: TransactionDetailsScreen(onDone: done),
              );
            },
          ),
        );
      }),
    ],
  );
}

String? _redirect(SessionState session, String location) {
  const entry = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.setPin,
    AppRoutes.setBiometric,
  };

  switch (session.status) {
    case SessionStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.unauthenticated:
      return location == AppRoutes.login ? null : AppRoutes.login;
    case SessionStatus.authenticated:
      if (!session.pinSet) {
        return location == AppRoutes.setPin ? null : AppRoutes.setPin;
      }
      if (session.biometricSetupPending) {
        return location == AppRoutes.setBiometric
            ? null
            : AppRoutes.setBiometric;
      }
      return entry.contains(location) ? AppRoutes.dashboard : null;
  }
}

/// A route using material_ui's MaterialPage (go_router would otherwise not
/// detect our MaterialApp, which now lives in the material_ui package).
GoRoute _route(
  String path,
  Widget Function(GoRouterState) builder, {
  String? Function(GoRouterState)? redirect,
}) => GoRoute(
  path: path,
  redirect: redirect == null ? null : (context, state) => redirect(state),
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
