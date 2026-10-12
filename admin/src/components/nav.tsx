'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

export type NavItem = { href: string; label: string; count?: number };
export type NavGroup = { title: string; items: NavItem[] };

export function Nav({ groups }: { groups: NavGroup[] }) {
  const pathname = usePathname();
  const isCurrent = (href: string) =>
    href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(`${href}/`);

  return (
    <>
      {groups.map((group) => (
        <div key={group.title} style={{ display: 'contents' }}>
          <div className="nav-section">{group.title}</div>
          {group.items.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="nav-link"
              aria-current={isCurrent(item.href) ? 'page' : undefined}
            >
              {item.label}
              {item.count ? <span className="nav-count">{item.count}</span> : null}
            </Link>
          ))}
        </div>
      ))}
    </>
  );
}
