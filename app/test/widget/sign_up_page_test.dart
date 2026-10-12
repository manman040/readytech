import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/view/sign_up_page.dart';

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

  /// The footer link pops the route, so the page needs a router in the tree.
  ///
  /// There is deliberately no verification route here. The page does not
  /// navigate after a successful sign-up; the session change does, through the
  /// app router's redirect, and that is covered in the routing and bloc tests.
  Future<void> pumpSignUp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/sign-up',
              name: 'sign-up',
              builder: (_, _) => const SignUpPage(),
            ),
          ],
          initialLocation: '/sign-up',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Field order on the form, top to bottom.
  const fullName = 0;
  const email = 1;
  const phone = 2;
  const password = 3;
  Finder field(int index) => find.byType(TextFormField).at(index);

  Future<void> fillEverythingButPhone(WidgetTester tester) async {
    await tester.enterText(field(fullName), 'Hafiz Ibrahim');
    await tester.enterText(field(email), 'hafiz@example.com');
    await tester.enterText(field(password), 'secret123');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers both roles and starts as a customer', (tester) async {
    await pumpSignUp(tester);

    expect(find.text('Join as'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Technician'), findsOneWidget);
    expect(find.textContaining('You can add this later'), findsOneWidget);
    expect(find.textContaining('reviewed by ReadyTech'), findsNothing);
  });

  testWidgets('a customer may sign up without a phone number', (tester) async {
    await pumpSignUp(tester);

    await fillEverythingButPhone(tester);
    await submit(tester);

    expect(repository.signUpCallCount, 1);
    expect(repository.lastSignUpRole, UserRole.customer);
  });

  testWidgets(
    'choosing technician explains verification and requires a phone',
    (
      tester,
    ) async {
      await pumpSignUp(tester);

      await tester.tap(find.text('Technician'));
      await tester.pumpAndSettle();

      expect(find.textContaining('reviewed by ReadyTech'), findsOneWidget);
      expect(find.textContaining('this is required'), findsOneWidget);

      await fillEverythingButPhone(tester);
      await submit(tester);

      expect(find.text('Phone number is required'), findsOneWidget);
      expect(repository.signUpCallCount, 0);
    },
  );

  testWidgets('submits a technician registration', (tester) async {
    await pumpSignUp(tester);

    await tester.tap(find.text('Technician'));
    await tester.pumpAndSettle();
    await fillEverythingButPhone(tester);
    await tester.enterText(field(phone), '012 345 6789');
    await submit(tester);

    expect(repository.signUpCallCount, 1);
    expect(repository.lastSignUpRole, UserRole.technician);
  });

  testWidgets('switching back to customer relaxes the phone rule', (
    tester,
  ) async {
    await pumpSignUp(tester);

    await tester.tap(find.text('Technician'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('reviewed by ReadyTech'), findsNothing);

    await fillEverythingButPhone(tester);
    await submit(tester);

    expect(repository.signUpCallCount, 1);
    expect(repository.lastSignUpRole, UserRole.customer);
  });
}
