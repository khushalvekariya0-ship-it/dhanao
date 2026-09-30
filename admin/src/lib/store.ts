"use client";

import { useSyncExternalStore } from "react";
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";

import { dateLong, money } from "./format";
import { buildSeed, type SeedData } from "./seed";
import { nextStage, stageInfo } from "./stages";
import type {
  AppSettings,
  AppUser,
  GemStock,
  Job,
  MetalStock,
  Partner,
  ProjectFile,
  Session,
  StageKey,
} from "./types";

export const SESSION_COOKIE = "dhanaos_session";

/** Fields accepted when creating a job from the admin. */
export type NewJobInput = Pick<Job, "title" | "customer" | "productType" | "metal" | "dueDate" | "value"> &
  Partial<Pick<Job, "priority" | "centerStone" | "settingStyle" | "weightGrams" | "ringSize" | "quantity" | "notes" | "image">>;

interface State extends SeedData {
  session: Session | null;
  seq: number;

  // Session
  /** Returns an error message, or null on success. `remember` keeps the session after the browser closes. */
  login: (email: string, password: string, remember?: boolean) => string | null;
  logout: () => void;

  // Settings
  updateSettings: (patch: Partial<AppSettings>) => void;
  resetDemo: () => void;

  // Jobs
  addJob: (input: NewJobInput) => string;
  updateJob: (id: string, patch: Partial<Job>) => void;
  deleteJob: (id: string) => void;
  toggleRisk: (id: string) => void;
  setStage: (id: string, stage: StageKey, opts?: { by?: string; note?: string }) => void;
  completeStage: (id: string, opts?: { by?: string; note?: string }) => void;
  assignStage: (id: string, stage: StageKey, who: string, expected?: string) => void;
  recordStage: (id: string, stage: StageKey, data: Record<string, string>) => void;
  postMessage: (id: string, text: string) => void;
  addFile: (id: string, file: Omit<ProjectFile, "date" | "uploadedBy" | "sizeLabel"> & Partial<ProjectFile>) => void;
  removeFile: (id: string, index: number) => void;

  // Partners
  savePartner: (p: Partner) => void;
  deletePartner: (id: string) => void;

  // Inventory
  adjustMetal: (code: string, deltaGrams: number, note?: string) => void;
  saveMetal: (m: MetalStock, originalCode?: string) => void;
  deleteMetal: (code: string) => void;
  saveGem: (g: GemStock, originalId?: string) => void;
  deleteGem: (id: string) => void;
  assignGem: (gemId: string, jobId: string | null) => void;

  // Dashboard
  dismissAction: (id: string) => void;

  // Users
  saveUser: (u: AppUser) => void;
  deleteUser: (id: string) => void;
}

const nowIso = () => new Date().toISOString();
const uid = (p: string) => `${p}-${Math.random().toString(36).slice(2, 9)}`;

function setCookie(on: boolean, remember = true) {
  if (typeof document === "undefined") return;
  // Without "remember me" it's a session cookie that ends when the browser closes.
  document.cookie = on
    ? `${SESSION_COOKIE}=1; path=/;${remember ? ` max-age=${60 * 60 * 24 * 7};` : ""} samesite=lax`
    : `${SESSION_COOKIE}=; path=/; max-age=0; samesite=lax`;
}

/** True when the session cookie the proxy checks is present. */
export const hasSessionCookie = () =>
  typeof document !== "undefined" && document.cookie.split("; ").includes(`${SESSION_COOKIE}=1`);

