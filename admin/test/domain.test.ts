import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe as group, expect, it } from 'vitest';
import { DEVICE_TYPE, ENUM_MIRRORS, USER_ROLE, describe as describeValue } from '@/lib/domain/enums';
import {
  ADMIN_LABEL,
  CLOSED_STATUSES,
  CUSTOMER_LABEL,
  SERVICE_STATUSES,
  STATUS_TONE,
} from '@/lib/domain/service-status';

/**
 * The console keeps its own copies of the schema's vocabularies and the app's
 * wording. These tests read the migrations and the Dart sources directly, so a
 * value added on either side without the other fails here instead of rendering
 * as a raw enum string in front of an administrator.
 */

const repo = join(__dirname, '..', '..');
const migrations = readdirSync(join(repo, 'supabase', 'migrations'))
  .filter((f) => f.endsWith('.sql'))
  .sort()
  .map((f) => readFileSync(join(repo, 'supabase', 'migrations', f), 'utf8'))
  .join('\n');
const dart = (path: string) => readFileSync(join(repo, 'app', 'lib', ...path.split('/')), 'utf8');

function postgresEnums(): Map<string, string[]> {
  const found = new Map<string, string[]>();
  for (const m of migrations.matchAll(/create type public\.(\w+) as enum \(([^)]*)\)/g)) {
    const values = [...(m[2] ?? '').matchAll(/'([^']+)'/g)].map((v) => v[1] as string);
    found.set(m[1] as string, values);
  }
  // `alter type ... add value` would extend an enum; there are none yet, and
  // if one appears it must be reflected here too.
  for (const m of migrations.matchAll(/alter type public\.(\w+) add value(?: if not exists)? '([^']+)'/g)) {
    found.get(m[1] as string)?.push(m[2] as string);
  }
  return found;
}

/** `camelCase('SCREAMING')` pairs from a Dart enum declaration. */
function dartWireNames(source: string, enumName: string): Map<string, string> {
  const body = source.slice(source.indexOf(`enum ${enumName} {`));
  const pairs = new Map<string, string>();
  for (const m of body.matchAll(/^\s+(\w+)\('([^']+)'\)/gm)) pairs.set(m[1] as string, m[2] as string);
  return pairs;
}

/** `name => 'Label'` pairs from a Dart switch expression getter. */
function dartLabels(source: string, getter: string): Map<string, string> {
  const start = source.indexOf(`get ${getter} => switch`);
  const block = source.slice(start, source.indexOf('};', start));
  const pairs = new Map<string, string>();
  for (const m of block.matchAll(/^\s+(\w+) => '([^']+)'/gm)) pairs.set(m[1] as string, m[2] as string);
  return pairs;
}

group('Postgres enums', () => {
  const enums = postgresEnums();

  it('service_status matches, in order', () => {
    expect(SERVICE_STATUSES).toEqual(enums.get('service_status'));
  });

  for (const [name, mirror] of Object.entries(ENUM_MIRRORS)) {
    it(`${name} has a label for exactly the database's values`, () => {
      expect(enums.has(name), `no enum ${name} in the migrations`).toBe(true);
      expect(Object.keys(mirror).sort()).toEqual([...(enums.get(name) ?? [])].sort());
    });
  }

  it('every enum the console renders is mirrored', () => {
    const rendered = [...enums.keys()].filter((name) => !['service_status', 'notification_type', 'message_kind', 'address_label'].includes(name));
    expect(rendered.filter((name) => !(name in ENUM_MIRRORS))).toEqual([]);
  });
});

group('Same words as the app', () => {
  const statusSource = dart('data/models/service_status.dart');
  const wire = dartWireNames(statusSource, 'ServiceStatus');

  it('customer-facing status labels match ServiceStatus.customerLabel', () => {
    const labels = dartLabels(statusSource, 'customerLabel');
    expect(labels.size).toBe(SERVICE_STATUSES.length);
    for (const [dartName, label] of labels) {
      const status = wire.get(dartName) as keyof typeof CUSTOMER_LABEL;
      expect(CUSTOMER_LABEL[status], dartName).toBe(label);
    }
  });

  it('admin labels are the technician wording, apart from calling a dispute a dispute', () => {
    const overrides = dartLabels(statusSource, 'technicianLabel');
    expect(overrides.size).toBeGreaterThan(0);
    for (const status of SERVICE_STATUSES) {
      if (status === 'DISPUTED') continue;
      const dartName = [...wire].find(([, w]) => w === status)?.[0] as string;
      expect(ADMIN_LABEL[status], status).toBe(overrides.get(dartName) ?? CUSTOMER_LABEL[status]);
    }
  });

  it('status colours match ServiceStatusChip.toneOf', () => {
    const chip = dart('core/widgets/status_chip.dart');
    const block = chip.slice(chip.indexOf('toneOf('), chip.indexOf('};', chip.indexOf('toneOf(')));
    const tones = new Map<string, string>();
    let pending: string[] = [];
    for (const line of block.split('\n')) {
      for (const m of line.matchAll(/ServiceStatus\.(\w+)/g)) pending.push(m[1] as string);
      const tone = line.match(/=> StatusTone\.(\w+)/);
      if (tone) {
        for (const name of pending) tones.set(name, tone[1] as string);
        pending = [];
      }
    }
    expect(tones.size).toBe(SERVICE_STATUSES.length);
    for (const [dartName, tone] of tones) {
      const status = wire.get(dartName) as keyof typeof STATUS_TONE;
      expect(STATUS_TONE[status], dartName).toBe(tone);
    }
  });

  it('closed statuses match the app', () => {
    const block = statusSource.slice(statusSource.indexOf('_closedStatuses = {'));
    const closed = [...block.slice(0, block.indexOf('};')).matchAll(/ServiceStatus\.(\w+)/g)].map((m) =>
      wire.get(m[1] as string),
    );
    expect([...CLOSED_STATUSES].sort()).toEqual(closed.sort());
  });

  it('device type labels match DeviceType.label', () => {
    const source = dart('data/models/device_type.dart');
    const deviceWire = dartWireNames(source, 'DeviceType');
    for (const [dartName, label] of dartLabels(source, 'label')) {
      const key = deviceWire.get(dartName) as keyof typeof DEVICE_TYPE;
      expect(DEVICE_TYPE[key]?.label, dartName).toBe(label);
    }
  });

  it('role labels match UserRole.label', () => {
    const source = dart('data/models/user_role.dart');
    const roleWire = dartWireNames(source, 'UserRole');
    for (const [dartName, label] of dartLabels(source, 'label')) {
      const key = roleWire.get(dartName) as keyof typeof USER_ROLE;
      expect(USER_ROLE[key]?.label, dartName).toBe(label);
    }
  });
});

group('describe', () => {
  it('renders an unknown value instead of failing', () => {
    expect(describeValue(DEVICE_TYPE, 'smart_fridge')).toEqual({ label: 'Smart fridge', tone: 'neutral' });
    expect(describeValue(DEVICE_TYPE, null).label).toBe('—');
  });
});
