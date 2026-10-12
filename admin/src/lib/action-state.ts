/** What every server action returns to `ActionForm`. Kept apart from
 * lib/actions.ts so client components can import the type without pulling in
 * server-only code. */
export type ActionState = { ok?: boolean; error?: string; message?: string };
