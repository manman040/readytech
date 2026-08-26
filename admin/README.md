# ReadyTech admin console

Phase 9. Not yet implemented.

## Why it is separate from the mobile app

Administration is desk work. A verification queue with identity documents side
by side, a dispute with the chat log, the evidence photographs, the quotation
and the payment all visible at once, a pricing table, a report — none of that
fits on a phone, and building it there would make it worse for the person who
has to use it all day.

The mobile app carries a minimal admin landing screen so an administrator
account has somewhere to go instead of being bounced by the router. Everything
real lives here.

## Planned stack

Next.js (App Router) · TypeScript · Supabase JS · desktop-first.

## Modules

Dashboard · Users · Technicians · Verification queue · Service requests ·
Active jobs · Completed jobs · Categories · Pricing · Quotations · Payments ·
Commissions · Refunds · Reviews · Disputes · Notifications · Reports · Settings

## Metrics

Total users · total technicians · active technicians · active services ·
completed · cancelled · revenue · platform commission · average rating ·
average response time · average completion time.

Charts only where a shape is the point. A number that is read as a number is
better as a number.

## Security

The console is subject to the same Row Level Security as everything else. An
administrator's privileges come from `user_roles`, which the policies in
`supabase/migrations/20260101001200_row_level_security.sql` already grant.

The service-role key, where the console needs one, is used only in server
components and route handlers. It must never appear in a variable prefixed
`NEXT_PUBLIC_`, because those are compiled into the browser bundle.

Privileged actions — resolving a dispute, issuing a refund, suspending a
technician — go through Edge Functions, not through direct table writes. That
keeps the audit trail and the money rules in one place rather than duplicating
them in a second codebase.
