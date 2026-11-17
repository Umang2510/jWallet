import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/crypto/e2e_cipher.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/view_model/login_cubit.dart';
import 'router/app_router.dart';
import 'session/session_cubit.dart';

final sl = GetIt.instance;

void setupDependencies({AppConfig? config}) {
  sl
    ..registerSingleton<AppConfig>(config ?? AppConfig.fromEnvironment())
    ..registerLazySingleton<SecureStore>(
      () => SecureStore(const FlutterSecureStorage()),
    )
    ..registerLazySingleton<E2eCipher>(() => E2eCipher(sl()))
    ..registerLazySingleton<Dio>(
      () => Dio(
        BaseOptions(
          baseUrl: sl<AppConfig>().apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          contentType: Headers.jsonContentType,
        ),
      ),
    )
    ..registerLazySingleton<ApiClient>(() => ApiClient(sl(), sl()))
    ..registerLazySingleton<AuthRepository>(() => AuthRepository(sl(), sl()))
    ..registerFactory<LoginCubit>(() => LoginCubit(sl()))
    ..registerLazySingleton<SessionCubit>(() => SessionCubit(sl()))
    ..registerLazySingleton<GoRouter>(() => createRouter(sl()));
}
