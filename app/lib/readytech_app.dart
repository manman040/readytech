import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/services/connectivity_service.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/core/widgets/offline_banner.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_event.dart';
import 'package:readytech/routing/app_router.dart';

/// The application root.
///
/// The router is built once and held in state: rebuilding a [GoRouter] on every
/// frame discards the navigation stack, which shows up as screens that refuse
/// to keep their scroll position or lose a half-filled form.
class ReadyTechApp extends StatefulWidget {
  const ReadyTechApp({super.key});

  @override
  State<ReadyTechApp> createState() => _ReadyTechAppState();
}

class _ReadyTechAppState extends State<ReadyTechApp> {
  late final AuthBloc _authBloc = getIt<AuthBloc>()..add(const AuthStarted());

  late final GoRouter _router = createRouter(_authBloc);

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'ReadyTech',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _router,
        builder: (context, child) {
          return OfflineBanner(
            connectivity: getIt<ConnectivityService>(),
            child: _TextScaleGuard(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}

/// Honours the reader's font size preference, within limits.
///
/// The system scale is respected up to 1.4x. Past that a dense screen such as a
/// price breakdown stops fitting at all, and an unreadable layout serves nobody
/// better than a large-but-legible one.
class _TextScaleGuard extends StatelessWidget {
  const _TextScaleGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.4,
        ),
      ),
      child: child,
    );
  }
}
