import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../core/config/app_config.dart';
import '../core/crypto/device_keys.dart';
import '../core/crypto/e2e_cipher.dart';
import '../core/network/api_client.dart';
import '../core/network/authenticated_client.dart';
import '../core/storage/secure_store.dart';
import '../features/app_lock/data/app_lock_repository.dart';
import '../features/app_lock/view_model/app_lock_cubit.dart';
import '../features/app_lock/view_model/app_lock_setup_cubit.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/view_model/login_cubit.dart';
import '../features/security/data/security_repository.dart';
import '../features/security/view_model/biometric_setup_cubit.dart';
import '../features/security/view_model/pin_setup_cubit.dart';
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
    ..registerLazySingleton<DeviceKeys>(DeviceKeys.new)
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
    ..registerLazySingleton<AuthenticatedClient>(
      () => AuthenticatedClient(sl(), sl(), sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(sl(), sl(), sl(), sl()),
    )
    ..registerLazySingleton<SecurityRepository>(
      () => SecurityRepository(sl(), sl()),
    )
    ..registerLazySingleton<LocalAuthentication>(LocalAuthentication.new)
    ..registerLazySingleton<AppLockRepository>(
      () => AppLockRepository(sl(), sl()),
    )
    ..registerFactory<LoginCubit>(() => LoginCubit(sl()))
    ..registerFactory<PinSetupCubit>(() => PinSetupCubit(sl()))
    ..registerFactory<BiometricSetupCubit>(() => BiometricSetupCubit(sl()))
    ..registerLazySingleton<SessionCubit>(() => SessionCubit(sl()))
    ..registerLazySingleton<AppLockCubit>(() => AppLockCubit(sl(), sl()))
    ..registerFactory<AppLockSetupCubit>(() => AppLockSetupCubit(sl()))
    ..registerLazySingleton<GoRouter>(() => createRouter(sl()));
}
