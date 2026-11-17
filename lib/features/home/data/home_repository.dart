import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_client.dart';
import 'home_models.dart';

class HomeRepository {
  HomeRepository(this._client);
  final AuthenticatedClient _client;

  /// Profile, balance and the latest transactions, requested together.
  Future<HomeData> load() async {
    final results = await Future.wait([
      _client.request('GET', '/api/v1/users/profile'),
      _client.request('GET', '/api/v1/wallet/balance'),
      _client.request('GET', '/api/v1/transactions?page=1&limit=5'),
    ]);
    try {
      return HomeData(
        profile: UserProfile.fromJson(results[0]),
        wallet: WalletBalance.fromJson(results[1]),
        recent: [
          for (final item in results[2]['items'] as List<dynamic>)
            TransactionItem.fromJson(item as Map<String, dynamic>),
        ],
      );
    } on TypeError {
      throw const ApiException('Received an unexpected response. Please try again.');
    }
  }
}
