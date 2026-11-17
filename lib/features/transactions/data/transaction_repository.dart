import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_client.dart';
import 'transaction_details.dart';

class TransactionRepository {
  TransactionRepository(this._client);
  final AuthenticatedClient _client;

  Future<TransactionDetails> details(String id) async {
    final body = await _client.request(
      'GET',
      '/api/v1/transactions/${Uri.encodeComponent(id)}',
    );
    try {
      return TransactionDetails.fromJson(body);
    } on TypeError {
      throw const ApiException(
        'Received an unexpected response. Please try again.',
      );
    }
  }
}
