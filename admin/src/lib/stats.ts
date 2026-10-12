import 'server-only';
import { cache } from 'react';
import { createClient } from '@/lib/supabase/server';

/** The shape returned by admin_dashboard_stats(). Money is in sen. */
export type DashboardStats = {
  customers: number;
  technicians: number;
  technicians_approved: number;
  technicians_available: number;
  technicians_awaiting_review: number;
  documents_pending: number;
  jobs_active: number;
  jobs_matching: number;
  jobs_awaiting_approval: number;
  jobs_payment_pending: number;
  jobs_completed_30d: number;
  jobs_cancelled_30d: number;
  jobs_total: number;
  disputes_open: number;
  messages_reported: number;
  gross_paid_sen_30d: number;
  gross_paid_sen_total: number;
  commission_sen_total: number;
  earnings_pending_sen: number;
  average_rating: number;
  jobs_by_status: Record<string, number>;
};

/** One RPC per request, shared by the sidebar counts and the overview page. */
export const getDashboardStats = cache(async (): Promise<DashboardStats | null> => {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('admin_dashboard_stats');
  if (error) {
    console.error('[admin] admin_dashboard_stats', error);
    return null;
  }
  return data as DashboardStats;
});
