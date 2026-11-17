import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_client.dart';
import 'activity_models.dart';

class ActivityRepository {
  ActivityRepository(this._client);
  final AuthenticatedClient _client;

  static const pageSize = 20;

  Future<TransactionPage> list(ActivityFilters filters, {int page = 1}) async {
    final body = await _client.request(
      'GET',
      filters.path(page: page, limit: pageSize),
    );
    try {
      return TransactionPage.fromJson(body);
    } on TypeError {
      throw const ApiException(
        'Received an unexpected response. Please try again.',
      );
    }
  }
}
