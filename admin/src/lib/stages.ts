import seed from "@/data/seed.json";
import { STAGE_KEYS, type Job, type ProjectFile, type StageKey, type ThreadMessage } from "./types";

export interface StageInfo {
  key: StageKey;
  index: number;
  label: string;
  short: string;
  /** Status color family (hex) */
  color: string;
  summary: string;
  owner: string;
  checklist: string[];
  /** Name of the matching workspace screen in the mobile app */
  workspace: string;
}

export const STAGES: StageInfo[] = seed.stages.map((s, index) => ({ ...s, key: s.key as StageKey, index }));

export const stageInfo = (k: StageKey): StageInfo => STAGES[STAGE_KEYS.indexOf(k)];
export const stageIndex = (k: StageKey) => STAGE_KEYS.indexOf(k);
export const nextStage = (k: StageKey): StageKey | null => STAGE_KEYS[stageIndex(k) + 1] ?? null;

/** 0..1 progress through the pipeline */
export const jobProgress = (j: Job) => stageIndex(j.stage) / (STAGE_KEYS.length - 1);

/** Production-floor kanban columns, as in the app. */
export const BOARD_COLUMNS: { key: string; label: string; stages: StageKey[]; entry: StageKey }[] = [
  { key: "approved", label: "Approved", stages: ["inquiry", "cad", "approval", "pricing", "finalApproval"], entry: "finalApproval" },
  { key: "wax", label: "Wax/Print", stages: ["wax"], entry: "wax" },
  { key: "casting", label: "Casting", stages: ["casting"], entry: "casting" },
  { key: "assembly", label: "Assembly", stages: ["assembly"], entry: "assembly" },
  { key: "setting", label: "Setting", stages: ["setting"], entry: "setting" },
  { key: "finishing", label: "Polish & QC", stages: ["polishing", "qc", "certification"], entry: "polishing" },
  { key: "dispatch", label: "Dispatch", stages: ["dispatch", "delivered"], entry: "dispatch" },
];

export type StageStatus = "done" | "current" | "upcoming" | "skipped";

export const STATUS_LABEL: Record<StageStatus, string> = {
  done: "Completed",
  current: "In Progress",
  upcoming: "Pending",
  skipped: "Skipped",
};

export interface StageRecord {
  stage: StageKey;
  status: StageStatus;
  start?: string;
  end?: string;
  /** Who completed it (done) or who holds it (current/upcoming) */
  by?: string;
  note?: string;
  data: Record<string, string>;
  activity: ThreadMessage[];
  files: ProjectFile[];
  /** ms spent in the stage (until now for the current stage) */
  durationMs?: number;
}

/** Same derivation as the app's StageRecord.of (lib/core/stage_info.dart). */
export function stageRecord(job: Job, s: StageKey): StageRecord {
  let entryIdx = -1;
  job.history.forEach((h, i) => {
    if (h.stage === s) entryIdx = i;
  });
  const entry = entryIdx >= 0 ? job.history[entryIdx] : undefined;
  const past = stageIndex(s) < stageIndex(job.stage);
  const exit = entry && past ? job.history[entryIdx + 1] : undefined;
  const data = job.stageData[s] ?? {};

  let status: StageStatus;
  if (s === job.stage) status = "current";
  else if (!past) status = "upcoming";
  else status = entry || Object.keys(data).length ? "done" : "skipped";

  const startMs = entry && status !== "upcoming" ? Date.parse(entry.at) : undefined;
  const endMs = exit ? Date.parse(exit.at) : undefined;
  const inWindow = (iso: string) => {
    if (startMs === undefined) return false;
    const t = Date.parse(iso);
    return t >= startMs && (endMs === undefined || t < endMs);
  };

  let by: string | undefined;
  let note: string | undefined;
  if (status === "current") by = data["Assigned To"] ?? job.assignee ?? undefined;
  else if (status === "upcoming") by = data["Assigned To"];
  else {
    by = data["Completed By"] ?? exit?.by ?? entry?.by;
    if (!("Completion Note" in data)) note = exit?.note ?? undefined;
  }

  const until = endMs ?? (status === "current" ? Date.now() : undefined);
  return {
    stage: s,
    status,
    start: status === "upcoming" ? undefined : entry?.at,
    end: exit?.at,
    by,
    note,
    data,
    activity: job.thread.filter((m) => inWindow(m.time)),
    files: job.files.filter((f) => inWindow(f.date)),
    durationMs: startMs !== undefined && until !== undefined ? until - startMs : undefined,
  };
}
