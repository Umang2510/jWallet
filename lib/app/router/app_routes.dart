/// Every route path in one place — use these instead of string literals.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const setPin = '/set-pin';
  static const setBiometric = '/set-biometric';

  static const dashboard = '/dashboard';

  static const sendMoney = '/send-money';
  static const transferConfirm = '/send-money/confirm';

  static const transactions = '/transactions';
  static String transactionDetails(String id) => '/transactions/$id';
}
