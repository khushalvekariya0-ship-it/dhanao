import raw from "@/data/seed.json";
import type {
  ActionItem,
  ActivityItem,
  AppSettings,
  AppUser,
  GemStock,
  Job,
  MetalStock,
  Partner,
} from "./types";

/**
 * Demo data exported from the Flutter app. Dates are shifted so they stay
 * relative to "now" (a job due today when exported is due today when loaded).
 */
export interface SeedData {
  jobs: Job[];
  partners: Partner[];
  metals: MetalStock[];
  gems: GemStock[];
  actions: ActionItem[];
  activity: ActivityItem[];
  users: AppUser[];
  settings: AppSettings;
}

const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;

function shiftDates<T>(value: T, offsetMs: number): T {
  if (typeof value === "string" && ISO.test(value)) {
    return new Date(Date.parse(value) + offsetMs).toISOString() as T;
  }
  if (Array.isArray(value)) return value.map((v) => shiftDates(v, offsetMs)) as T;
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, shiftDates(v, offsetMs)])) as T;
  }
  return value;
}

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

export const DEFAULT_SETTINGS: AppSettings = {
  companyName: "AuraForge India",
  currency: "USD",
  timezone: "Asia/Kolkata",
  theme: "light",
  notifyStageChanges: true,
  notifyDelays: true,
  notifyApprovals: true,
  dueSoonDays: 3,
};

export const DEMO_LOGIN = { email: "admin@dhanaos.com", password: "admin123" };

export function buildSeed(): SeedData {
  const offset = Date.now() - Date.parse(raw.exportedAt);
  const data = shiftDates(raw, offset);
  const now = new Date().toISOString();

  const users: AppUser[] = [
    { id: "u-admin", name: "Admin", email: DEMO_LOGIN.email, password: DEMO_LOGIN.password, role: "Admin", active: true, lastActive: now },
    { id: "u-ravi", name: "Ravi S.", email: "ravi@auraforge.in", password: "ravi123", role: "Manufacturing Engineer", active: true, avatar: "avatar_ravi.jpg", lastActive: now },
    { id: "u-sarah", name: "Sarah J.", email: "sarah@auraforge.in", password: "sarah123", role: "CAD Designer", active: true, avatar: "avatar_sarah.jpg" },
    { id: "u-mike", name: "Mike T.", email: "mike@auraforge.in", password: "mike123", role: "CAD Designer", active: true },
    { id: "u-patel", name: "Patel Casting Works", email: "ops@patelcasting.in", password: "patel123", role: "Caster", active: true, avatar: "avatar_patel.jpg" },
    { id: "u-marco", name: "Marco V.", email: "marco@auraforge.in", password: "marco123", role: "Setter", active: true },
    { id: "u-carter", name: "E. Carter", email: "carter@auraforge.in", password: "carter123", role: "QC Specialist", active: true },
    { id: "u-scottsdale", name: "Scottsdale Diamond Co.", email: "orders@scottsdale.com", password: "scott123", role: "Retailer", active: false },
  ];

  return {
    jobs: data.jobs as unknown as Job[],
    partners: data.partners.map((p) => ({ ...p, id: slug(p.name), email: null }) as Partner),
    metals: data.metals as MetalStock[],
    gems: data.gems as unknown as GemStock[],
    actions: data.actions.map((a, i) => ({ ...a, id: `a${i + 1}` }) as ActionItem),
    activity: data.activity.map((a, i) => ({ ...a, id: `act${i + 1}` })),
    users,
    settings: { ...DEFAULT_SETTINGS },
  };
}
