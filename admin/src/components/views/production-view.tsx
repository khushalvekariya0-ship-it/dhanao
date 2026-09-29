"use client";

import { ArrowRightLeft, Clock, Inbox, ListFilter, Plus, TriangleAlert, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useMemo, useState, type DragEvent } from "react";

import { useToast } from "@/components/toast";
import {
  Avatar,
  Button,
  ButtonLink,
  Card,
  cn,
  PageHeader,
  PriorityBadge,
  priorityLabel,
  ProgressBar,
  Select,
  StageBadge,
  Thumb,
  Toggle,
} from "@/components/ui";
import { date, daysUntil } from "@/lib/format";
import { BOARD_COLUMNS, jobProgress, stageInfo } from "@/lib/stages";
import { useStore } from "@/lib/store";
import type { Job, Priority } from "@/lib/types";

type Column = (typeof BOARD_COLUMNS)[number];

const PRIORITIES: Priority[] = ["critical", "high", "rush", "standard"];
const DRAG_TYPE = "application/x-dhanaos-job";

const isActive = (j: Job) => j.stage !== "delivered";
const isAtRisk = (j: Job) => j.atRisk || daysUntil(j.dueDate) < 0;
const columnOf = (j: Job) => BOARD_COLUMNS.find((c) => c.stages.includes(j.stage));

interface Filters {
  priorities: Priority[];
  atRiskOnly: boolean;
  customer: string;
}
const NO_FILTERS: Filters = { priorities: [], atRiskOnly: false, customer: "" };

export function ProductionView() {
  const jobs = useStore((s) => s.jobs);
  const setStage = useStore((s) => s.setStage);
  const toast = useToast();

  const [filters, setFilters] = useState<Filters>(NO_FILTERS);
  const [showFilters, setShowFilters] = useState(false);
  const [dragId, setDragId] = useState<string | null>(null);
  const [overCol, setOverCol] = useState<string | null>(null);

  const customers = useMemo(() => [...new Set(jobs.map((j) => j.customer))].sort(), [jobs]);
  const filterCount = filters.priorities.length + (filters.atRiskOnly ? 1 : 0) + (filters.customer ? 1 : 0);

  const visible = useMemo(
    () =>
      jobs.filter(
        (j) =>
          (!filters.priorities.length || filters.priorities.includes(j.priority)) &&
          (!filters.atRiskOnly || isAtRisk(j)) &&
          (!filters.customer || j.customer === filters.customer),
      ),
    [jobs, filters],
  );

  const columns = useMemo(
    () =>
      BOARD_COLUMNS.map((col) => ({
        col,
        jobs: visible
          .filter((j) => col.stages.includes(j.stage))
          .sort((a, b) => Date.parse(a.dueDate) - Date.parse(b.dueDate)),
      })),
    [visible],
  );

  const active = jobs.filter(isActive);
  const atRisk = active.filter(isAtRisk).length;
  const dragFrom = dragId ? columnOf(jobs.find((j) => j.id === dragId)!)?.key : undefined;

  const moveTo = (id: string, col: Column) => {
    const job = jobs.find((j) => j.id === id);
    if (!job || col.stages.includes(job.stage)) return;
    setStage(job.id, col.entry, { note: `Moved on Production Floor to ${col.label}.` });
    toast(`${job.id} moved to ${col.label}`);
  };

  return (
    <>
      <PageHeader
        title="Production Floor"
        subtitle={
          <span className="flex flex-wrap items-center gap-2 pt-1">
            <span className="label-caps">Metrics:</span>
            <MetricChip dot="bg-accent">{active.length} Active</MetricChip>
            <MetricChip dot="bg-danger">{atRisk} At Risk</MetricChip>
            {filterCount > 0 && (
              <span className="text-sm text-fg-faint">
                Showing {visible.length} of {jobs.length}
              </span>
            )}
          </span>
        }
        actions={
          <>
            <Button
              variant={showFilters || filterCount ? "secondary" : "ghost"}
              icon={<ListFilter size={16} />}
              onClick={() => setShowFilters((v) => !v)}
              aria-expanded={showFilters}
              className={cn(!showFilters && !filterCount && "bg-surface-low")}
            >
              Filter
              {filterCount > 0 && (
                <span className="rounded-full bg-accent px-1.5 font-mono text-[11px] text-on-accent">{filterCount}</span>
              )}
            </Button>
            <ButtonLink href="/jobs/new" variant="primary" icon={<Plus size={16} />}>
              New Job
            </ButtonLink>
          </>
        }
      />

      {showFilters && (
        <FilterPanel
          filters={filters}
          customers={customers}
          onChange={setFilters}
          onClose={() => setShowFilters(false)}
        />
      )}

      <div className="-mx-4 overflow-x-auto px-4 pb-4 sm:-mx-6 sm:px-6 lg:-mx-10 lg:px-10">
        <div className="flex min-w-max gap-4 md:h-[calc(100vh-15rem)] md:min-h-[520px]">
          {columns.map(({ col, jobs: list }) => (
            <BoardColumn
              key={col.key}
              col={col}
              jobs={list}
              dragging={!!dragId}
              target={overCol === col.key && dragFrom !== col.key}
              onDragOver={(e) => {
                if (!dragId && !e.dataTransfer.types.includes(DRAG_TYPE)) return;
                e.preventDefault();
                e.dataTransfer.dropEffect = "move";
                if (overCol !== col.key) setOverCol(col.key);
              }}
              onDragLeave={(e) => {
                if (!e.currentTarget.contains(e.relatedTarget as Node | null)) {
                  setOverCol((c) => (c === col.key ? null : c));
                }
              }}
              onDrop={(e) => {
                e.preventDefault();
                const id = e.dataTransfer.getData(DRAG_TYPE) || dragId;
                setOverCol(null);
                setDragId(null);
                if (id) moveTo(id, col);
              }}
              onDragStart={setDragId}
              onDragEnd={() => {
                setDragId(null);
                setOverCol(null);
              }}
              draggingId={dragId}
              onMove={moveTo}
            />
          ))}
        </div>
      </div>
    </>
  );
}

