"use client";

import {
  ArrowLeft,
  ArrowRight,
  ArrowRightLeft,
  Award,
  Box,
  Calculator,
  Check,
  CheckCircle2,
  ChevronRight,
  Circle,
  CircleDot,
  ClipboardList,
  Download,
  FileMusic,
  FileSpreadsheet,
  FileText,
  Flag,
  Flame,
  FolderOpen,
  Gem,
  Image as ImageIcon,
  ListChecks,
  MessagesSquare,
  Minus,
  PackageCheck,
  PanelRightOpen,
  Paperclip,
  Pencil,
  Play,
  Plus,
  Printer,
  RotateCcw,
  Send,
  Sparkles,
  Stamp,
  ThumbsUp,
  Trash2,
  Truck,
  Upload,
  User,
  UserPlus,
  Wrench,
  X,
  type LucideIcon,
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Fragment, useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from "react";

import { useToast } from "@/components/toast";
import {
  Avatar,
  Badge,
  Button,
  ButtonLink,
  Card,
  CardHeader,
  ConfirmModal,
  Drawer,
  EmptyState,
  Field,
  IconButton,
  Input,
  Modal,
  PriorityBadge,
  ProgressBar,
  Segmented,
  Select,
  Tabs,
  Textarea,
  Thumb,
  cn,
  type Tone,
} from "@/components/ui";
import { date, dateLong, daysUntil, dueTag, duration, fromDateInput, money, relativeDay, time, toDateInput } from "@/lib/format";
import { useJob, useStore } from "@/lib/store";
import { STAGES, STATUS_LABEL, jobProgress, nextStage, stageIndex, stageInfo, stageRecord, type StageRecord, type StageStatus } from "@/lib/stages";
import type { FileKind, Job, Partner, ProjectFile, StageKey, ThreadMessage } from "@/lib/types";
import { METALS, PRIORITY_OPTIONS, PRODUCT_TYPES, RING_SIZES, isRing, readImage } from "./new-job-view";

// ---------------------------------------------------------------------------
// Stage helpers (mirror lib/screens/jobs/stage_sheet.dart)

const STAGE_ICON: Record<StageKey, LucideIcon> = {
  inquiry: ClipboardList,
  cad: Box,
  approval: ThumbsUp,
  pricing: Calculator,
  finalApproval: Stamp,
  wax: Printer,
  casting: Flame,
  assembly: Wrench,
  setting: Gem,
  polishing: Sparkles,
  qc: ListChecks,
  certification: Award,
  dispatch: Truck,
  delivered: PackageCheck,
};

/** Typical hours per stage — used for the "Expected" hand-off when nothing was promised. */
const EXPECTED_HOURS: Record<StageKey, number> = {
  inquiry: 24,
  cad: 72,
  approval: 24,
  pricing: 24,
  finalApproval: 48,
  wax: 24,
  casting: 32,
  assembly: 48,
  setting: 48,
  polishing: 24,
  qc: 12,
  certification: 96,
  dispatch: 48,
  delivered: 0,
};

/** Partner roles that suit each stage (sorts the assign list). */
const ROLE_HINTS: Partial<Record<StageKey, string[]>> = {
  cad: ["CAD", "Designer"],
  approval: ["Retailer", "Designer"],
  finalApproval: ["Retailer"],
  casting: ["Casting"],
  setting: ["Setter"],
  assembly: ["Setter"],
  qc: ["QC"],
  certification: ["Lab"],
  dispatch: ["Courier"],
  delivered: ["Retailer"],
};

/** Shown in the sheet's fact grid, so left out of "What happened". */
const FACT_KEYS = new Set(["Assigned To", "Expected"]);

const STATUS_TONE: Record<StageStatus, Tone> = { done: "success", current: "accent", upcoming: "neutral", skipped: "warning" };

/** Who holds the stage: the completer for finished stages, else the assignee. */
function heldBy(job: Job, r: StageRecord) {
  const assigned = r.data["Assigned To"];
  if (r.status === "done" || r.status === "skipped") return r.by ?? assigned;
  if (r.status === "current") return assigned ?? job.assignee ?? undefined;
  return assigned;
}

const stamp = (iso: string) => (daysUntil(iso) === 0 ? time(iso) : relativeDay(iso));
const fileSrc = (f: ProjectFile) => f.dataUrl ?? f.asset ?? null;
const imgUrl = (src: string) => (src.startsWith("data:") || src.startsWith("/") ? src : `/images/${src}`);

const FILE_ICON: Record<FileKind, LucideIcon> = { image: ImageIcon, cad: Box, pdf: FileText, sheet: FileSpreadsheet, audio: FileMusic };

function kindOf(file: File): FileKind {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  if (file.type.startsWith("image/")) return "image";
  if (file.type.startsWith("audio/")) return "audio";
  if (ext === "pdf") return "pdf";
  if (["xls", "xlsx", "csv", "numbers"].includes(ext)) return "sheet";
  if (["stl", "step", "stp", "3dm", "obj", "iges", "igs"].includes(ext)) return "cad";
  return "pdf";
}

const sizeLabel = (bytes: number) =>
  bytes >= 1024 * 1024 ? `${(bytes / (1024 * 1024)).toFixed(1)} MB` : `${Math.max(1, Math.ceil(bytes / 1024))} KB`;

// ---------------------------------------------------------------------------

type Tab = "overview" | "process" | "thread" | "files";

type Dialog =
  | { kind: "edit" }
  | { kind: "delete" }
  | { kind: "complete" }
  | { kind: "change" }
  | { kind: "assign"; stage: StageKey }
  | { kind: "reopen"; stage: StageKey }
  | { kind: "file"; index: number }
  | { kind: "removeFile"; index: number }
  | { kind: "person"; person: Participant };

export function JobDetailView({ id }: { id: string }) {
  const job = useJob(id);
  const [gone, setGone] = useState(false);
  if (gone) return null;
  if (!job) {
    return (
      <Card className="mt-6">
        <EmptyState
          icon={<FolderOpen size={36} />}
          title={`Job ${id} not found`}
          message="It may have been deleted, or the link is wrong."
          action={
            <ButtonLink href="/jobs" variant="primary" icon={<ArrowLeft size={16} />}>
              Back to jobs
            </ButtonLink>
          }
        />
      </Card>
    );
  }
  return <JobDetail job={job} onDeleted={() => setGone(true)} />;
}

function JobDetail({ job, onDeleted }: { job: Job; onDeleted: () => void }) {
  const router = useRouter();
  const toast = useToast();
  const toggleRisk = useStore((s) => s.toggleRisk);
  const deleteJob = useStore((s) => s.deleteJob);
  const setStage = useStore((s) => s.setStage);
  const removeFile = useStore((s) => s.removeFile);
  const [tab, setTab] = useState<Tab>("overview");
  const [openStage, setOpenStage] = useState<StageKey | null>(null);
  const [dialog, setDialog] = useState<Dialog | null>(null);
  const records = useMemo(() => STAGES.map((s) => stageRecord(job, s.key)), [job]);
  const close = () => setDialog(null);

  const actions: StageActions = {
    open: setOpenStage,
    assign: (stage) => setDialog({ kind: "assign", stage }),
    complete: () => setDialog({ kind: "complete" }),
    change: () => setDialog({ kind: "change" }),
    reopen: (stage) => setDialog({ kind: "reopen", stage }),
    preview: (index) => setDialog({ kind: "file", index }),
    removeFile: (index) => setDialog({ kind: "removeFile", index }),
  };

  return (
    <>
      <Header
        job={job}
        onEdit={() => setDialog({ kind: "edit" })}
        onRisk={() => {
          toggleRisk(job.id);
          toast(job.atRisk ? `${job.id} no longer flagged` : `${job.id} flagged as at risk`);
        }}
        onDelete={() => setDialog({ kind: "delete" })}
      />
      <MetaGrid job={job} />
      <StageTimeline job={job} records={records} onOpen={setOpenStage} />

      <div className="mt-6">
        <Tabs
          tabs={[
            { value: "overview", label: "Overview" },
            { value: "process", label: "Process" },
            { value: "thread", label: "Thread", count: job.thread.length },
            { value: "files", label: "Files", count: job.files.length },
          ]}
          value={tab}
          onChange={setTab}
        />
      </div>

      <div className="mt-6">
        {tab === "overview" && (
          <Overview
            job={job}
            record={records[stageIndex(job.stage)]}
            actions={actions}
            onTab={setTab}
            onPerson={(person) => setDialog({ kind: "person", person })}
          />
        )}
        {tab === "process" && <ProcessList job={job} records={records} onOpen={setOpenStage} />}
        {tab === "thread" && (
          <Card className="overflow-hidden">
            <ThreadPanel job={job} listClass="h-[62vh] min-h-96" />
          </Card>
        )}
        {tab === "files" && <FilesPanel job={job} actions={actions} />}
      </div>

      {openStage && (
        <StageDrawer
          job={job}
          record={records[stageIndex(openStage)]}
          // A dialog opened from the drawer handles Esc / backdrop first.
          onClose={() => !dialog && setOpenStage(null)}
          actions={actions}
        />
      )}

      {dialog?.kind === "edit" && <EditJobDrawer job={job} onClose={close} />}
      {dialog?.kind === "complete" && <CompleteModal job={job} onClose={close} />}
      {dialog?.kind === "change" && <ChangeStageModal job={job} onClose={close} />}
      {dialog?.kind === "assign" && <AssignModal job={job} stage={dialog.stage} onClose={close} />}
      {dialog?.kind === "file" && job.files[dialog.index] && (
        <FilePreview
          file={job.files[dialog.index]}
          onClose={close}
          onDelete={() => setDialog({ kind: "removeFile", index: dialog.index })}
        />
      )}
      {dialog?.kind === "person" && <PersonModal person={dialog.person} onClose={close} />}

      <ConfirmModal
        open={dialog?.kind === "reopen"}
        onClose={close}
        title={dialog?.kind === "reopen" ? `Reopen ${stageInfo(dialog.stage).label}?` : ""}
        message={
          dialog?.kind === "reopen"
            ? `${job.id} moves back to ${stageInfo(dialog.stage).label}. Later stages keep what they recorded, and the move is logged in the thread.`
            : ""
        }
        confirmLabel="Reopen stage"
        onConfirm={() => {
          if (dialog?.kind !== "reopen") return;
          const label = stageInfo(dialog.stage).label;
          setStage(job.id, dialog.stage, { note: `${label} reopened from the admin panel.` });
          toast(`${job.id} moved back to ${label}`);
        }}
      />
      <ConfirmModal
        open={dialog?.kind === "removeFile"}
        onClose={close}
        danger
        title="Delete file?"
        message={dialog?.kind === "removeFile" ? `${job.files[dialog.index]?.name ?? "This file"} is removed from ${job.id}.` : ""}
        confirmLabel="Delete"
        onConfirm={() => {
          if (dialog?.kind !== "removeFile") return;
          const name = job.files[dialog.index]?.name;
          removeFile(job.id, dialog.index);
          toast(`${name} deleted`);
        }}
      />
      <ConfirmModal
        open={dialog?.kind === "delete"}
        onClose={close}
        danger
        title={`Delete ${job.id}?`}
        message={`“${job.title}” for ${job.customer} is removed with its stage records, thread and files. This can't be undone.`}
        confirmLabel="Delete job"
        onConfirm={() => {
          onDeleted();
          deleteJob(job.id);
          toast(`${job.id} deleted`);
          router.push("/jobs");
        }}
      />
    </>
  );
}

interface StageActions {
  open: (stage: StageKey) => void;
  assign: (stage: StageKey) => void;
  complete: () => void;
  change: () => void;
  reopen: (stage: StageKey) => void;
  preview: (index: number) => void;
  removeFile: (index: number) => void;
}

// ---------------------------------------------------------------------------
// Header, meta and timeline

function Header({ job, onEdit, onRisk, onDelete }: { job: Job; onEdit: () => void; onRisk: () => void; onDelete: () => void }) {
  const overdue = job.stage !== "delivered" && daysUntil(job.dueDate) < 0;
  return (
    <div className="mb-6">
      <Link href="/jobs" className="mb-4 inline-flex items-center gap-1.5 text-sm font-semibold text-fg-muted transition hover:text-fg">
        <ArrowLeft size={16} /> All jobs
      </Link>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <PriorityBadge priority={job.priority} />
            {job.atRisk && (
              <Badge tone="danger" dot>
                At risk
              </Badge>
            )}
            {overdue && <Badge tone="danger">Overdue</Badge>}
            <span className="ml-1 inline-flex items-center gap-2 font-mono text-xs text-fg-muted">
              <PulseDot /> Live Thread
            </span>
          </div>
          <h1 className="mt-2 font-mono text-4xl font-bold tracking-tight break-all sm:text-5xl">{job.id}</h1>
          <p className="mt-1 text-lg text-fg-muted">
            {job.productType} · <span className="text-fg">{job.title}</span>
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" icon={<Pencil size={16} />} onClick={onEdit}>
            Edit
          </Button>
          <Button variant="secondary" icon={<Flag size={16} className={cn(job.atRisk && "fill-danger text-danger")} />} onClick={onRisk}>
            {job.atRisk ? "Clear at-risk" : "Mark at risk"}
          </Button>
          <Button variant="danger" icon={<Trash2 size={16} />} onClick={onDelete}>
            Delete
          </Button>
        </div>
      </div>
    </div>
  );
}

function PulseDot() {
  return (
    <span className="relative flex size-2">
      <span className="absolute inset-0 animate-ping rounded-full bg-accent opacity-60" />
      <span className="relative size-2 rounded-full bg-accent" />
    </span>
  );
}

function MetaGrid({ job }: { job: Job }) {
  const dueSoonDays = useStore((s) => s.settings.dueSoonDays);
  const days = daysUntil(job.dueDate);
  const delivered = job.stage === "delivered";
  const tone: Tone = delivered ? "success" : days <= 0 ? "danger" : days <= dueSoonDays ? "warning" : "neutral";
  return (
    <Card className="grid grid-cols-2 gap-x-6 gap-y-5 p-5 lg:grid-cols-4 lg:p-6">
      <Meta label="Customer">{job.customer}</Meta>
      <Meta label="Manufacturer">{job.manufacturer}</Meta>
      <Meta label="Due Date">
        <span className={cn(!delivered && days <= 0 && "text-danger")}>{date(job.dueDate)}</span>
        <Badge tone={tone} className="ml-2 align-middle">
          {delivered ? "Delivered" : dueTag(days)}
        </Badge>
      </Meta>
      <Meta label="Value">
        <span className="font-mono">{money(job.value)}</span>
      </Meta>
    </Card>
  );
}

function Meta({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <div className="label-caps">{label}</div>
      <div className="mt-1.5 text-lg font-semibold break-words">{children}</div>
    </div>
  );
}

function StageTimeline({ job, records, onOpen }: { job: Job; records: StageRecord[]; onOpen: (s: StageKey) => void }) {
  const box = useRef<HTMLDivElement>(null);
  const current = useRef<HTMLButtonElement>(null);

  // Keep the current stage in view.
  useEffect(() => {
    const b = box.current;
    const c = current.current;
    if (b && c) b.scrollTo({ left: c.offsetLeft - b.clientWidth / 2 + c.clientWidth / 2, behavior: "smooth" });
  }, [job.stage]);

  return (
    <Card className="mt-4">
      <div
        ref={box}
        className="relative flex items-center overflow-x-auto px-4 py-4 [mask-image:linear-gradient(to_right,transparent,#000_28px,#000_calc(100%-28px),transparent)]"
      >
        {records.map((r, i) => {
          const s = stageInfo(r.stage);
          const reached = r.status !== "upcoming";
          return (
            <Fragment key={r.stage}>
              {i > 0 && <span className={cn("h-px w-5 shrink-0", reached ? "bg-fg" : "bg-border-strong")} />}
              <button
                ref={r.status === "current" ? current : undefined}
                type="button"
                onClick={() => onOpen(r.stage)}
                title={`${s.index + 1}. ${s.label} · ${STATUS_LABEL[r.status]}`}
                className="flex shrink-0 items-center gap-2 rounded-full p-1 pr-2.5 transition hover:bg-surface-high"
              >
                <TimelineNode status={r.status} />
                <span
                  className={cn(
                    "text-sm whitespace-nowrap",
                    r.status === "current" && "rounded-full bg-surface-high px-3 py-1 font-semibold text-fg",
                    r.status === "upcoming" && "text-fg-faint",
                    (r.status === "done" || r.status === "skipped") && "font-medium",
                  )}
                >
                  {s.short}
                </span>
              </button>
            </Fragment>
          );
        })}
      </div>
    </Card>
  );
}

function TimelineNode({ status }: { status: StageStatus }) {
  if (status === "done") {
    return (
      <span className="flex size-6 items-center justify-center rounded-full bg-action text-on-action">
        <Check size={14} strokeWidth={3} />
      </span>
    );
  }
  if (status === "skipped") {
    return (
      <span className="flex size-6 items-center justify-center rounded-full border border-dashed border-warning text-warning">
        <Minus size={12} strokeWidth={3} />
      </span>
    );
  }
  if (status === "current") {
    return (
      <span className="flex size-7 items-center justify-center rounded-full bg-accent ring-4 ring-accent/20">
        <span className="size-2.5 rounded-full bg-on-accent" />
      </span>
    );
  }
  return <span className="m-1 size-4 rounded-full border border-border-strong bg-surface-high" />;
}

function StatusPill({ status }: { status: StageStatus }) {
  return (
    <Badge tone={STATUS_TONE[status]} dot className="rounded-full px-2.5 py-1">
      {STATUS_LABEL[status]}
    </Badge>
  );
}

// ---------------------------------------------------------------------------
// Overview

function Overview({
  job,
  record,
  actions,
  onTab,
  onPerson,
}: {
  job: Job;
  record: StageRecord;
  actions: StageActions;
  onTab: (t: Tab) => void;
  onPerson: (p: Participant) => void;
}) {
  return (
    <div className="grid gap-6 xl:grid-cols-12">
      <div className="min-w-0 space-y-6 xl:col-span-8">
        <CurrentStageCard job={job} record={record} actions={actions} />
        <div className="grid items-start gap-6 md:grid-cols-2">
          <ProductCard job={job} />
          <NetworkHub job={job} onPerson={onPerson} />
        </div>
        <FilesPreview job={job} actions={actions} onViewAll={() => onTab("files")} />
      </div>
      <div className="min-w-0 xl:col-span-4">
        <Card className="overflow-hidden xl:sticky xl:top-24">
          <ThreadPanel job={job} limit={6} listClass="max-h-[560px]" onViewAll={() => onTab("thread")} />
        </Card>
      </div>
    </div>
  );
}

function CurrentStageCard({ job, record: r, actions }: { job: Job; record: StageRecord; actions: StageActions }) {
  const info = stageInfo(job.stage);
  const next = nextStage(job.stage);
  const Icon = STAGE_ICON[job.stage];
  const delivered = !next;
  const entered = job.stageEnteredAt ?? r.start;
  const promised = r.data.Expected;
  const allowedMs = EXPECTED_HOURS[job.stage] * 3_600_000;
  const late = !delivered && !promised && r.durationMs !== undefined && r.durationMs > allowedMs;
  const expected = promised ?? (entered ? relativeDay(new Date(Date.parse(entered) + allowedMs)) : "—");
  const holder = heldBy(job, r) ?? job.manufacturer;

  return (
    <Card className="relative overflow-hidden">
      <div className="pointer-events-none absolute -top-20 -right-20 size-64 rounded-full bg-accent/10 blur-3xl" />
      <div className="relative flex flex-col gap-6 p-6 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          <div className="label-caps">
            Stage {info.index + 1} of {STAGES.length} · {info.owner}
          </div>
          <h2 className="mt-2 flex items-center gap-2.5 text-2xl font-semibold tracking-tight">
            <Icon size={24} className="shrink-0 text-accent" />
            {delivered ? "Delivered to customer" : `${info.label} in progress`}
          </h2>
          <p className="mt-1 text-fg-muted">
            at <span className="text-lg font-semibold text-fg">{holder}</span>
          </p>
          <div className="mt-5 flex flex-wrap items-center gap-2">
            <TimeBox label="Received" value={entered ? relativeDay(entered) : "—"} />
            <ArrowRight size={18} className="hidden text-fg-faint sm:block" />
            <TimeBox label={delivered ? "Delivered" : "Expected"} value={delivered ? (entered ? dateLong(entered) : "—") : expected} tone={late ? "danger" : "accent"} />
          </div>
          <p className={cn("mt-3 text-sm", late ? "text-danger" : "text-fg-muted")}>
            {r.durationMs !== undefined && <span className="font-mono">{duration(r.durationMs)}</span>}
            {r.durationMs !== undefined && (delivered ? " since delivery" : " in this stage")}
            {late && ` — past the typical hand-off for ${info.label}.`}
          </p>
        </div>
        <div className="flex w-full shrink-0 flex-col gap-2 lg:w-56">
          {next && (
            <Button className="h-12" icon={<CheckCircle2 size={18} />} onClick={actions.complete}>
              Mark Complete
            </Button>
          )}
          <Button variant="secondary" icon={<ArrowRightLeft size={16} />} onClick={actions.change}>
            Change stage
          </Button>
          <Button variant="ghost" icon={<PanelRightOpen size={16} />} onClick={() => actions.open(job.stage)}>
            Stage details
          </Button>
          {next && <p className="text-center font-mono text-xs text-fg-faint">Next: {stageInfo(next).label}</p>}
        </div>
      </div>
    </Card>
  );
}

function TimeBox({ label, value, tone }: { label: string; value: string; tone?: "accent" | "danger" }) {
  return (
    <div className="rounded-lg bg-surface-low px-3 py-2">
      <div className="text-[10px] font-semibold tracking-wider text-fg-muted uppercase">{label}</div>
      <div className={cn("font-mono text-sm", tone === "accent" && "font-bold text-accent", tone === "danger" && "font-bold text-danger")}>{value}</div>
    </div>
  );
}

function ProductCard({ job }: { job: Job }) {
  const specs: [string, string][] = [
    ["Product", job.quantity > 1 ? `${job.productType} × ${job.quantity}` : job.productType],
    ["Material", job.metal],
    ...(job.centerStone && job.centerStone !== "—" ? [["Center Stone", job.centerStone] as [string, string]] : []),
    ...(job.settingStyle && job.settingStyle !== "—" ? [["Setting Style", job.settingStyle] as [string, string]] : []),
    ...(job.weightGrams ? [["Weight", `${job.weightGrams} g`] as [string, string]] : []),
    ...(job.ringSize ? [["Ring Size", job.ringSize] as [string, string]] : []),
  ];
  return (
    <Card className="min-w-0 overflow-hidden">
      <div className="relative h-56 bg-surface-high">
        {job.image ? (
          // eslint-disable-next-line @next/next/no-img-element -- data: URLs
          <img src={imgUrl(job.image)} alt={job.title} className="size-full object-cover" />
        ) : (
          <div className="flex size-full items-center justify-center text-fg-faint">
            <Gem size={40} strokeWidth={1.25} />
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/0 to-black/0" />
        <div className="absolute inset-x-4 bottom-3 flex items-end gap-2">
          <span className="min-w-0 flex-1 text-xl leading-tight font-semibold text-white">{job.title}</span>
          <span className="rounded-full border border-white/30 bg-white/20 px-2.5 py-0.5 font-mono text-xs text-white backdrop-blur">
            {job.productType}
          </span>
        </div>
      </div>
      <div className="space-y-2 p-4">
        {specs.map(([k, v]) => (
          <div key={k} className="flex items-center justify-between gap-3 rounded-lg bg-surface-low px-3.5 py-2.5">
            <span className="text-xs font-semibold text-fg-muted">{k}</span>
            <span className="text-right font-mono text-sm">{v}</span>
          </div>
        ))}
        {job.notes && <p className="border-l-2 border-accent pt-1 pl-3 text-sm text-fg-muted">{job.notes}</p>}
      </div>
    </Card>
  );
}

interface Participant {
  name: string;
  role: string;
  partner?: Partner;
  active?: boolean;
  style: "photo" | "dark" | "icon";
}

function useParticipants(job: Job): Participant[] {
  const partners = useStore((s) => s.partners);
  return useMemo(() => {
    const find = (name?: string | null) => (name ? partners.find((p) => p.name.toLowerCase() === name.toLowerCase()) : undefined);
    const out: Participant[] = [];
    const add = (p: Participant) => !out.some((o) => o.name === p.name) && out.push(p);
    if (job.assignee) {
      const p = find(job.assignee);
      add({ name: job.assignee, role: `${stageInfo(job.stage).label} (Active)`, partner: p, active: true, style: "photo" });
    }
    const customer = find(job.customer);
    add({ name: job.customer, role: customer?.role ?? "Client", partner: customer, style: "dark" });
    const cad = job.stageData.cad ?? {};
    const designerName = cad.Designer ?? cad["Assigned To"] ?? cad["Completed By"];
    const designer = find(designerName) ?? partners.find((p) => p.role.includes("Designer"));
    if (designerName || designer) add({ name: designerName ?? designer!.name, role: designer?.role ?? "CAD Designer", partner: designer, style: "photo" });
    const stones = partners.find((p) => p.role.includes("Stone"));
    add({ name: stones?.name ?? "GemSource", role: stones?.role ?? "Stone Provider", partner: stones, style: "icon" });
    return out;
  }, [job, partners]);
}

function ParticipantAvatar({ p, size = 40 }: { p: Participant; size?: number }) {
  if (p.style === "icon" && !p.partner?.avatar) {
    return (
      <span className="flex shrink-0 items-center justify-center rounded-full bg-surface-high text-fg" style={{ width: size, height: size }}>
        <Gem size={size * 0.45} />
      </span>
    );
  }
  return <Avatar name={p.name} src={p.partner?.avatar} size={size} dark={p.style === "dark"} />;
}

function NetworkHub({ job, onPerson }: { job: Job; onPerson: (p: Participant) => void }) {
  const people = useParticipants(job);
  return (
    <Card className="min-w-0">
      <CardHeader title="Network Hub" action={<Badge tone="accent">{people.length} Active</Badge>} />
      <div className="p-2">
        {people.map((p) => (
          <button
            key={p.name}
            type="button"
            onClick={() => onPerson(p)}
            className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left transition hover:bg-surface-low"
          >
            <ParticipantAvatar p={p} />
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold">{p.name}</div>
              <div className={cn("truncate font-mono text-[11px] tracking-wide uppercase", p.active ? "text-accent" : "text-fg-muted")}>{p.role}</div>
            </div>
            <ChevronRight size={16} className="text-fg-faint" />
          </button>
        ))}
      </div>
    </Card>
  );
}

function PersonModal({ person: p, onClose }: { person: Participant; onClose: () => void }) {
  const d = p.partner;
  const rows: [string, string][] = [
    ["Company", d?.company ?? "—"],
    ["Location", d?.location ?? "—"],
    ["Phone", d?.phone ?? "Not shared"],
    ["Email", d?.email ?? "Not shared"],
    ["Active jobs", d ? String(d.activeJobs) : "—"],
    ["Rating", d ? `★ ${d.rating.toFixed(1)}` : "—"],
  ];
  return (
    <Modal
      open
      onClose={onClose}
      size="sm"
      title={
        <span className="flex items-center gap-3">
          <ParticipantAvatar p={p} size={44} />
          <span className="min-w-0">
            <span className="block truncate">{p.name}</span>
            <span className={cn("block font-mono text-[11px] font-bold tracking-wide uppercase", p.active ? "text-accent" : "text-fg-muted")}>{p.role}</span>
          </span>
        </span>
      }
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Close
          </Button>
          <ButtonLink href="/partners" variant="primary">
            Open partners
          </ButtonLink>
        </>
      }
    >
      {d ? (
        <dl className="divide-y divide-border">
          {rows.map(([k, v]) => (
            <div key={k} className="flex justify-between gap-4 py-2.5 text-sm">
              <dt className="text-fg-muted">{k}</dt>
              <dd className="text-right font-medium">{v}</dd>
            </div>
          ))}
        </dl>
      ) : (
        <p className="text-sm text-fg-muted">{p.name} isn&apos;t in the partner directory yet. Add them on the Partners page to keep contact details.</p>
      )}
    </Modal>
  );
}

function FilesPreview({ job, actions, onViewAll }: { job: Job; actions: StageActions; onViewAll: () => void }) {
  return (
    <Card>
      <CardHeader
        title="Project Files"
        icon={<FolderOpen size={20} />}
        action={
          <button type="button" onClick={onViewAll} className="text-sm font-semibold text-accent hover:underline">
            View all ({job.files.length})
          </button>
        }
      />
      <div className="p-5">
        {job.files.length === 0 ? (
          <FilePicker jobId={job.id}>
            {(open) => (
              <button
                type="button"
                onClick={open}
                className="flex w-full flex-col items-center gap-1 rounded-xl border border-dashed border-border-strong bg-surface-low py-8 text-sm transition hover:border-accent"
              >
                <Upload size={20} className="text-fg-muted" />
                <span className="font-semibold">Upload the first file</span>
                <span className="text-xs text-fg-muted">Bench photos, references or QC shots</span>
              </button>
            )}
          </FilePicker>
        ) : (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            {job.files.slice(0, 4).map((f, i) => (
              <FileTile key={`${f.name}-${i}`} file={f} onOpen={() => actions.preview(i)} />
            ))}
          </div>
        )}
      </div>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// Process

function ProcessList({ job, records, onOpen }: { job: Job; records: StageRecord[]; onOpen: (s: StageKey) => void }) {
  const done = stageIndex(job.stage);
  return (
    <div className="grid gap-6 lg:grid-cols-12">
      <Card className="h-fit min-w-0 p-5 lg:sticky lg:top-24 lg:col-span-4">
        <div className="flex items-baseline justify-between gap-3">
          <h2 className="text-lg font-semibold">Lifecycle</h2>
          <span className="font-mono text-sm text-fg-muted">
            {done}/{STAGES.length - 1} done
          </span>
        </div>
        <ProgressBar value={jobProgress(job)} tone={job.stage === "delivered" ? "success" : "accent"} className="mt-3" />
        <p className="mt-3 text-sm text-fg-muted">
          Click any stage to see what happened in it — dates, who holds it, details, photos and messages.
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          {(["done", "current", "upcoming", "skipped"] as StageStatus[]).map((s) => (
            <span key={s} className="inline-flex items-center gap-1.5 text-xs text-fg-muted">
              <StatusIcon status={s} size={14} /> {STATUS_LABEL[s]}
            </span>
          ))}
        </div>
      </Card>
      <div className="min-w-0 space-y-2 lg:col-span-8">
        {records.map((r) => (
          <ProcessRow key={r.stage} job={job} record={r} onOpen={() => onOpen(r.stage)} />
        ))}
      </div>
    </div>
  );
}

function StatusIcon({ status, size = 20 }: { status: StageStatus; size?: number }) {
  if (status === "done") return <CheckCircle2 size={size} className="shrink-0 text-success" />;
  if (status === "current") return <CircleDot size={size} className="shrink-0 text-accent" />;
  if (status === "skipped") return <Minus size={size} className="shrink-0 text-warning" />;
  return <Circle size={size} className="shrink-0 text-fg-faint" />;
}

function ProcessRow({ job, record: r, onOpen }: { job: Job; record: StageRecord; onOpen: () => void }) {
  const s = stageInfo(r.stage);
  const Icon = STAGE_ICON[r.stage];
  const upcoming = r.status === "upcoming";
  const held = heldBy(job, r);
  const sub = (() => {
    switch (r.status) {
      case "done":
        return [r.end ? date(r.end) : r.start ? date(r.start) : null, held, r.durationMs !== undefined ? duration(r.durationMs) : null]
          .filter(Boolean)
          .join(" · ");
      case "current":
        return [`In progress${r.start ? ` since ${relativeDay(r.start)}` : ""}`, held].filter(Boolean).join(" · ");
      case "upcoming":
        return held ? `Assigned: ${held}${r.data.Expected ? ` · by ${r.data.Expected}` : ""}` : `Pending · ${s.owner}`;
      default:
        return "Skipped";
    }
  })();
  const preview = Object.entries(r.data)
    .filter(([k]) => !FACT_KEYS.has(k))
    .slice(0, 2)
    .map(([k, v]) => `${k}: ${v}`)
    .join("  •  ");

  return (
    <button
      type="button"
      onClick={onOpen}
      className={cn(
        "flex w-full items-center gap-3 rounded-xl border bg-surface p-3 text-left transition hover:border-border-strong hover:shadow-sm",
        r.status === "current" ? "border-accent ring-1 ring-accent/30" : "border-border",
      )}
    >
      <span
        className={cn("flex size-10 shrink-0 items-center justify-center rounded-lg", upcoming && "bg-surface-high text-fg-faint")}
        style={upcoming ? undefined : { background: `${s.color}24`, color: s.color }}
      >
        <Icon size={20} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2">
          <span className="font-mono text-xs text-fg-faint">{String(s.index + 1).padStart(2, "0")}</span>
          <span className={cn("truncate font-semibold", upcoming && "text-fg-faint")}>{s.label}</span>
          {r.status === "current" && <StatusPill status="current" />}
        </span>
        <span className="block truncate text-sm text-fg-muted">{sub}</span>
        {preview && <span className="block truncate font-mono text-xs text-fg-faint">{preview}</span>}
      </span>
      {r.status === "upcoming" ? <ChevronRight size={20} className="shrink-0 text-fg-faint" /> : <StatusIcon status={r.status} />}
    </button>
  );
}

// ---------------------------------------------------------------------------
// Stage drawer — the app's stage sheet

function StageDrawer({ job, record: r, onClose, actions }: { job: Job; record: StageRecord; onClose: () => void; actions: StageActions }) {
  const info = stageInfo(r.stage);
  const held = heldBy(job, r);
  const finished = r.status === "done" || r.status === "skipped";
  const hasNext = !!nextStage(r.stage);
  const fileIndex = (f: ProjectFile) => job.files.indexOf(f);

  const footer =
    r.status === "upcoming" ? (
      <Button icon={<UserPlus size={16} />} onClick={() => actions.assign(r.stage)} className="w-full sm:w-auto">
        {r.data["Assigned To"] ? "Reassign" : "Assign"} {info.short}
      </Button>
    ) : r.status === "current" ? (
      <>
        <Button variant="secondary" icon={<UserPlus size={16} />} onClick={() => actions.assign(r.stage)}>
          Assign
        </Button>
        {hasNext && (
          <Button icon={<CheckCircle2 size={16} />} onClick={actions.complete} className="flex-1 sm:flex-none">
            Mark {info.short} Complete
          </Button>
        )}
      </>
    ) : (
      <Button variant="secondary" icon={<RotateCcw size={16} />} onClick={() => actions.reopen(r.stage)}>
        Reopen stage
      </Button>
    );

  return (
    <Drawer
      open
      onClose={onClose}
      width={580}
      title={
        <span className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <span>
            {info.index + 1}. {info.label}
          </span>
          <StatusPill status={r.status} />
        </span>
      }
      subtitle={
        <span className="block truncate font-mono text-xs text-fg-faint">
          {job.id} · {job.title}
        </span>
      }
      footer={footer}
    >
      <div className="space-y-5">
        <div className="grid grid-cols-2 gap-x-4 gap-y-5">
          <Fact label="Received" value={r.start ? relativeDay(r.start) : "Not reached"} />
          {r.status === "done" ? (
            <Fact label="Completed" value={r.end ? relativeDay(r.end) : "—"} />
          ) : (
            <Fact label="Expected" value={r.data.Expected ?? "Not promised"} />
          )}
          <Fact label={finished ? "Time taken" : "Time in stage"} value={r.durationMs !== undefined ? duration(r.durationMs) : "—"} />
          <Fact label={finished ? "Completed by" : "Held by"} value={held ?? "Nobody yet"} icon={<User size={18} />} sans />
        </div>

        {r.note && <p className="rounded-lg border-l-[3px] border-accent bg-surface px-3 py-2.5 text-sm">{r.note}</p>}

        <p className="text-sm text-fg-muted">{info.summary}</p>

        <Section
          title={r.status === "current" ? "Recorded so far" : r.status === "upcoming" ? "Details" : "What happened"}
          count={Object.keys(r.data).filter((k) => !FACT_KEYS.has(k)).length}
        >
          <StageDetails job={job} stage={r.stage} data={r.data} />
        </Section>

        {(r.files.length > 0 || r.status === "current") && (
          <Section
            title="Photos & files"
            count={r.files.length}
            trailing={
              r.status === "current" && (
                <FilePicker jobId={job.id}>
                  {(open) => (
                    <button type="button" onClick={open} className="inline-flex items-center gap-1 text-xs font-semibold text-accent hover:underline">
                      <Upload size={13} /> Upload
                    </button>
                  )}
                </FilePicker>
              )
            }
          >
            {r.files.length ? (
              <div className="grid grid-cols-3 gap-3 pt-1 sm:grid-cols-4">
                {r.files.map((f, i) => (
                  <FileTile key={`${f.name}-${i}`} file={f} compact onOpen={() => actions.preview(fileIndex(f))} />
                ))}
              </div>
            ) : (
              <p className="py-2 text-sm text-fg-faint">No photos yet. Bench photos uploaded now land in this stage.</p>
            )}
          </Section>
        )}

        {r.activity.length > 0 && (
          <Section title="Activity" count={r.activity.length}>
            <ol className="pt-1">
              {r.activity.map((m, i) => (
                <li key={`${m.time}-${i}`} className="relative flex gap-3 pb-4 last:pb-1">
                  {i < r.activity.length - 1 && <span className="absolute top-4 bottom-0 left-[5px] w-px bg-border" />}
                  <span className={cn("mt-1.5 size-[11px] shrink-0 rounded-full border-2", m.kind === "stage" ? "border-accent bg-accent-soft" : "border-border-strong bg-surface")} />
                  <div className="min-w-0">
                    <div className="text-sm font-semibold">{m.title ?? m.author}</div>
                    <div className="font-mono text-[11px] text-fg-faint">
                      {m.title ? `${m.author} · ` : ""}
                      {relativeDay(m.time)}
                    </div>
                    <p className="mt-0.5 text-sm text-fg-muted">{m.text}</p>
                  </div>
                </li>
              ))}
            </ol>
          </Section>
        )}

        <Section title="Checklist" trailing={<span className="text-xs text-fg-faint">{info.owner}</span>}>
          <ul className="space-y-2 pt-1">
            {info.checklist.map((c) => (
              <li key={c} className="flex items-start gap-2.5 text-sm">
                {r.status === "done" ? (
                  <CheckCircle2 size={18} className="shrink-0 text-success" />
                ) : (
                  <Circle size={18} className="shrink-0 text-fg-faint" />
                )}
                <span className={cn(r.status === "done" && "text-fg-muted")}>{c}</span>
              </li>
            ))}
          </ul>
        </Section>
      </div>
    </Drawer>
  );
}

function Fact({ label, value, icon, sans }: { label: string; value: string; icon?: ReactNode; sans?: boolean }) {
  return (
    <div className="min-w-0">
      <div className="label-caps">{label}</div>
      <div className={cn("mt-1.5 flex items-center gap-2", sans ? "text-lg font-medium" : "font-mono text-base")}>
        {icon && <span className="text-fg-muted">{icon}</span>}
        <span className="min-w-0 break-words">{value}</span>
      </div>
    </div>
  );
}

function Section({ title, count, trailing, children }: { title: string; count?: number; trailing?: ReactNode; children: ReactNode }) {
  return (
    <section className="rounded-2xl border border-border bg-surface px-4 pt-3.5 pb-3">
      <div className="mb-1.5 flex items-center gap-2">
        <h3 className="label-caps flex-1">{title}</h3>
        {count !== undefined && <span className="font-mono text-xs text-fg-faint">{count}</span>}
        {trailing}
      </div>
      {children}
    </section>
  );
}

/** Key/value rows recorded for a stage, editable in place. */
function StageDetails({ job, stage, data }: { job: Job; stage: StageKey; data: Record<string, string> }) {
  const updateJob = useStore((s) => s.updateJob);
  const recordStage = useStore((s) => s.recordStage);
  const toast = useToast();
  const [editing, setEditing] = useState<{ key: string; k: string; v: string } | null>(null);
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState({ k: "", v: "" });
  const rows = Object.entries(data).filter(([k]) => !FACT_KEYS.has(k));

  const write = (next: Record<string, string>) => updateJob(job.id, { stageData: { ...job.stageData, [stage]: next } });

  const saveEdit = (e: FormEvent) => {
    e.preventDefault();
    if (!editing) return;
    const k = editing.k.trim();
    const v = editing.v.trim();
    if (!k || !v) return;
    const next: Record<string, string> = {};
    for (const [key, val] of Object.entries(data)) {
      if (key === editing.key) next[k] = v;
      else if (key !== k) next[key] = val;
    }
    write(next);
    setEditing(null);
  };

  const add = (e: FormEvent) => {
    e.preventDefault();
    const k = draft.k.trim();
    const v = draft.v.trim();
    if (!k || !v) return;
    recordStage(job.id, stage, { [k]: v });
    toast(`${k} recorded for ${stageInfo(stage).label}`);
    setDraft({ k: "", v: "" });
    setAdding(false);
  };

  return (
    <div>
      {rows.length === 0 && !adding && <p className="py-2 text-sm text-fg-faint">Nothing recorded yet.</p>}
      <div className="divide-y divide-border">
        {rows.map(([k, v]) =>
          editing?.key === k ? (
            <form key={k} onSubmit={saveEdit} className="grid gap-2 py-2.5 sm:grid-cols-[1fr_1.4fr_auto]">
              <Input value={editing.k} onChange={(e) => setEditing({ ...editing, k: e.target.value })} aria-label="Label" autoFocus />
              <Input value={editing.v} onChange={(e) => setEditing({ ...editing, v: e.target.value })} aria-label="Value" className="font-mono" />
              <div className="flex gap-1">
                <Button type="submit" size="sm" className="h-10">
                  Save
                </Button>
                <IconButton label="Cancel" onClick={() => setEditing(null)} className="size-10">
                  <X size={16} />
                </IconButton>
              </div>
            </form>
          ) : (
            <div key={k} className="group flex items-start gap-3 py-2.5">
              <span className="w-1/3 shrink-0 text-sm text-fg-muted">{k}</span>
              <span className="min-w-0 flex-1 text-right font-mono text-sm break-words">{v}</span>
              <span className="-my-0.5 flex shrink-0 gap-0.5 transition sm:opacity-0 sm:group-hover:opacity-100 sm:focus-within:opacity-100">
                <SmallIconButton label={`Edit ${k}`} onClick={() => setEditing({ key: k, k, v })}>
                  <Pencil size={13} />
                </SmallIconButton>
                <SmallIconButton
                  label={`Delete ${k}`}
                  onClick={() => {
                    write(Object.fromEntries(Object.entries(data).filter(([key]) => key !== k)));
                    toast(`${k} removed`);
                  }}
                >
                  <Trash2 size={13} />
                </SmallIconButton>
              </span>
            </div>
          ),
        )}
      </div>
      {adding ? (
        <form onSubmit={add} className="mt-2 grid gap-2 border-t border-border pt-3 sm:grid-cols-[1fr_1.4fr_auto]">
          <Input value={draft.k} onChange={(e) => setDraft({ ...draft, k: e.target.value })} placeholder="Label, e.g. Flask Temp" aria-label="Label" autoFocus />
          <Input value={draft.v} onChange={(e) => setDraft({ ...draft, v: e.target.value })} placeholder="Value" aria-label="Value" className="font-mono" />
          <div className="flex gap-1">
            <Button type="submit" size="sm" className="h-10" disabled={!draft.k.trim() || !draft.v.trim()}>
              Add
            </Button>
            <IconButton label="Cancel" onClick={() => setAdding(false)} className="size-10">
              <X size={16} />
            </IconButton>
          </div>
        </form>
      ) : (
        <button
          type="button"
          onClick={() => setAdding(true)}
          className="mt-1 inline-flex items-center gap-1.5 rounded-md py-1.5 text-sm font-semibold text-accent hover:underline"
        >
          <Plus size={15} /> Add detail
        </button>
      )}
    </div>
  );
}

function SmallIconButton({ label, onClick, children }: { label: string; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      className="inline-flex size-7 items-center justify-center rounded-md text-fg-muted transition hover:bg-surface-high hover:text-fg"
    >
      {children}
    </button>
  );
}

// ---------------------------------------------------------------------------
// Stage modals

function CompleteModal({ job, onClose }: { job: Job; onClose: () => void }) {
  const completeStage = useStore((s) => s.completeStage);
  const me = useStore((s) => s.session?.name ?? "Admin");
  const toast = useToast();
  const info = stageInfo(job.stage);
  const next = nextStage(job.stage);
  const [by, setBy] = useState(job.stageData[job.stage]?.["Assigned To"] ?? job.assignee ?? me);
  const [note, setNote] = useState("");
  if (!next) return null;

  const submit = (e: FormEvent) => {
    e.preventDefault();
    completeStage(job.id, { by: by.trim() || me, note: note.trim() || undefined });
    toast(`${job.id} moved to ${stageInfo(next).label}`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={`Complete ${info.label}`}
      subtitle={`${job.id} moves to ${stageInfo(next).label}. What you enter here is saved in the ${info.label} record.`}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="complete-stage" icon={<Check size={16} />}>
            Mark Complete
          </Button>
        </>
      }
    >
      <form id="complete-stage" onSubmit={submit} className="space-y-4">
        <Field label="Completed by">
          <Input value={by} onChange={(e) => setBy(e.target.value)} placeholder="Name / bench / vendor" autoFocus />
        </Field>
        <Field label="Notes">
          <Textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="What was done, any issues…" />
        </Field>
      </form>
    </Modal>
  );
}

function ChangeStageModal({ job, onClose }: { job: Job; onClose: () => void }) {
  const setStage = useStore((s) => s.setStage);
  const toast = useToast();
  const [to, setTo] = useState<StageKey>(job.stage);
  const [note, setNote] = useState("");
  const back = stageIndex(to) < stageIndex(job.stage);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (to === job.stage) return;
    setStage(job.id, to, { note: note.trim() || undefined });
    toast(`${job.id} moved to ${stageInfo(to).label}`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title="Change stage"
      subtitle={`Move ${job.id} to any stage. The move is logged in the thread.`}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="change-stage" disabled={to === job.stage}>
            Move to {stageInfo(to).short}
          </Button>
        </>
      }
    >
      <form id="change-stage" onSubmit={submit} className="space-y-4">
        <Field label="Stage">
          <Select value={to} onChange={(e) => setTo(e.target.value as StageKey)} autoFocus>
            {STAGES.map((s) => (
              <option key={s.key} value={s.key}>
                {s.index + 1}. {s.label}
                {s.key === job.stage ? " (current)" : ""}
              </option>
            ))}
          </Select>
        </Field>
        {back && <p className="rounded-lg bg-warning-soft px-3 py-2 text-sm text-warning">This moves the job backwards in the pipeline.</p>}
        <Field label="Note (optional)">
          <Textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Why the move? Shown in the thread." />
        </Field>
      </form>
    </Modal>
  );
}

function AssignModal({ job, stage, onClose }: { job: Job; stage: StageKey; onClose: () => void }) {
  const partners = useStore((s) => s.partners);
  const assignStage = useStore((s) => s.assignStage);
  const toast = useToast();
  const info = stageInfo(stage);
  const data = job.stageData[stage] ?? {};
  const hints = ROLE_HINTS[stage] ?? [];
  const fits = (p: Partner) => hints.some((h) => p.role.includes(h));
  const sorted = [...partners].sort((a, b) => Number(fits(b)) - Number(fits(a)));
  const promised = data.Expected ? new Date(data.Expected) : null;
  const [who, setWho] = useState(data["Assigned To"] ?? (stage === job.stage ? (job.assignee ?? "") : ""));
  const [expected, setExpected] = useState(promised && !isNaN(promised.getTime()) ? toDateInput(promised.toISOString()) : "");

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const name = who.trim();
    if (!name) return;
    assignStage(job.id, stage, name, expected ? fromDateInput(expected) : undefined);
    toast(`${name} assigned to ${info.label}`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={`Assign ${info.label}`}
      subtitle={`Choose who will hold this stage for ${job.id}.`}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="assign-stage" icon={<UserPlus size={16} />} disabled={!who.trim()}>
            Assign
          </Button>
        </>
      }
    >
      <form id="assign-stage" onSubmit={submit} className="space-y-4">
        <Field label="Partner" hint={hints.length ? `Partners marked ✓ match the ${info.label} role.` : undefined}>
          <Select value={sorted.some((p) => p.name === who) ? who : ""} onChange={(e) => setWho(e.target.value)}>
            <option value="">Choose a partner…</option>
            {sorted.map((p) => (
              <option key={p.id} value={p.name}>
                {fits(p) ? "✓ " : ""}
                {p.name} — {p.role} · {p.activeJobs} active
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Or type a name">
          <Input value={who} onChange={(e) => setWho(e.target.value)} placeholder="Name / bench / vendor" />
        </Field>
        <Field label="Expected by (optional)">
          <Input type="date" value={expected} onChange={(e) => setExpected(e.target.value)} className="font-mono" />
        </Field>
      </form>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Thread

function ThreadPanel({ job, limit, listClass, onViewAll }: { job: Job; limit?: number; listClass?: string; onViewAll?: () => void }) {
  const postMessage = useStore((s) => s.postMessage);
  const [text, setText] = useState("");
  const list = useRef<HTMLDivElement>(null);
  const msgs = limit ? job.thread.slice(-limit) : job.thread;

  useEffect(() => {
    const el = list.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [job.thread.length]);

  const send = () => {
    const t = text.trim();
    if (!t) return;
    postMessage(job.id, t);
    setText("");
  };

  return (
    <div className="flex flex-col">
      <div className="flex items-center gap-2 border-b border-border px-5 py-4">
        <MessagesSquare size={20} className="text-accent" />
        <h2 className="flex-1 text-base font-semibold">Digital Thread</h2>
        <span className="inline-flex items-center gap-1.5 rounded-full border border-border bg-surface-low px-2 py-0.5 text-xs text-fg-muted">
          <PulseDot /> Live
        </span>
        {onViewAll && job.thread.length > (limit ?? 0) && (
          <button type="button" onClick={onViewAll} className="ml-1 text-xs font-semibold text-accent hover:underline">
            All {job.thread.length}
          </button>
        )}
      </div>
      <div ref={list} className={cn("space-y-4 overflow-y-auto px-5 py-5", listClass)}>
        {msgs.length === 0 ? (
          <EmptyState icon={<MessagesSquare size={28} />} title="No updates yet" message="Post the first message for this job." />
        ) : (
          msgs.map((m, i) => <Message key={`${m.time}-${i}`} m={m} />)
        )}
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          send();
        }}
        className="flex items-end gap-2 border-t border-border bg-surface px-3 py-3"
      >
        <FilePicker jobId={job.id}>
          {(open) => (
            <IconButton label="Attach file" onClick={open} className="size-10 shrink-0">
              <Paperclip size={18} />
            </IconButton>
          )}
        </FilePicker>
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault();
              send();
            }
          }}
          rows={Math.min(4, text.split("\n").length)}
          placeholder="Type a message or update…"
          aria-label="Message"
          className="min-h-10 flex-1 resize-none rounded-2xl border border-transparent bg-surface-low px-4 py-2 text-sm leading-6 text-fg outline-none placeholder:text-fg-faint focus:border-accent"
        />
        <button
          type="submit"
          aria-label="Send"
          disabled={!text.trim()}
          className="flex size-10 shrink-0 items-center justify-center rounded-full bg-action text-on-action transition hover:opacity-90 disabled:opacity-40"
        >
          <Send size={17} />
        </button>
      </form>
    </div>
  );
}

function Message({ m }: { m: ThreadMessage }) {
  if (m.kind !== "message") {
    const Icon = m.kind === "file" ? Upload : m.kind === "stage" ? Play : CircleDot;
    return (
      <div className="flex gap-3">
        <span
          className={cn(
            "mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full",
            m.kind === "stage" ? "bg-accent-soft text-accent" : "bg-surface-high text-fg",
          )}
        >
          <Icon size={15} />
        </span>
        <div className="max-w-2xl min-w-0 flex-1 rounded-xl rounded-tl-sm border border-border bg-surface px-4 py-3">
          <div className="text-sm font-semibold">{m.title ?? m.author}</div>
          <p className="mt-0.5 text-sm text-fg-muted">{m.text}</p>
          <div className="mt-2 font-mono text-[11px] text-fg-faint">{stamp(m.time)}</div>
        </div>
      </div>
    );
  }
  if (m.isMe) {
    return (
      <div className="flex flex-col items-end pl-12">
        <span className="mb-1 text-xs font-semibold text-fg-muted">You</span>
        <p className="max-w-xl rounded-2xl rounded-tr-sm bg-action px-4 py-2.5 text-sm whitespace-pre-wrap text-on-action">{m.text}</p>
        <span className="mt-1 font-mono text-[11px] text-fg-faint">{stamp(m.time)}</span>
      </div>
    );
  }
  return (
    <div className="flex gap-3 pr-10">
      <Avatar name={m.author} src={m.avatar} size={32} />
      <div className="min-w-0">
        <span className="mb-1 block text-xs font-semibold text-fg-muted">{m.author}</span>
        <p className="max-w-xl rounded-2xl rounded-tl-sm bg-surface-high px-4 py-2.5 text-sm whitespace-pre-wrap">{m.text}</p>
        <span className="mt-1 block font-mono text-[11px] text-fg-faint">{stamp(m.time)}</span>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Files

/** Hidden file input + render prop to open it; uploads go straight onto the job. */
function FilePicker({ jobId, children }: { jobId: string; children: (open: () => void) => ReactNode }) {
  const addFile = useStore((s) => s.addFile);
  const toast = useToast();
  const [input, setInput] = useState<HTMLInputElement | null>(null);

  const upload = async (files: File[]) => {
    for (const f of files) {
      const kind = kindOf(f);
      try {
        const dataUrl = kind === "image" ? await readImage(f) : null;
        addFile(jobId, { name: f.name, kind, dataUrl, sizeLabel: sizeLabel(f.size) });
      } catch {
        toast(`Couldn't read ${f.name}`);
        return;
      }
    }
    if (files.length) toast(files.length === 1 ? `${files[0].name} uploaded` : `${files.length} files uploaded`);
  };

  return (
    <>
      {children(() => input?.click())}
      <input
        ref={setInput}
        type="file"
        multiple
        hidden
        onChange={(e) => {
          upload([...(e.target.files ?? [])]);
          e.target.value = "";
        }}
      />
    </>
  );
}

function FileThumb({ file, className, iconSize = 36 }: { file: ProjectFile; className?: string; iconSize?: number }) {
  const src = fileSrc(file);
  if (src) return <Thumb src={src} alt={file.name} className={className} />;
  const Icon = FILE_ICON[file.kind] ?? FileText;
  return (
    <div className={cn("flex items-center justify-center rounded-lg bg-surface-high text-fg-muted", className)}>
      <Icon size={iconSize} strokeWidth={1.5} />
    </div>
  );
}

function FileTile({ file, onOpen, onRemove, compact }: { file: ProjectFile; onOpen: () => void; onRemove?: () => void; compact?: boolean }) {
  return (
    <div className="group relative min-w-0">
      <button type="button" onClick={onOpen} className="block w-full rounded-lg ring-accent transition hover:ring-2" title={file.name}>
        <FileThumb file={file} className="aspect-square w-full" iconSize={compact ? 24 : 40} />
      </button>
      <div className={cn("mt-2 truncate font-mono", compact ? "text-[11px]" : "text-xs")}>{file.name}</div>
      {!compact && (
        <div className="truncate text-xs text-fg-faint">
          {file.sizeLabel} · {file.uploadedBy}
        </div>
      )}
      {onRemove && (
        <button
          type="button"
          aria-label={`Delete ${file.name}`}
          onClick={onRemove}
          className="absolute top-2 right-2 flex size-8 items-center justify-center rounded-lg bg-surface/90 text-fg-muted shadow transition hover:text-danger sm:opacity-0 sm:group-hover:opacity-100 sm:focus:opacity-100"
        >
          <Trash2 size={15} />
        </button>
      )}
    </div>
  );
}

function FilesPanel({ job, actions }: { job: Job; actions: StageActions }) {
  return (
    <Card>
      <CardHeader
        title={`Project Files (${job.files.length})`}
        subtitle="Bench photos, references, CAD and documents for this job."
        icon={<FolderOpen size={20} />}
        action={
          <FilePicker jobId={job.id}>
            {(open) => (
              <Button icon={<Upload size={16} />} onClick={open}>
                Upload
              </Button>
            )}
          </FilePicker>
        }
      />
      {job.files.length === 0 ? (
        <EmptyState
          icon={<FolderOpen size={32} />}
          title="No files yet"
          message="Upload bench photos, references or QC shots."
          action={
            <FilePicker jobId={job.id}>
              {(open) => (
                <Button variant="secondary" icon={<Upload size={16} />} onClick={open}>
                  Upload file
                </Button>
              )}
            </FilePicker>
          }
        />
      ) : (
        <div className="grid grid-cols-2 gap-x-4 gap-y-6 p-5 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
          {job.files.map((f, i) => (
            <FileTile key={`${f.name}-${i}`} file={f} onOpen={() => actions.preview(i)} onRemove={() => actions.removeFile(i)} />
          ))}
        </div>
      )}
    </Card>
  );
}

function FilePreview({ file, onClose, onDelete }: { file: ProjectFile; onClose: () => void; onDelete: () => void }) {
  const src = fileSrc(file);
  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={<span className="font-mono text-base break-all">{file.name}</span>}
      subtitle={`${file.sizeLabel} · ${file.uploadedBy} · ${relativeDay(file.date)}`}
      footer={
        <>
          <Button variant="danger" icon={<Trash2 size={16} />} onClick={onDelete} className="mr-auto">
            Delete
          </Button>
          {src && (
            <a
              href={imgUrl(src)}
              download={file.name}
              className="inline-flex h-10 items-center gap-2 rounded-lg border border-border-strong bg-surface px-4 text-sm font-semibold transition hover:bg-surface-low"
            >
              <Download size={16} /> Download
            </a>
          )}
          <Button onClick={onClose}>Close</Button>
        </>
      }
    >
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element -- data: URLs
        <img src={imgUrl(src)} alt={file.name} className="mx-auto max-h-[60vh] rounded-lg object-contain" />
      ) : (
        <div className="flex flex-col items-center gap-3 py-10 text-center">
          <FileThumb file={file} className="size-28" iconSize={48} />
          <p className="text-sm text-fg-muted">No preview for {file.kind.toUpperCase()} files in the panel.</p>
        </div>
      )}
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Edit job

function EditJobDrawer({ job, onClose }: { job: Job; onClose: () => void }) {
  const updateJob = useStore((s) => s.updateJob);
  const partners = useStore((s) => s.partners);
  const toast = useToast();
  const [f, setF] = useState(() => ({
    title: job.title,
    customer: job.customer,
    productType: job.productType,
    metal: job.metal,
    centerStone: job.centerStone === "—" ? "" : job.centerStone,
    settingStyle: job.settingStyle === "—" ? "" : job.settingStyle,
    weight: job.weightGrams ? String(job.weightGrams) : "",
    ringSize: job.ringSize ?? "",
    quantity: String(job.quantity),
    value: String(job.value),
    due: toDateInput(job.dueDate),
    priority: job.priority,
    assignee: job.assignee ?? "",
    notes: job.notes ?? "",
  }));
  const [tried, setTried] = useState(false);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((p) => ({ ...p, [k]: e.target.value }));

  const errors = {
    title: !f.title.trim() && "Required",
    customer: !f.customer.trim() && "Required",
    metal: !f.metal.trim() && "Required",
    value: !(Number(f.value) > 0) && "Must be above $0",
    due: !f.due && "Required",
  };
  const err = (k: keyof typeof errors) => (tried ? errors[k] || undefined : undefined);
  const invalid = (k: keyof typeof errors) => cn(err(k) && "ring-1 ring-danger");
  const types = PRODUCT_TYPES.includes(f.productType) ? PRODUCT_TYPES : [f.productType, ...PRODUCT_TYPES];

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (Object.values(errors).some(Boolean)) return;
    updateJob(job.id, {
      title: f.title.trim(),
      customer: f.customer.trim(),
      productType: f.productType,
      metal: f.metal.trim(),
      centerStone: f.centerStone.trim() || "—",
      settingStyle: f.settingStyle.trim() || "—",
      weightGrams: Number(f.weight) > 0 ? Number(f.weight) : null,
      ringSize: f.ringSize.trim() || null,
      quantity: Math.max(1, parseInt(f.quantity, 10) || 1),
      value: Number(f.value),
      dueDate: fromDateInput(f.due),
      priority: f.priority,
      assignee: f.assignee.trim() || null,
      notes: f.notes.trim() || null,
    });
    toast(`${job.id} updated`);
    onClose();
  };

  return (
    <Drawer
      open
      onClose={onClose}
      width={560}
      title={`Edit ${job.id}`}
      subtitle="Order details, specs and logistics."
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="edit-job" icon={<Check size={16} />}>
            Save changes
          </Button>
        </>
      }
    >
      <form id="edit-job" onSubmit={submit} noValidate className="grid gap-4 sm:grid-cols-2">
        <Field label="Piece name" className="sm:col-span-2">
          <Input value={f.title} onChange={set("title")} className={invalid("title")} />
          <FieldError msg={err("title")} />
        </Field>
        <Field label="Customer" className="sm:col-span-2">
          <Input value={f.customer} onChange={set("customer")} className={invalid("customer")} />
          <FieldError msg={err("customer")} />
        </Field>
        <Field label="Product type">
          <Select value={f.productType} onChange={set("productType")}>
            {types.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </Select>
        </Field>
        <Field label="Metal">
          <Input value={f.metal} onChange={set("metal")} list="edit-metals" className={invalid("metal")} />
          <datalist id="edit-metals">
            {METALS.map((m) => (
              <option key={m} value={m} />
            ))}
          </datalist>
          <FieldError msg={err("metal")} />
        </Field>
        <Field label="Center stone">
          <Input value={f.centerStone} onChange={set("centerStone")} placeholder="—" />
        </Field>
        <Field label="Setting style">
          <Input value={f.settingStyle} onChange={set("settingStyle")} placeholder="—" />
        </Field>
        <Field label="Weight (g)">
          <Input type="number" min={0} step={0.1} value={f.weight} onChange={set("weight")} className="font-mono" />
        </Field>
        <Field label="Ring size">
          <Input value={f.ringSize} onChange={set("ringSize")} list="edit-ring-sizes" placeholder={isRing(f.productType) ? "e.g. US 6.5" : "—"} />
          <datalist id="edit-ring-sizes">
            {RING_SIZES.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>
        </Field>
        <Field label="Quantity">
          <Input type="number" min={1} step={1} value={f.quantity} onChange={set("quantity")} className="font-mono" />
        </Field>
        <Field label="Value ($)">
          <Input type="number" min={0} step={50} value={f.value} onChange={set("value")} className={cn("font-mono", invalid("value"))} />
          <FieldError msg={err("value")} />
        </Field>
        <Field label="Due date">
          <Input type="date" value={f.due} onChange={set("due")} className={cn("font-mono", invalid("due"))} />
          <FieldError msg={err("due")} />
        </Field>
        <Field label="Assignee">
          <Input value={f.assignee} onChange={set("assignee")} list="edit-partners" placeholder="Current stage holder" />
          <datalist id="edit-partners">
            {partners.map((p) => (
              <option key={p.id} value={p.name} />
            ))}
          </datalist>
        </Field>
        <div className="sm:col-span-2">
          <span className="label-caps mb-1.5 block">Priority</span>
          <Segmented
            options={PRIORITY_OPTIONS}
            value={f.priority}
            onChange={(v) => setF((p) => ({ ...p, priority: v }))}
            className="w-full [&>button]:flex-1"
          />
        </div>
        <Field label="Notes" className="sm:col-span-2">
          <Textarea value={f.notes} onChange={set("notes")} placeholder="Instructions for the bench…" />
        </Field>
      </form>
    </Drawer>
  );
}

function FieldError({ msg }: { msg?: string | false }) {
  return msg ? <span className="mt-1 block text-xs font-semibold text-danger">{msg}</span> : null;
}
