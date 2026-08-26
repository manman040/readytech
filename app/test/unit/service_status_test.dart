import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/data/models/service_status.dart';

void main() {
  group('ServiceStatus', () {
    test('round-trips through its wire name', () {
      for (final status in ServiceStatus.values) {
        expect(ServiceStatus.tryParse(status.wireName), status);
      }
      expect(ServiceStatus.tryParse('NOT_A_STATUS'), isNull);
      expect(ServiceStatus.tryParse(null), isNull);
    });

    test('wire names are SCREAMING_SNAKE_CASE, matching the Postgres enum', () {
      for (final status in ServiceStatus.values) {
        expect(
          status.wireName,
          matches(RegExp(r'^[A-Z][A-Z_]*$')),
          reason: '${status.name} must match the database enum label',
        );
      }
    });

    group('transitions', () {
      test('follows the happy path from request to warranty', () {
        const happyPath = [
          ServiceStatus.requested,
          ServiceStatus.matching,
          ServiceStatus.assigned,
          ServiceStatus.technicianOnTheWay,
          ServiceStatus.arrived,
          ServiceStatus.checkingIn,
          ServiceStatus.diagnosing,
          ServiceStatus.quotationPending,
          ServiceStatus.quotationSubmitted,
          ServiceStatus.awaitingCustomerApproval,
          ServiceStatus.approved,
          ServiceStatus.repairing,
          ServiceStatus.completed,
          ServiceStatus.paymentPending,
          ServiceStatus.paid,
          ServiceStatus.warrantyActive,
        ];

        for (var i = 0; i < happyPath.length - 1; i++) {
          expect(
            happyPath[i].canTransitionTo(happyPath[i + 1]),
            isTrue,
            reason:
                '${happyPath[i].name} should reach ${happyPath[i + 1].name}',
          );
        }
      });

      test('refuses to skip diagnosis and go straight to repair', () {
        expect(
          ServiceStatus.checkingIn.canTransitionTo(ServiceStatus.repairing),
          isFalse,
        );
        expect(
          ServiceStatus.diagnosing.canTransitionTo(ServiceStatus.repairing),
          isFalse,
        );
      });

      test('refuses to reach repair without an approval', () {
        expect(
          ServiceStatus.quotationSubmitted.canTransitionTo(
            ServiceStatus.repairing,
          ),
          isFalse,
        );
        expect(
          ServiceStatus.awaitingCustomerApproval.canTransitionTo(
            ServiceStatus.repairing,
          ),
          isFalse,
        );
        // Only through an explicit approval.
        expect(
          ServiceStatus.awaitingCustomerApproval.canTransitionTo(
            ServiceStatus.approved,
          ),
          isTrue,
        );
        expect(
          ServiceStatus.approved.canTransitionTo(ServiceStatus.repairing),
          isTrue,
        );
      });

      test('refuses to jump to paid without going through payment', () {
        expect(
          ServiceStatus.completed.canTransitionTo(ServiceStatus.paid),
          isFalse,
        );
        expect(
          ServiceStatus.repairing.canTransitionTo(ServiceStatus.paid),
          isFalse,
        );
      });

      test('cancelled is terminal', () {
        expect(ServiceStatus.cancelled.isTerminal, isTrue);
        expect(ServiceStatus.cancelled.allowedTransitions, isEmpty);
      });

      test('never transitions to itself', () {
        for (final status in ServiceStatus.values) {
          expect(
            status.canTransitionTo(status),
            isFalse,
            reason: '${status.name} should not list itself as a next state',
          );
        }
      });

      test('every status except cancelled is reachable from requested', () {
        final reachable = <ServiceStatus>{ServiceStatus.requested};
        final queue = <ServiceStatus>[ServiceStatus.requested];

        while (queue.isNotEmpty) {
          final current = queue.removeLast();
          for (final next in current.allowedTransitions.keys) {
            if (reachable.add(next)) queue.add(next);
          }
        }

        expect(
          reachable,
          containsAll(ServiceStatus.values),
          reason: 'an unreachable status is dead code in the state machine',
        );
      });

      test('every transition names at least one actor', () {
        for (final status in ServiceStatus.values) {
          status.allowedTransitions.forEach((next, actors) {
            expect(
              actors,
              isNotEmpty,
              reason:
                  '${status.name} -> ${next.name} has no permitted actor, '
                  'so it can never be taken',
            );
          });
        }
      });
    });

    group('actor permissions', () {
      test('only the customer may declare the work complete', () {
        expect(
          ServiceStatus.repairing.canBeMovedBy(
            ServiceActor.customer,
            ServiceStatus.completed,
          ),
          isTrue,
        );
        expect(
          ServiceStatus.repairing.canBeMovedBy(
            ServiceActor.technician,
            ServiceStatus.completed,
          ),
          isFalse,
        );
      });

      test('only the customer may approve a quotation', () {
        expect(
          ServiceStatus.awaitingCustomerApproval.canBeMovedBy(
            ServiceActor.customer,
            ServiceStatus.approved,
          ),
          isTrue,
        );
        expect(
          ServiceStatus.awaitingCustomerApproval.canBeMovedBy(
            ServiceActor.technician,
            ServiceStatus.approved,
          ),
          isFalse,
        );
        expect(
          ServiceStatus.awaitingCustomerApproval.canBeMovedBy(
            ServiceActor.admin,
            ServiceStatus.approved,
          ),
          isFalse,
        );
      });

      test('only the system may mark a job paid', () {
        expect(
          ServiceStatus.paymentPending.canBeMovedBy(
            ServiceActor.system,
            ServiceStatus.paid,
          ),
          isTrue,
        );
        for (final actor in [
          ServiceActor.customer,
          ServiceActor.technician,
          ServiceActor.admin,
        ]) {
          expect(
            ServiceStatus.paymentPending.canBeMovedBy(
              actor,
              ServiceStatus.paid,
            ),
            isFalse,
            reason: '${actor.name} must not be able to settle a payment',
          );
        }
      });

      test('a technician cannot assign themselves a job', () {
        expect(
          ServiceStatus.requested.canBeMovedBy(
            ServiceActor.technician,
            ServiceStatus.assigned,
          ),
          isFalse,
        );
        expect(
          ServiceStatus.matching.canBeMovedBy(
            ServiceActor.technician,
            ServiceStatus.assigned,
          ),
          isFalse,
        );
      });

      test('a technician cannot walk away once repair is approved', () {
        expect(
          ServiceStatus.approved.canBeMovedBy(
            ServiceActor.technician,
            ServiceStatus.cancelled,
          ),
          isFalse,
        );
        expect(
          ServiceStatus.repairing.canBeMovedBy(
            ServiceActor.technician,
            ServiceStatus.cancelled,
          ),
          isFalse,
        );
      });

      test('only an admin resolves a dispute', () {
        ServiceStatus.disputed.allowedTransitions.forEach((next, actors) {
          expect(
            actors,
            equals({ServiceActor.admin}),
            reason: 'dispute resolution to ${next.name} must be admin only',
          );
        });
      });
    });

    group('derived properties', () {
      test('isActive covers the live lifecycle only', () {
        expect(ServiceStatus.technicianOnTheWay.isActive, isTrue);
        expect(ServiceStatus.repairing.isActive, isTrue);
        expect(ServiceStatus.cancelled.isActive, isFalse);
        expect(ServiceStatus.warrantyActive.isActive, isFalse);
        expect(ServiceStatus.disputed.isActive, isFalse);
      });

      test('hasAssignedTechnician starts at assignment', () {
        expect(ServiceStatus.requested.hasAssignedTechnician, isFalse);
        expect(ServiceStatus.matching.hasAssignedTechnician, isFalse);
        expect(ServiceStatus.assigned.hasAssignedTechnician, isTrue);
        expect(ServiceStatus.repairing.hasAssignedTechnician, isTrue);
      });

      test('isOnSite starts only after the arrival code is verified', () {
        expect(ServiceStatus.technicianOnTheWay.isOnSite, isFalse);
        // ARRIVED is the technician's own claim; check-in is the verified one.
        expect(ServiceStatus.arrived.isOnSite, isFalse);
        expect(ServiceStatus.checkingIn.isOnSite, isTrue);
        expect(ServiceStatus.repairing.isOnSite, isTrue);
      });

      test('every status has a customer label', () {
        for (final status in ServiceStatus.values) {
          expect(status.customerLabel, isNotEmpty);
          expect(status.technicianLabel, isNotEmpty);
        }
      });
    });
  });
}
