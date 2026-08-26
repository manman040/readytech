import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/view/sign_in_page.dart';

import '../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() {
    repository = FakeAuthRepository();
    getIt.registerSingleton<AuthRepository>(repository);
  });

  tearDown(() async {
    await getIt.reset();
    await repository.dispose();
  });

  /// The page pushes named routes, so it needs a router in the tree.
  Future<void> pumpSignIn(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/sign-in',
              name: 'sign-in',
              builder: (_, _) => const SignInPage(),
            ),
            GoRoute(
              path: '/sign-up',
              name: 'sign-up',
              builder: (_, _) => const Scaffold(body: Text('sign up page')),
            ),
            GoRoute(
              path: '/forgot-password',
              name: 'forgot-password',
              builder: (_, _) => const Scaffold(body: Text('forgot page')),
            ),
          ],
          initialLocation: '/sign-in',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The page has three AppButtons - sign in, forgot password and the sign-up
  /// link - and the sign-in one loses its label while busy, so it has to be
  /// found by identity rather than by position or text.
  Finder signInButton() => find.byWidgetPredicate(
    (widget) => widget is AppButton && widget.label == 'Sign in',
  );

  testWidgets('renders the form', (tester) async {
    await pumpSignIn(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('refuses to submit an invalid email', (tester) async {
    await pumpSignIn(tester);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(repository.signInCallCount, 0);
  });

  testWidgets('refuses to submit an empty password', (tester) async {
    await pumpSignIn(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'adam@readytech.test',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Password is required'), findsOneWidget);
    expect(repository.signInCallCount, 0);
  });

  testWidgets('submits a valid form', (tester) async {
    await pumpSignIn(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'adam@readytech.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.signInCallCount, 1);
  });

  testWidgets('shows the failure message without leaking driver text', (
    tester,
  ) async {
    repository.signInFailure = const AuthFailure(
      message: 'Incorrect email or password.',
      debugDetail: 'AuthApiException(statusCode: 400, sql: select * from ...)',
    );
    await pumpSignIn(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'adam@readytech.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrongpass1');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.textContaining('AuthApiException'), findsNothing);
    expect(find.textContaining('select *'), findsNothing);
  });

  testWidgets('shows a busy button while the request is in flight', (
    tester,
  ) async {
    // Hold the request open so the in-flight frame is observable, the way a
    // slow connection would.
    final gate = Completer<void>();
    repository.signInGate = gate;

    await pumpSignIn(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'adam@readytech.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    final button = tester.widget<AppButton>(signInButton());
    expect(button.isBusy, isTrue);
    // The label is replaced by the spinner, so a second tap is impossible.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('does not submit twice on a double tap', (tester) async {
    final gate = Completer<void>();
    repository.signInGate = gate;

    await pumpSignIn(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'adam@readytech.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    // The button is now a spinner; tapping the control again must do nothing.
    await tester.tap(signInButton(), warnIfMissed: false);
    await tester.pump();

    expect(repository.signInCallCount, 1);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('navigates to sign up', (tester) async {
    await pumpSignIn(tester);

    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();

    expect(find.text('sign up page'), findsOneWidget);
  });

  testWidgets('navigates to forgot password', (tester) async {
    await pumpSignIn(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('forgot page'), findsOneWidget);
  });

  testWidgets('offers to reveal the password', (tester) async {
    await pumpSignIn(tester);

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
