"use client";

import { ArrowUpRight, Briefcase, Flag, Plus, Search, Trash2, X } from "lucide-react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo, useState, type MouseEvent } from "react";

import { useToast } from "@/components/toast";
import {
  Button,
  ButtonLink,
  Card,
  ConfirmModal,
  EmptyState,
  IconButton,
  Input,
  PageHeader,
  PriorityBadge,
  ProgressBar,
  Select,
  StageBadge,
  Table,
  Tabs,
  TD,
  TH,
  Thumb,
  cn,
  priorityLabel,
} from "@/components/ui";
import { date, daysUntil, dueTag, money } from "@/lib/format";
import { useStore } from "@/lib/store";
import { STAGES, jobProgress, stageIndex, stageInfo } from "@/lib/stages";
import type { Job, Priority, StageKey } from "@/lib/types";

const FILTERS = ["all", "active", "atRisk", "dueSoon", "completed"] as const;
type Filter = (typeof FILTERS)[number];

const FILTER_LABEL: Record<Filter, string> = {
  all: "All",
  active: "Active",
  atRisk: "At Risk",
  dueSoon: "Due Soon",
  completed: "Completed",
};

type Sort = "due" | "value" | "stage" | "newest";
const PRIORITIES: Priority[] = ["standard", "high", "rush", "critical"];

const isDone = (j: Job) => j.stage === "delivered";
const createdAt = (j: Job) => Date.parse(j.history[0]?.at ?? j.stageEnteredAt ?? j.dueDate);

function matches(j: Job, f: Filter, dueSoonDays: number) {
  switch (f) {
    case "active":
      return !isDone(j);
    case "atRisk":
      // Same as the dashboard KPI: flagged or overdue.
      return !isDone(j) && (j.atRisk || daysUntil(j.dueDate) < 0);
    case "dueSoon":
      return !isDone(j) && daysUntil(j.dueDate) <= dueSoonDays;
    case "completed":
      return isDone(j);
    default:
      return true;
  }
}

const SORTS: Record<Sort, (a: Job, b: Job) => number> = {
  due: (a, b) => Number(isDone(a)) - Number(isDone(b)) || Date.parse(a.dueDate) - Date.parse(b.dueDate),
  value: (a, b) => b.value - a.value,
  stage: (a, b) => stageIndex(b.stage) - stageIndex(a.stage),
  newest: (a, b) => createdAt(b) - createdAt(a),
};

export function JobsView() {
  return (
    <Suspense fallback={<PageHeader title="Jobs" />}>
      <JobsList />
    </Suspense>
  );
}