function MetricChip({ dot, children }: { dot: string; children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-border bg-surface px-2.5 py-1 text-sm font-semibold text-fg">
      <span className={cn("size-2 rounded-full", dot)} />
      {children}
    </span>
  );
}

function FilterPanel({
  filters,
  customers,
  onChange,
  onClose,
}: {
  filters: Filters;
  customers: string[];
  onChange: (f: Filters) => void;
  onClose: () => void;
}) {
  const toggle = (p: Priority) =>
    onChange({
      ...filters,
      priorities: filters.priorities.includes(p) ? filters.priorities.filter((x) => x !== p) : [...filters.priorities, p],
    });
  return (
    <Card className="mb-5 flex flex-wrap items-end gap-x-8 gap-y-4 p-4">
      <div>
        <div className="label-caps mb-1.5">Priority</div>
        <div className="flex flex-wrap gap-1.5">
          {PRIORITIES.map((p) => {
            const on = filters.priorities.includes(p);
            return (
              <button
                key={p}
                type="button"
                aria-pressed={on}
                onClick={() => toggle(p)}
                className={cn(
                  "h-10 rounded-lg border px-3 text-sm font-semibold transition",
                  on
                    ? "border-accent bg-accent-soft text-accent"
                    : "border-border bg-surface text-fg-muted hover:border-border-strong hover:text-fg",
                )}
              >
                {priorityLabel(p)}
              </button>
            );
          })}
        </div>
      </div>
      <div>
        <div className="label-caps mb-1.5">At risk only</div>
        <div className="flex h-10 items-center">
          <Toggle
            checked={filters.atRiskOnly}
            onChange={(v) => onChange({ ...filters, atRiskOnly: v })}
            label="Show at-risk jobs only"
          />
        </div>
      </div>
      <label className="block min-w-52">
        <span className="label-caps mb-1.5 block">Customer</span>
        <Select value={filters.customer} onChange={(e) => onChange({ ...filters, customer: e.target.value })}>
          <option value="">All customers</option>
          {customers.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </Select>
      </label>
      <div className="ml-auto flex gap-2">
        <Button variant="ghost" size="sm" onClick={() => onChange(NO_FILTERS)} disabled={!filters.priorities.length && !filters.atRiskOnly && !filters.customer}>
          Clear
        </Button>
        <Button variant="secondary" size="sm" icon={<X size={14} />} onClick={onClose}>
          Close
        </Button>
      </div>
    </Card>
  );
}

function BoardColumn({
  col,
  jobs,
  dragging,
  target,
  draggingId,
  onDragOver,
  onDragLeave,
  onDrop,
  onDragStart,
  onDragEnd,
  onMove,
}: {
  col: Column;
  jobs: Job[];
  dragging: boolean;
  target: boolean;
  draggingId: string | null;
  onDragOver: (e: DragEvent<HTMLElement>) => void;
  onDragLeave: (e: DragEvent<HTMLElement>) => void;
  onDrop: (e: DragEvent<HTMLElement>) => void;
  onDragStart: (id: string) => void;
  onDragEnd: () => void;
  onMove: (id: string, col: Column) => void;
}) {
  const color = stageInfo(col.entry).color;
  return (
    <section
      aria-label={`${col.label} column`}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onDrop={onDrop}
      className={cn(
        "flex w-[296px] shrink-0 flex-col rounded-xl border transition md:h-full",
        target ? "border-accent bg-accent-soft/40 ring-2 ring-accent/30" : "border-border bg-surface-low",
        !jobs.length && !dragging && "opacity-75",
      )}
    >
      <header className="flex items-center gap-2 border-b border-border px-4 py-3.5">
        <span className="size-2.5 rounded-full" style={{ background: color }} />
        <h2 className="font-semibold">{col.label}</h2>
        <span className="rounded-full bg-surface-high px-2 py-0.5 font-mono text-xs font-semibold text-fg-muted">
          {jobs.length}
        </span>
      </header>
      <div className="flex min-h-40 flex-1 flex-col gap-3 overflow-y-auto p-3">
        {jobs.map((j) => (
          <JobCard
            key={j.id}
            job={j}
            col={col}
            dragging={draggingId === j.id}
            onDragStart={onDragStart}
            onDragEnd={onDragEnd}
            onMove={onMove}
          />
        ))}
        {!jobs.length && (
          <div
            className={cn(
              "flex flex-1 flex-col items-center justify-center rounded-lg py-10 text-center text-fg-faint",
              target && "border-2 border-dashed border-accent/50 text-accent",
            )}
          >
            <Inbox size={28} className="mb-2 opacity-60" />
            <p className="text-sm">Drop jobs here</p>
          </div>
        )}
      </div>
    </section>
  );
}

function JobCard({
  job: j,
  col,
  dragging,
  onDragStart,
  onDragEnd,
  onMove,
}: {
  job: Job;
  col: Column;
  dragging: boolean;
  onDragStart: (id: string) => void;
  onDragEnd: () => void;
  onMove: (id: string, col: Column) => void;
}) {
  const router = useRouter();
  const partners = useStore((s) => s.partners);
  const dueSoonDays = useStore((s) => s.settings.dueSoonDays);
  const due = daysUntil(j.dueDate);
  const inStage = j.stageEnteredAt ? Math.max(0, -daysUntil(j.stageEnteredAt)) : 0;
  const risk = isAtRisk(j);
  const open = () => router.push(`/jobs/${j.id}`);
  const avatar = j.assignee ? partners.find((p) => p.name === j.assignee)?.avatar : null;
  const dueTone = !isActive(j) ? "text-fg-faint" : due < 0 ? "text-danger" : due <= dueSoonDays ? "text-warning" : "text-fg-muted";

  return (
    <article
      role="link"
      tabIndex={0}
      aria-label={`${j.id} ${j.title}`}
      draggable
      onDragStart={(e) => {
        e.dataTransfer.setData(DRAG_TYPE, j.id);
        e.dataTransfer.setData("text/plain", j.id);
        e.dataTransfer.effectAllowed = "move";
        onDragStart(j.id);
      }}
      onDragEnd={onDragEnd}
      onClick={open}
      onKeyDown={(e) => e.key === "Enter" && e.target === e.currentTarget && open()}
      className={cn(
        "group relative flex cursor-grab flex-col gap-3 rounded-lg border border-l-2 bg-surface p-3 shadow-sm transition select-none hover:shadow-md active:cursor-grabbing",
        risk ? "border-border border-l-danger" : "border-border border-l-transparent hover:border-l-accent",
        "focus-visible:ring-2 focus-visible:ring-accent/40 focus-visible:outline-none",
        dragging && "scale-[0.97] opacity-50 ring-2 ring-accent",
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <span className="font-mono text-[13px] text-fg-muted">#{j.id}</span>
        <div className="flex items-center gap-1.5">
          {risk && (
            <span title={j.atRisk ? "Flagged at risk" : "Overdue"} className="text-danger">
              <TriangleAlert size={14} />
            </span>
          )}
          {j.priority !== "standard" && <PriorityBadge priority={j.priority} />}
        </div>
      </div>

      <div className="flex gap-3">
        <div className="pointer-events-none shrink-0">
          <Thumb src={j.image} alt={j.title} className="size-12" />
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-semibold">{j.title}</h3>
          <p className="truncate text-[13px] text-fg-muted">Client: {j.customer}</p>
        </div>
      </div>

      <ProgressBar value={jobProgress(j)} tone={risk ? "danger" : "accent"} className="h-1" />

      <div className="flex items-center justify-between gap-2">
        <StageBadge stage={j.stage} />
        <span className="text-xs text-fg-muted">{inStage}d in stage</span>
      </div>

      <div className="flex items-center justify-between gap-2 border-t border-border pt-2.5">
        <span className={cn("flex items-center gap-1 text-xs font-medium", dueTone)}>
          <Clock size={13} />
          Due: {date(j.dueDate)}
          {isActive(j) && <span className="font-mono">({due < 0 ? `${-due}d late` : `${due}d`})</span>}
        </span>
        <div className="flex items-center gap-1">
          <MoveMenu col={col} onMove={(c) => onMove(j.id, c)} />
          {j.assignee && (
            <span title={j.assignee}>
              <Avatar name={j.assignee} src={avatar} size={24} />
            </span>
          )}
        </div>
      </div>
    </article>
  );
}

/** Keyboard/touch alternative to dragging: a native select behind an icon. */
function MoveMenu({ col, onMove }: { col: Column; onMove: (c: Column) => void }) {
  return (
    <label
      title="Move to…"
      onClick={(e) => e.stopPropagation()}
      className="relative inline-flex size-7 items-center justify-center rounded-md text-fg-faint transition group-hover:text-fg-muted hover:bg-surface-high hover:text-fg focus-within:ring-2 focus-within:ring-accent/40"
    >
      <ArrowRightLeft size={14} />
      <select
        aria-label="Move to column"
        value=""
        onChange={(e) => {
          const c = BOARD_COLUMNS.find((x) => x.key === e.target.value);
          if (c) onMove(c);
        }}
        className="absolute inset-0 cursor-pointer opacity-0"
      >
        <option value="" disabled>
          Move to…
        </option>
        {BOARD_COLUMNS.map((c) => (
          <option key={c.key} value={c.key} disabled={c.key === col.key}>
            {c.label}
          </option>
        ))}
      </select>
    </label>
  );
}
