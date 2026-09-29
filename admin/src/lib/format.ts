const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const d = (v: string | Date) => (typeof v === "string" ? new Date(v) : v);

const SYMBOL: Record<string, string> = { USD: "$", INR: "₹", EUR: "€" };
let currency = "USD";

/** Set from Settings (the admin shell calls this on every render). */
export const setCurrency = (code: string) => {
  currency = code;
};

/** $4,850 / ₹4,850 / €4,850 in the currency chosen in Settings. */
export const money = (v: number, cents = false) =>
  `${v < 0 ? "-" : ""}${SYMBOL[currency] ?? `${currency} `}${Math.abs(v).toLocaleString(currency === "INR" ? "en-IN" : "en-US", {
    minimumFractionDigits: cents ? 2 : 0,
    maximumFractionDigits: cents ? 2 : 0,
  })}`;

/** 1,240.5 g */
export const grams = (v: number, digits = 1) =>
  `${v.toLocaleString("en-US", { minimumFractionDigits: digits, maximumFractionDigits: digits })} g`;

/** Aug 24 */
export const date = (v: string | Date) => `${MONTHS[d(v).getMonth()]} ${d(v).getDate()}`;

/** Aug 24, 2026 */
export const dateLong = (v: string | Date) => `${date(v)}, ${d(v).getFullYear()}`;

/** 09:15 AM */
export const time = (v: string | Date) => {
  const x = d(v);
  const h = x.getHours() % 12 || 12;
  return `${String(h).padStart(2, "0")}:${String(x.getMinutes()).padStart(2, "0")} ${x.getHours() < 12 ? "AM" : "PM"}`;
};

const startOfDay = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();

/** Whole days from today until [v] (negative = past). */
export const daysUntil = (v: string | Date) => Math.round((startOfDay(d(v)) - startOfDay(new Date())) / 86_400_000);

/** "Today, 10:42 AM" / "Yesterday, …" / "Aug 12, 05:00 PM" */
export const relativeDay = (v: string | Date) => {
  const diff = daysUntil(v);
  if (diff === 0) return `Today, ${time(v)}`;
  if (diff === -1) return `Yesterday, ${time(v)}`;
  if (diff === 1) return `Tomorrow, ${time(v)}`;
  return `${date(v)}, ${time(v)}`;
};

/** "10 mins ago" */
export const ago = (v: string | Date) => {
  const s = (Date.now() - d(v).getTime()) / 1000;
  if (s < 60) return "just now";
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min${m === 1 ? "" : "s"} ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} hr${h === 1 ? "" : "s"} ago`;
  const days = Math.floor(h / 24);
  return `${days} day${days === 1 ? "" : "s"} ago`;
};

/** "DUE TODAY", "DUE TMRW", "DUE IN 5D", "OVERDUE 2D" */
export const dueTag = (days: number) => {
  if (days < 0) return `OVERDUE ${-days}D`;
  if (days === 0) return "DUE TODAY";
  if (days === 1) return "DUE TMRW";
  return `DUE IN ${days}D`;
};

/** "2d 4h", "3h 20m", "12m" */
export const duration = (ms: number) => {
  const mins = Math.max(0, Math.floor(ms / 60_000));
  const days = Math.floor(mins / 1440);
  const hours = Math.floor((mins % 1440) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${mins % 60}m`;
  return `${mins}m`;
};

/** <input type="date"> value ↔ ISO */
export const toDateInput = (v?: string | null) => {
  if (!v) return "";
  const x = new Date(v);
  return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, "0")}-${String(x.getDate()).padStart(2, "0")}`;
};
export const fromDateInput = (v: string) => new Date(`${v}T12:00:00`).toISOString();

export const initials = (name: string) => {
  const p = name.trim().split(/\s+/).filter(Boolean);
  if (!p.length) return "?";
  return (p.length === 1 ? p[0][0] : p[0][0] + p[1][0]).toUpperCase();
};