export const useStore = create<State>()(
  persist(
    (set, get) => {
      /** Immutably update one job and log an activity line. */
      const patchJob = (id: string, fn: (j: Job) => Job, activity?: string) =>
        set((s) => ({
          jobs: s.jobs.map((j) => (j.id === id ? fn(j) : j)),
          activity: activity
            ? [{ id: uid("act"), text: activity, jobId: id, time: nowIso(), by: s.session?.name ?? "Admin" }, ...s.activity]
            : s.activity,
        }));
      const me = () => get().session?.name ?? "Admin";

      return {
        ...buildSeed(),
        session: null,
        seq: 1842,

        login: (email, password, remember = true) => {
          const u = get().users.find((x) => x.email.toLowerCase() === email.trim().toLowerCase());
          if (!u || u.password !== password) return "Incorrect email or password.";
          if (!u.active) return "This account is deactivated.";
          if (u.role !== "Admin" && u.role !== "Manufacturing Engineer") {
            return "Only Admin and Manufacturing Engineer accounts can open the admin panel.";
          }
          setCookie(true, remember);
          set((s) => ({
            session: { userId: u.id, name: u.name, email: u.email, role: u.role },
            users: s.users.map((x) => (x.id === u.id ? { ...x, lastActive: nowIso() } : x)),
          }));
          return null;
        },
        logout: () => {
          setCookie(false);
          set({ session: null });
        },

        updateSettings: (patch) => set((s) => ({ settings: { ...s.settings, ...patch } })),
        resetDemo: () => set((s) => ({ ...buildSeed(), session: s.session, seq: 1842, settings: s.settings })),

        addJob: (input) => {
          const seq = get().seq + 1;
          const id = `DH-2026-${String(seq).padStart(5, "0")}`;
          const at = nowIso();
          const job: Job = {
            id,
            manufacturer: get().settings.companyName,
            priority: "standard",
            centerStone: "—",
            settingStyle: "—",
            quantity: 1,
            atRisk: false,
            ...input,
            stage: "inquiry",
            stageEnteredAt: at,
            history: [{ stage: "inquiry", at, by: me() }],
            stageData: {
              inquiry: {
                "Order Type": "Admin Panel",
                Customer: input.customer,
                Product: input.productType,
                Piece: input.title,
                Metal: input.metal,
                ...(input.centerStone && input.centerStone !== "—" ? { "Center Stone": input.centerStone } : {}),
                ...(input.ringSize ? { "Ring Size": input.ringSize } : {}),
                Quantity: String(input.quantity ?? 1),
                "Target Value": money(input.value),
                "Requested Delivery": dateLong(input.dueDate),
                ...(input.notes ? { Notes: input.notes } : {}),
                "Created By": me(),
              },
            },
            thread: [{ author: "System", kind: "stage", title: "Job Order Created", text: `Created in the admin panel by ${me()}.`, time: at }],
            files: [],
          };
          set((s) => ({
            seq,
            jobs: [job, ...s.jobs],
            activity: [{ id: uid("act"), text: "Job order created", jobId: id, time: at, by: me() }, ...s.activity],
          }));
          return id;
        },
        updateJob: (id, patch) => patchJob(id, (j) => ({ ...j, ...patch })),
        deleteJob: (id) =>
          set((s) => ({
            jobs: s.jobs.filter((j) => j.id !== id),
            gems: s.gems.map((g) => (g.assignedJobId === id ? { ...g, assignedJobId: null } : g)),
            actions: s.actions.filter((a) => a.jobId !== id),
          })),
        toggleRisk: (id) => patchJob(id, (j) => ({ ...j, atRisk: !j.atRisk })),

        setStage: (id, stage, opts) => {
          const job = get().jobs.find((j) => j.id === id);
          if (!job || job.stage === stage) return;
          const at = nowIso();
          const by = opts?.by || me();
          const label = stageInfo(stage).label;
          patchJob(
            id,
            (j) => ({
              ...j,
              stage,
              stageEnteredAt: at,
              history: [...j.history, { stage, at, by, note: opts?.note ?? null }],
              thread: [
                ...j.thread,
                { author: "System", kind: "stage", title: `Stage Changed: ${label}`, text: opts?.note || `${by} moved the job to ${label}.`, time: at },
              ],
            }),
            `${label} started`,
          );
        },
        completeStage: (id, opts) => {
          const job = get().jobs.find((j) => j.id === id);
          if (!job) return;
          const next = nextStage(job.stage);
          const by = opts?.by?.trim() || me();
          get().recordStage(id, job.stage, { "Completed By": by, ...(opts?.note ? { "Completion Note": opts.note } : {}) });
          if (next) get().setStage(id, next, { by, note: opts?.note });
        },
        assignStage: (id, stage, who, expected) =>
          patchJob(id, (j) => ({
            ...j,
            assignee: stage === j.stage ? who : j.assignee,
            stageData: {
              ...j.stageData,
              [stage]: { ...(j.stageData[stage] ?? {}), "Assigned To": who, ...(expected ? { Expected: dateLong(expected) } : {}) },
            },
            thread: [
              ...j.thread,
              {
                author: "System",
                kind: "system",
                title: `Assigned: ${stageInfo(stage).label}`,
                text: `${who} will handle ${stageInfo(stage).label}${expected ? ` by ${dateLong(expected)}` : ""}.`,
                time: nowIso(),
              },
            ],
          })),
        recordStage: (id, stage, data) => {
          const clean = Object.fromEntries(Object.entries(data).filter(([, v]) => v.trim() !== ""));
          if (!Object.keys(clean).length) return;
          patchJob(id, (j) => ({ ...j, stageData: { ...j.stageData, [stage]: { ...(j.stageData[stage] ?? {}), ...clean } } }));
        },
        postMessage: (id, text) =>
          patchJob(id, (j) => ({ ...j, thread: [...j.thread, { author: me(), text, time: nowIso(), kind: "message", isMe: true }] })),
        addFile: (id, file) =>
          patchJob(
            id,
            (j) => ({
              ...j,
              files: [{ uploadedBy: me(), date: nowIso(), sizeLabel: "—", ...file }, ...j.files],
              thread: [...j.thread, { author: me(), kind: "file", title: "File uploaded", text: file.name, time: nowIso() }],
            }),
            "File uploaded",
          ),
        removeFile: (id, index) => patchJob(id, (j) => ({ ...j, files: j.files.filter((_, i) => i !== index) })),

        savePartner: (p) =>
          set((s) => ({
            partners: s.partners.some((x) => x.id === p.id) ? s.partners.map((x) => (x.id === p.id ? p : x)) : [p, ...s.partners],
          })),
        deletePartner: (id) => set((s) => ({ partners: s.partners.filter((p) => p.id !== id) })),

        adjustMetal: (code, delta) =>
          set((s) => ({ metals: s.metals.map((m) => (m.code === code ? { ...m, grams: Math.max(0, +(m.grams + delta).toFixed(2)) } : m)) })),
        saveMetal: (m, originalCode) =>
          set((s) => {
            const key = originalCode ?? m.code;
            const exists = s.metals.some((x) => x.code === key);
            return { metals: exists ? s.metals.map((x) => (x.code === key ? m : x)) : [...s.metals, m] };
          }),
        deleteMetal: (code) => set((s) => ({ metals: s.metals.filter((m) => m.code !== code) })),
        saveGem: (g, originalId) =>
          set((s) => {
            const key = originalId ?? g.id;
            const exists = s.gems.some((x) => x.id === key);
            return { gems: exists ? s.gems.map((x) => (x.id === key ? g : x)) : [g, ...s.gems] };
          }),
        deleteGem: (id) => set((s) => ({ gems: s.gems.filter((g) => g.id !== id) })),
        assignGem: (gemId, jobId) => set((s) => ({ gems: s.gems.map((g) => (g.id === gemId ? { ...g, assignedJobId: jobId } : g)) })),

        dismissAction: (id) => set((s) => ({ actions: s.actions.filter((a) => a.id !== id) })),

        saveUser: (u) =>
          set((s) => ({ users: s.users.some((x) => x.id === u.id) ? s.users.map((x) => (x.id === u.id ? u : x)) : [...s.users, u] })),
        deleteUser: (id) => set((s) => ({ users: s.users.filter((u) => u.id !== id) })),
      };
    },
    {
      name: "dhanaos-admin-v1",
      // Browser only — Node 25 exposes a global localStorage on the server too.
      storage: createJSONStorage(() =>
        typeof window !== "undefined"
          ? window.localStorage
          : { getItem: () => null, setItem: () => undefined, removeItem: () => undefined },
      ),
      partialize: ({ jobs, partners, metals, gems, actions, activity, users, settings, session, seq }) => ({
        jobs,
        partners,
        metals,
        gems,
        actions,
        activity,
        users,
        settings,
        session,
        seq,
      }),
    },
  ),
);

/** True once the persisted store has loaded in the browser (gate client-only UI on it). */
export function useHydrated() {
  return useSyncExternalStore(
    (onChange) => useStore.persist.onFinishHydration(onChange),
    () => useStore.persist.hasHydrated(),
    () => false,
  );
}

/** Look up a job by id (undefined if missing). */
export const useJob = (id: string) => useStore((s) => s.jobs.find((j) => j.id === id));

export const newId = uid;
