/**
 * IST Timezone Helpers
 *
 * All timestamps in the system are in IST (Asia/Kolkata, UTC+5:30).
 * These helpers ensure consistency across all Lambda handlers.
 */

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000; // +5:30 in milliseconds

/** Get current date/time in IST as a Date object */
export function getISTNow(): Date {
  const utcNow = new Date();
  return new Date(utcNow.getTime() + IST_OFFSET_MS);
}

/** Get IST timestamp string: "2026-04-04T15:30:00+05:30" */
export function getISTTimestamp(): string {
  const ist = getISTNow();
  return ist.toISOString().replace('Z', '+05:30');
}

/** Get IST date string: "2026-04-04" */
export function getISTDate(): string {
  const ist = getISTNow();
  return ist.toISOString().split('T')[0];
}

/** Get IST time string: "15:30:00" */
export function getISTTime(): string {
  const ist = getISTNow();
  return ist.toISOString().split('T')[1].split('.')[0];
}

/** Get IST hours and minutes for session comparison: { hours: 15, minutes: 30 } */
export function getISTHoursMinutes(): { hours: number; minutes: number } {
  const ist = getISTNow();
  return {
    hours: ist.getUTCHours(),
    minutes: ist.getUTCMinutes(),
  };
}

/**
 * Check if a given HH:mm time string is between two HH:mm boundaries.
 * Used for determining active session.
 */
export function isTimeBetween(current: string, start: string, end: string): boolean {
  const toMinutes = (t: string) => {
    const [h, m] = t.split(':').map(Number);
    return h * 60 + m;
  };
  const c = toMinutes(current);
  const s = toMinutes(start);
  const e = toMinutes(end);
  return c >= s && c <= e;
}

/** Format a Date as IST date string */
export function formatISTDate(date: Date): string {
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  return ist.toISOString().split('T')[0];
}
