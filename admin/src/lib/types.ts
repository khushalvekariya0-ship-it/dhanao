// Domain types — mirror the Flutter app's models (lib/core/models.dart).

export const STAGE_KEYS = [
  "inquiry",
  "cad",
  "approval",
  "pricing",
  "finalApproval",
  "wax",
  "casting",
  "assembly",
  "setting",
  "polishing",
  "qc",
  "certification",
  "dispatch",
  "delivered",
] as const;

export type StageKey = (typeof STAGE_KEYS)[number];

export type Priority = "standard" | "high" | "rush" | "critical";

export type MessageKind = "message" | "system" | "file" | "stage";

export type FileKind = "image" | "cad" | "pdf" | "sheet" | "audio";

export interface StageEvent {
  stage: StageKey;
  /** ISO date */
  at: string;
  by: string;
  note?: string | null;
}

export interface ThreadMessage {
  author: string;
  text: string;
  time: string;
  kind: MessageKind;
  title?: string | null;
  isMe?: boolean;
  /** file name under /images */
  avatar?: string | null;
}

export interface ProjectFile {
  name: string;
  kind: FileKind;
  /** file name under /images for image files */
  asset?: string | null;
  /** data: URL for files uploaded in the admin */
  dataUrl?: string | null;
  uploadedBy: string;
  date: string;
  sizeLabel: string;
}

export interface Job {
  id: string;
  title: string;
  productType: string;
  customer: string;
  manufacturer: string;
  stage: StageKey;
  priority: Priority;
  dueDate: string;
  value: number;
  image?: string | null;
  metal: string;
  centerStone: string;
  settingStyle: string;
  weightGrams?: number | null;
  ringSize?: string | null;
  assignee?: string | null;
  stageEnteredAt?: string | null;
  atRisk: boolean;
  quantity: number;
  notes?: string | null;
  history: StageEvent[];
  /** What was recorded in each stage — label → value */
  stageData: Partial<Record<StageKey, Record<string, string>>>;
  thread: ThreadMessage[];
  files: ProjectFile[];
}

export interface Partner {
  id: string;
  name: string;
  role: string;
  avatar?: string | null;
  company?: string | null;
  location?: string | null;
  phone?: string | null;
  email?: string | null;
  activeJobs: number;
  rating: number;
}

export interface MetalStock {
  code: string;
  name: string;
  grams: number;
  capacityGrams: number;
  color: string;
}

export interface GemStock {
  id: string;
  name: string;
  tag: string;
  carat: number;
  specs: Record<string, string>;
  location: string;
  image?: string | null;
  assignedJobId?: string | null;
}

export type ActionKind = "cadReview" | "pricing" | "delay" | "missing" | "certification";

export interface ActionItem {
  id: string;
  kind: ActionKind;
  title: string;
  subtitle: string;
  jobId: string;
  cta: string;
}

export interface ActivityItem {
  id: string;
  text: string;
  jobId: string;
  time: string;
  by: string;
}

export type UserRole =
  | "Admin"
  | "Manufacturing Engineer"
  | "CAD Designer"
  | "Caster"
  | "Setter"
  | "QC Specialist"
  | "Logistics"
  | "Retailer";

export const USER_ROLES: UserRole[] = [
  "Admin",
  "Manufacturing Engineer",
  "CAD Designer",
  "Caster",
  "Setter",
  "QC Specialist",
  "Logistics",
  "Retailer",
];

export interface AppUser {
  id: string;
  name: string;
  email: string;
  /** Demo only — frontend panel, no real auth backend. */
  password: string;
  role: UserRole;
  active: boolean;
  avatar?: string | null;
  lastActive?: string | null;
}

export interface AppSettings {
  companyName: string;
  currency: string;
  timezone: string;
  theme: "light" | "dark";
  notifyStageChanges: boolean;
  notifyDelays: boolean;
  notifyApprovals: boolean;
  /** Days before due date that count as "due soon". */
  dueSoonDays: number;
}

export interface Session {
  userId: string;
  name: string;
  email: string;
  role: UserRole;
}
