import Link from 'next/link';
import type { ReactNode } from 'react';
import { describe } from '@/lib/domain/enums';
import { ADMIN_LABEL, STATUS_TONE, type ServiceStatus, type Tone } from '@/lib/domain/service-status';

export function Chip({ label, tone, plain }: { label: string; tone: Tone; plain?: boolean }) {
  return <span className={`chip tone-${tone}${plain ? ' plain' : ''}`}>{label}</span>;
}

export function StatusChip({ status }: { status: ServiceStatus | string }) {
  const known = status in ADMIN_LABEL;
  const label = known ? ADMIN_LABEL[status as ServiceStatus] : status;
  const tone = known ? STATUS_TONE[status as ServiceStatus] : 'neutral';
  return <Chip label={label} tone={tone} />;
}

/** A chip for any of the enum maps in lib/domain/enums.ts. */
export function EnumChip({
  map,
  value,
  plain,
}: {
  map: Record<string, { label: string; tone: Tone }>;
  value: string | null | undefined;
  plain?: boolean;
}) {
  const { label, tone } = describe(map, value);
  return <Chip label={label} tone={tone} plain={plain} />;
}

export function PageHeader({
  title,
  description,
  crumbs,
  actions,
}: {
  title: ReactNode;
  description?: ReactNode;
  crumbs?: { href: string; label: string }[];
  actions?: ReactNode;
}) {
  return (
    <header className="page-header">
      <div>
        {crumbs && crumbs.length > 0 && (
          <div className="crumbs">
            {crumbs.map((c, i) => (
              <span key={c.href}>
                {i > 0 && ' / '}
                <Link href={c.href}>{c.label}</Link>
              </span>
            ))}
          </div>
        )}
        <h1>{title}</h1>
        {description && <p>{description}</p>}
      </div>
      {actions && <div className="actions">{actions}</div>}
    </header>
  );
}

export function Card({
  title,
  description,
  actions,
  flush,
  children,
}: {
  title?: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  flush?: boolean;
  children: ReactNode;
}) {
  return (
    <section className={`card${flush ? ' flush' : ''}`}>
      {(title || actions) && (
        <div className="card-head">
          <div>
            {title && <h2>{title}</h2>}
            {description && <p>{description}</p>}
          </div>
          {actions}
        </div>
      )}
      {children}
    </section>
  );
}

export function Stat({
  label,
  value,
  hint,
  href,
  attention,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  href?: string;
  attention?: boolean;
}) {
  const body = (
    <>
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
      {hint && <div className="stat-hint">{hint}</div>}
    </>
  );
  const className = `stat${attention ? ' attention' : ''}`;
  return href ? (
    <Link href={href} className={className}>
      {body}
    </Link>
  ) : (
    <div className={className}>{body}</div>
  );
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <strong>{title}</strong>
      {children}
    </div>
  );
}

export function Tabs({
  items,
  current,
}: {
  items: { href: string; label: string; key: string; count?: number }[];
  current: string;
}) {
  return (
    <nav className="tabs" aria-label="Filter">
      {items.map((item) => (
        <Link
          key={item.key}
          href={item.href}
          className="tab"
          aria-current={item.key === current ? 'page' : undefined}
        >
          {item.label}
          {item.count !== undefined && <span className="faint"> {item.count}</span>}
        </Link>
      ))}
    </nav>
  );
}

export function Pager({
  page,
  pageSize,
  total,
  hrefFor,
}: {
  page: number;
  pageSize: number;
  total: number;
  hrefFor: (page: number) => string;
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  if (pages <= 1) return null;
  const first = (page - 1) * pageSize + 1;
  const last = Math.min(total, page * pageSize);
  return (
    <div className="pager">
      <span>
        {first}–{last} of {total}
      </span>
      <span className="actions">
        {page > 1 && (
          <Link className="btn secondary small" href={hrefFor(page - 1)}>
            Previous
          </Link>
        )}
        {page < pages && (
          <Link className="btn secondary small" href={hrefFor(page + 1)}>
            Next
          </Link>
        )}
      </span>
    </div>
  );
}

/** Reads a positive page number from a search param. */
export function pageParam(value: string | string[] | undefined): number {
  const n = Number(Array.isArray(value) ? value[0] : value);
  return Number.isInteger(n) && n > 0 ? n : 1;
}

export function firstParam(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export function LoadError({ message }: { message: string }) {
  return <div className="notice error">{message}</div>;
}

/** Name over email, linked to the right detail page for the role. */
export function Person({
  id,
  name,
  email,
  href,
}: {
  id: string | null | undefined;
  name: string | null | undefined;
  email?: string | null;
  href?: string;
}) {
  if (!id) return <span className="faint">—</span>;
  const label = name || email || id.slice(0, 8);
  return (
    <span>
      {href ? <Link href={href}>{label}</Link> : label}
      {email && name && <span className="sub">{email}</span>}
    </span>
  );
}