function JobsList() {
  const router = useRouter();
  const params = useSearchParams();
  const toast = useToast();
  const jobs = useStore((s) => s.jobs);
  const dueSoonDays = useStore((s) => s.settings.dueSoonDays);
  const toggleRisk = useStore((s) => s.toggleRisk);
  const deleteJob = useStore((s) => s.deleteJob);
  const setStage = useStore((s) => s.setStage);

  const raw = params.get("filter");
  const filter: Filter = FILTERS.includes(raw as Filter) ? (raw as Filter) : "all";
  const [q, setQ] = useState("");
  const [stage, setStageFilter] = useState<StageKey | "all">("all");
  const [priority, setPriority] = useState<Priority | "all">("all");
  const [sort, setSort] = useState<Sort>("due");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkStage, setBulkStage] = useState<StageKey | "">("");
  const [confirm, setConfirm] = useState<{ ids: string[] } | null>(null);

  // The URL is the source of truth for the filter so dashboard links and reloads keep it.
  const setFilter = (f: Filter) => window.history.replaceState(null, "", f === "all" ? "/jobs" : `/jobs?filter=${f}`);

  const counts = useMemo(
    () => Object.fromEntries(FILTERS.map((f) => [f, jobs.filter((j) => matches(j, f, dueSoonDays)).length])) as Record<Filter, number>,
    [jobs, dueSoonDays],
  );

  const rows = useMemo(() => {
    const t = q.trim().toLowerCase();
    return jobs
      .filter((j) => matches(j, filter, dueSoonDays))
      .filter((j) => stage === "all" || j.stage === stage)
      .filter((j) => priority === "all" || j.priority === priority)
      .filter((j) => !t || [j.id, j.title, j.customer, j.assignee ?? ""].some((v) => v.toLowerCase().includes(t)))
      .sort(SORTS[sort]);
  }, [jobs, filter, dueSoonDays, stage, priority, q, sort]);

  const picked = rows.filter((j) => selected.has(j.id));
  const allPicked = rows.length > 0 && picked.length === rows.length;
  const hasFilters = !!q || stage !== "all" || priority !== "all" || filter !== "all";

  const toggle = (id: string) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });
  const toggleAll = () => setSelected(allPicked ? new Set() : new Set(rows.map((j) => j.id)));
  const clearFilters = () => {
    setQ("");
    setStageFilter("all");
    setPriority("all");
    setFilter("all");
  };

  const moveSelected = () => {
    if (!bulkStage) return;
    const moving = picked.filter((j) => j.stage !== bulkStage);
    moving.forEach((j) => setStage(j.id, bulkStage, { note: `Moved to ${stageInfo(bulkStage).label} from the admin panel.` }));
    toast(`${moving.length} job${moving.length === 1 ? "" : "s"} moved to ${stageInfo(bulkStage).label}`);
    setBulkStage("");
    setSelected(new Set());
  };

  const remove = (ids: string[]) => {
    ids.forEach(deleteJob);
    setSelected((s) => new Set([...s].filter((id) => !ids.includes(id))));
    toast(ids.length === 1 ? `${ids[0]} deleted` : `${ids.length} jobs deleted`);
  };

  const stop = (e: MouseEvent) => e.stopPropagation();

  return (
    <>
      <PageHeader
        eyebrow="Production"
        title={
          <>
            Jobs <span className="font-mono text-xl font-normal text-fg-faint">{jobs.length}</span>
          </>
        }
        subtitle="Every job order across the 14-stage pipeline."
        actions={
          <ButtonLink href="/jobs/new" variant="primary" icon={<Plus size={17} />}>
            New Job
          </ButtonLink>
        }
      />

      <Card className="overflow-hidden">
        <div className="px-2 pt-1">
          <Tabs
            tabs={FILTERS.map((f) => ({ value: f, label: FILTER_LABEL[f], count: counts[f] }))}
            value={filter}
            onChange={setFilter}
          />
        </div>

        <div className="flex flex-wrap items-center gap-2 border-b border-border px-4 py-3">
          <div className="relative min-w-0 basis-full sm:flex-1 sm:basis-auto">
            <Search size={16} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
            <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search ID, piece, customer or assignee" className="pl-9" />
          </div>
          <Select
            aria-label="Stage"
            value={stage}
            onChange={(e) => setStageFilter(e.target.value as StageKey | "all")}
            className="min-w-36 flex-1 sm:w-48 sm:flex-none"
          >
            <option value="all">All stages</option>
            {STAGES.map((s) => (
              <option key={s.key} value={s.key}>
                {s.index + 1}. {s.label}
              </option>
            ))}
          </Select>
          <Select
            aria-label="Priority"
            value={priority}
            onChange={(e) => setPriority(e.target.value as Priority | "all")}
            className="min-w-36 flex-1 sm:w-40 sm:flex-none"
          >
            <option value="all">All priorities</option>
            {PRIORITIES.map((p) => (
              <option key={p} value={p}>
                {priorityLabel(p)}
              </option>
            ))}
          </Select>
          <Select
            aria-label="Sort"
            value={sort}
            onChange={(e) => setSort(e.target.value as Sort)}
            className="min-w-36 flex-1 sm:w-40 sm:flex-none"
          >
            <option value="due">Sort: Due date</option>
            <option value="value">Sort: Value</option>
            <option value="stage">Sort: Stage</option>
            <option value="newest">Sort: Newest</option>
          </Select>
        </div>

        {picked.length > 0 && (
          <div className="flex flex-wrap items-center gap-2 border-b border-border bg-accent-soft/60 px-4 py-2.5">
            <span className="mr-2 text-sm font-semibold">
              <span className="font-mono">{picked.length}</span> selected
            </span>
            <Select
              aria-label="Move to stage"
              value={bulkStage}
              onChange={(e) => setBulkStage(e.target.value as StageKey | "")}
              className="min-w-0 flex-1 sm:w-56 sm:flex-none"
            >
              <option value="">Move to stage…</option>
              {STAGES.map((s) => (
                <option key={s.key} value={s.key}>
                  {s.index + 1}. {s.label}
                </option>
              ))}
            </Select>
            <Button disabled={!bulkStage} onClick={moveSelected}>
              Apply
            </Button>
            <Button variant="danger" icon={<Trash2 size={15} />} onClick={() => setConfirm({ ids: picked.map((j) => j.id) })}>
              Delete
            </Button>
            <Button variant="ghost" icon={<X size={15} />} className="ml-auto" onClick={() => setSelected(new Set())}>
              Clear
            </Button>
          </div>
        )}

        {rows.length === 0 ? (
          <EmptyState
            icon={<Briefcase size={32} />}
            title={jobs.length ? "No jobs match these filters" : "No jobs yet"}
            message={jobs.length ? "Try a different search, stage or priority." : "Create the first job order to start tracking it through production."}
            action={
              jobs.length && hasFilters ? (
                <Button variant="secondary" onClick={clearFilters}>
                  Clear filters
                </Button>
              ) : (
                <ButtonLink href="/jobs/new" variant="primary" icon={<Plus size={17} />}>
                  New Job
                </ButtonLink>
              )
            }
          />
        ) : (
          <Table>
            <thead>
              <tr>
                <TH>
                  <span className="flex items-center gap-4">
                    <Checkbox checked={allPicked} indeterminate={picked.length > 0 && !allPicked} onChange={toggleAll} label="Select all" />
                    Job
                  </span>
                </TH>
                <TH>Customer</TH>
                <TH>Stage</TH>
                <TH>Priority</TH>
                <TH>Due</TH>
                <TH className="text-right">Value</TH>
                <TH>Assignee</TH>
                <TH className="text-right">Actions</TH>
              </tr>
            </thead>
            <tbody>
              {rows.map((j) => {
                const days = daysUntil(j.dueDate);
                const late = !isDone(j) && days <= 0;
                const on = selected.has(j.id);
                return (
                  <tr
                    key={j.id}
                    onClick={() => router.push(`/jobs/${j.id}`)}
                    className={cn("cursor-pointer transition hover:bg-surface-low", on && "bg-accent-soft/40")}
                  >
                    <TD>
                      <div className="flex items-center gap-3">
                        <span onClick={stop} className="-my-3 -ml-4 flex self-stretch items-center py-3 pr-1 pl-4">
                          <Checkbox checked={on} onChange={() => toggle(j.id)} label={`Select ${j.id}`} />
                        </span>
                        <Thumb src={j.image} alt={j.title} className="size-11 shrink-0" />
                        <div className="min-w-40">
                          <Link href={`/jobs/${j.id}`} onClick={stop} className="font-semibold hover:text-accent">
                            {j.title}
                          </Link>
                          {j.atRisk && <Flag size={13} className="ml-1.5 inline fill-danger align-[-1px] text-danger" aria-label="At risk" />}
                          <div className="font-mono text-xs text-fg-faint">{j.id}</div>
                        </div>
                      </div>
                    </TD>
                    <TD className="min-w-32 text-fg-muted">{j.customer}</TD>
                    <TD>
                      <div className="w-28">
                        <StageBadge stage={j.stage} />
                        <ProgressBar value={jobProgress(j)} tone={isDone(j) ? "success" : "accent"} className="mt-2" />
                      </div>
                    </TD>
                    <TD>
                      <PriorityBadge priority={j.priority} />
                    </TD>
                    <TD className="whitespace-nowrap">
                      <div className={cn("font-semibold", late && "text-danger")}>{date(j.dueDate)}</div>
                      <div className={cn("font-mono text-[10px] tracking-wider", late ? "text-danger" : "text-fg-faint")}>
                        {isDone(j) ? "DELIVERED" : dueTag(days)}
                      </div>
                    </TD>
                    <TD className="text-right font-mono whitespace-nowrap">{money(j.value)}</TD>
                    <TD className="min-w-28 text-fg-muted">{j.assignee ?? <span className="text-fg-faint">—</span>}</TD>
                    <TD className="text-right whitespace-nowrap">
                      <span onClick={stop} className="inline-flex gap-0.5">
                        <IconButton label="Open job" onClick={() => router.push(`/jobs/${j.id}`)}>
                          <ArrowUpRight size={17} />
                        </IconButton>
                        <IconButton
                          label={j.atRisk ? "Clear at-risk flag" : "Mark at risk"}
                          onClick={() => {
                            toggleRisk(j.id);
                            toast(j.atRisk ? `${j.id} no longer flagged` : `${j.id} flagged as at risk`);
                          }}
                        >
                          <Flag size={16} className={cn(j.atRisk && "fill-danger text-danger")} />
                        </IconButton>
                        <IconButton label="Delete job" onClick={() => setConfirm({ ids: [j.id] })} className="group">
                          <Trash2 size={16} className="group-hover:text-danger" />
                        </IconButton>
                      </span>
                    </TD>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        )}
        {rows.length > 0 && (
          <div className="flex items-center justify-between px-4 py-3 text-xs text-fg-faint">
            <span>
              Showing <span className="font-mono">{rows.length}</span> of <span className="font-mono">{jobs.length}</span> jobs
            </span>
            {hasFilters && (
              <button type="button" onClick={clearFilters} className="font-semibold text-accent hover:underline">
                Clear filters
              </button>
            )}
          </div>
        )}
      </Card>

      <ConfirmModal
        open={!!confirm}
        onClose={() => setConfirm(null)}
        onConfirm={() => confirm && remove(confirm.ids)}
        danger
        confirmLabel="Delete"
        title={confirm?.ids.length === 1 ? `Delete ${confirm.ids[0]}?` : `Delete ${confirm?.ids.length ?? 0} jobs?`}
        message="The job, its stage records, thread and files are removed from the panel. This can't be undone."
      />
    </>
  );
}

function Checkbox({
  checked,
  indeterminate,
  onChange,
  label,
}: {
  checked: boolean;
  indeterminate?: boolean;
  onChange: () => void;
  label: string;
}) {
  return (
    <input
      type="checkbox"
      aria-label={label}
      checked={checked}
      ref={(el) => {
        if (el) el.indeterminate = !!indeterminate;
      }}
      onChange={onChange}
      className="size-4 cursor-pointer align-middle accent-accent"
    />
  );
}
