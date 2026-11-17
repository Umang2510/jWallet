import 'package:dio/dio.dart';

import '../crypto/e2e_cipher.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._dio, this._cipher);
  final Dio _dio;
  final E2eCipher _cipher;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    try {
      final encrypted = _cipher.seal(method, path, body);
      final response = await _dio.request<dynamic>(
        path,
        data: encrypted.body,
        options: Options(
          method: method,
          validateStatus: (status) => status != null,
          headers: {
            ...encrypted.headers,
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      final status = response.statusCode ?? 500;
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid API response');
      }
      final isEncrypted = response.headers.value('X-Encrypted') == '1';
      final envelope = isEncrypted
          ? encrypted.openResponse(status, data['payload'] as String)
          : data;
      if (status < 200 || status >= 300) {
        final meta = envelope['meta'] as Map<String, dynamic>?;
        final error = envelope['body'] as Map<String, dynamic>?;
        throw ApiException(
          meta?['message'] as String? ?? 'Unable to complete the request.',
          statusCode: status,
          code: error?['errorCode'] as String?,
          notProcessed: const {429, 502, 503}.contains(status),
        );
      }
      // Successful plaintext responses must never downgrade the encrypted channel.
      if (!isEncrypted) {
        throw const FormatException('Expected an encrypted response');
      }
      return envelope['body'] as Map<String, dynamic>;
    } on DioException catch (error) {
      final timeout = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type);
      throw ApiException(
        timeout
            ? 'The request timed out. Please try again.'
            : 'Unable to connect. Check your internet connection and try again.',
        // The request never reached the server, so nothing was consumed.
        notProcessed: const {
          DioExceptionType.connectionTimeout,
          DioExceptionType.connectionError,
        }.contains(error.type),
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not verify the server response. Please try again.',
      );
    }
  }
}
