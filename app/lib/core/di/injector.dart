import 'package:get_it/get_it.dart';
import 'package:readytech/core/config/app_config.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/services/connectivity_service.dart';
import 'package:readytech/data/datasources/auth_remote_datasource.dart';
import 'package:readytech/data/datasources/device_remote_datasource.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/data/repositories/device_repository.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The service locator.
///
/// Registration is written by hand rather than generated. The graph is small
/// enough to read top to bottom, and an explicit list of what the app depends
/// on is worth more here than saving a few lines of boilerplate.
final GetIt getIt = GetIt.instance;

/// Wires the object graph. Called once from bootstrap, after Supabase has been
/// initialised.
///
/// Only long-lived, app-wide objects live here. Per-screen state - form cubits,
/// list blocs - is created by the screen that owns it so it is disposed with
/// that screen.
Future<void> configureDependencies(AppConfig config) async {
  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<AppLogger>(ConsoleAppLogger(config.flavor));

  final connectivity = ConnectivityPlusService();
  // Read the current value before the first frame so an offline start shows the
  // banner immediately rather than one status change later.
  await connectivity.initialise();

  getIt
    ..registerSingleton<ConnectivityService>(connectivity)
    ..registerSingleton<SupabaseClient>(Supabase.instance.client)
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => SupabaseAuthRepository(
        dataSource: getIt<AuthRemoteDataSource>(),
        logger: getIt<AppLogger>(),
      ),
    )
    // Exactly one session owner for the lifetime of the app.
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        repository: getIt<AuthRepository>(),
        logger: getIt<AppLogger>(),
      ),
    )
    ..registerLazySingleton<DeviceRemoteDataSource>(
      () => DeviceRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<DeviceRepository>(
      () => SupabaseDeviceRepository(
        dataSource: getIt<DeviceRemoteDataSource>(),
        logger: getIt<AppLogger>(),
      ),
    );
}

/// Tears the graph down. Used by tests between cases.
Future<void> resetDependencies() async {
  if (getIt.isRegistered<ConnectivityService>()) {
    await getIt<ConnectivityService>().dispose();
  }
  if (getIt.isRegistered<AuthBloc>()) {
    await getIt<AuthBloc>().close();
  }
  await getIt.reset();
}
