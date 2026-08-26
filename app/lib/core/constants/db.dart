/// Canonical names for every backend surface the client is allowed to touch.
///
/// Nothing in the app may reference a table, bucket, RPC or Edge Function by a
/// raw string literal. Renaming a table then becomes a single edit here plus a
/// migration, and typos surface at compile time instead of at runtime.
abstract final class DbTable {
  static const profiles = 'profiles';
  static const userRoles = 'user_roles';

  /// PostgREST embed target for a profile's role.
  ///
  /// `user_roles` has two foreign keys back to `profiles` - `user_id` and
  /// `assigned_by` - so a bare `user_roles(...)` embed is ambiguous and is
  /// rejected with PGRST201. Naming the constraint says which relationship is
  /// meant. The key in the response is still `user_roles`.
  static const userRolesEmbed = 'user_roles!user_roles_user_id_fkey';

  static const technicianProfiles = 'technician_profiles';
  static const technicianSkills = 'technician_skills';
  static const technicianVerifications = 'technician_verifications';
  static const devices = 'devices';
  static const savedAddresses = 'saved_addresses';
  static const serviceCategories = 'service_categories';
  static const pricingConfig = 'pricing_config';
  static const serviceRequests = 'service_requests';
  static const serviceRequestItems = 'service_request_items';
  static const serviceStatusHistory = 'service_status_history';
  static const technicianLocations = 'technician_locations';
  static const technicianAssignments = 'technician_assignments';
  static const diagnoses = 'diagnoses';
  static const quotations = 'quotations';
  static const quotationItems = 'quotation_items';
  static const quotationApprovals = 'quotation_approvals';
  static const payments = 'payments';
  static const paymentItems = 'payment_items';
  static const technicianEarnings = 'technician_earnings';
  static const serviceEvidence = 'service_evidence';
  static const warranties = 'warranties';
  static const reviews = 'reviews';
  static const messages = 'messages';
  static const notifications = 'notifications';
  static const disputes = 'disputes';
  static const cancellationRecords = 'cancellation_records';
}

/// Supabase Storage buckets. All are private; access is granted by storage
/// policies that mirror the row level security rules of the owning table.
abstract final class StorageBucket {
  static const avatars = 'avatars';
  static const serviceEvidence = 'service-evidence';
  static const technicianDocuments = 'technician-documents';
  static const messageAttachments = 'message-attachments';
}

/// Postgres functions callable through PostgREST `rpc`.
abstract final class DbFunction {
  static const currentUserRole = 'current_user_role';
  static const activeServiceRequest = 'active_service_request';
}

/// Edge Functions. Every financially or authorisation critical operation lives
/// here rather than in the client - see docs/ARCHITECTURE.md.
abstract final class EdgeFunction {
  static const calculateMatching = 'calculate-matching';
  static const createPayment = 'create-payment';
  static const verifyPayment = 'verify-payment';
  static const releasePayment = 'release-payment';
  static const createQuotation = 'create-quotation';
  static const approveQuotation = 'approve-quotation';
  static const createWarranty = 'create-warranty';
  static const sendNotification = 'send-notification';
  static const processCancellation = 'process-cancellation';
  static const resolveDispute = 'resolve-dispute';
}

/// Realtime channel names. Channels are private; authorisation is enforced by
/// realtime policies on the backend.
abstract final class RealtimeChannel {
  static String serviceRequest(String id) => 'service-request:$id';
  static String technicianLocation(String id) => 'technician-location:$id';
  static String conversation(String serviceRequestId) =>
      'conversation:$serviceRequestId';
  static String userNotifications(String userId) => 'notifications:$userId';
}
