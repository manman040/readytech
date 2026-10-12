/**
 * PostgREST select strings shared between pages, so "a job row with its
 * people" means the same columns everywhere.
 *
 * Foreign keys are named explicitly: service_requests references profiles and
 * technician_profiles more than once, and an ambiguous embed is an error.
 */

export const JOB_LIST_SELECT = `
  id, reference, status, urgency, created_at, requested_at, updated_at,
  problem_summary, problem_description, service_address,
  estimated_total_min_sen, estimated_total_max_sen,
  customer:profiles!service_requests_customer_id_fkey ( id, full_name, email ),
  technician:technician_profiles!service_requests_assigned_technician_id_fkey (
    id, profile:profiles!technician_profiles_id_fkey ( full_name, email )
  ),
  category:service_categories!service_requests_category_id_fkey ( name )
`;

export type PersonRef = { id: string; full_name: string; email: string } | null;

export type JobListRow = {
  id: string;
  reference: string;
  status: string;
  urgency: string;
  created_at: string;
  requested_at: string;
  updated_at: string;
  problem_summary: string | null;
  problem_description: string;
  service_address: string;
  estimated_total_min_sen: number | null;
  estimated_total_max_sen: number | null;
  customer: PersonRef;
  technician: { id: string; profile: { full_name: string; email: string } | null } | null;
  category: { name: string } | null;
};

/** PostgREST `or` filters take user input inside the filter syntax, so commas,
 * parentheses and wildcards have to go before it is interpolated. */
export function searchTerm(input: string | undefined): string | null {
  const cleaned = (input ?? '').replace(/[,()*%\\:"']/g, ' ').trim().slice(0, 80);
  return cleaned.length >= 2 ? cleaned : null;
}
