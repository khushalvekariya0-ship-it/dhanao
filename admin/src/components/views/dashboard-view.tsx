"use client";

import {
  Activity,
  BadgeCheck,
  Banknote,
  CalendarClock,
  ChartBar,
  CircleAlert,
  CircleCheck,
  Gem,
  Layers,
  ListChecks,
  PenTool,
  Plus,
  TriangleAlert,
  Wallet,
  Workflow,
  type LucideIcon,
} from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";

import { useToast } from "@/components/toast";
import { Button, ButtonLink, Card, CardHeader, cn, EmptyState, PageHeader, StatCard } from "@/components/ui";
import { ago, daysUntil, dueTag, money } from "@/lib/format";
import { jobProgress, STAGES, stageInfo } from "@/lib/stages";
import { useStore } from "@/lib/store";
import type { ActionItem, ActionKind, ActivityItem, Job, StageKey } from "@/lib/types";

const isActive = (j: Job) => j.stage !== "delivered";
const isAtRisk = (j: Job) => j.atRisk || daysUntil(j.dueDate) < 0;

export function DashboardView() {
  const jobs = useStore((s) => s.jobs);
  const dueSoonDays = useStore((s) => s.settings.dueSoonDays);

  const kpi = useMemo(() => {
    const active = jobs.filter(isActive);
    // Same rule as the Jobs page "Due Soon" tab (includes overdue).
    const dueSoon = active.filter((j) => daysUntil(j.dueDate) <= dueSoonDays);
    return {
      active: active.length,
      atRisk: active.filter(isAtRisk).length,
      flagged: active.filter((j) => j.atRisk).length,
      overdue: active.filter((j) => daysUntil(j.dueDate) < 0).length,
      value: active.reduce((sum, j) => sum + j.value, 0),
      dueSoon: dueSoon.length,
      delivered: jobs.length - active.length,
    };
  }, [jobs, dueSoonDays]);

  return (
    <>
      <PageHeader
        title="Manufacturer Overview"
        subtitle="Current operational status across all production stages."
        actions={
          <>
            <ButtonLink href="/production" icon={<Workflow size={16} />}>
              Production floor
            </ButtonLink>
            <ButtonLink href="/jobs/new" variant="primary" icon={<Plus size={16} />}>
              New job
            </ButtonLink>
          </>
        }
      />

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard
          label="Active jobs"
          value={kpi.active}
          hint={`${kpi.delivered} delivered`}
          icon={<Layers size={15} />}
          href="/jobs?filter=active"
        />
        <StatCard
          label="Delayed / at risk"
          value={kpi.atRisk}
          tone={kpi.atRisk ? "danger" : "neutral"}
          hint={`${kpi.flagged} flagged · ${kpi.overdue} overdue`}
          icon={<TriangleAlert size={15} />}
          href="/jobs?filter=atRisk"
        />
        <StatCard
          label="Value in production"
          value={money(kpi.value)}
          hint={kpi.active ? `Avg ${money(Math.round(kpi.value / kpi.active))} per job` : "No active jobs"}
          icon={<Wallet size={15} />}
          href="/jobs?filter=active"
        />
        <StatCard
          label="Due soon"
          value={kpi.dueSoon}
          tone={kpi.dueSoon ? "warning" : "neutral"}
          hint={`Due within ${dueSoonDays} day${dueSoonDays === 1 ? "" : "s"} or overdue`}
          icon={<CalendarClock size={15} />}
          href="/jobs?filter=dueSoon"
        />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="flex min-w-0 flex-col gap-6 lg:col-span-2">
          <StageMetrics jobs={jobs} />
          <ActionQueue />
        </div>
        <div className="flex min-w-0 flex-col gap-6">
          <PriorityOrders jobs={jobs} days={dueSoonDays} />
          <RecentActivity />
        </div>
      </div>
    </>
  );
}

// ---------------------------------------------------------------------------
// Stage metrics — horizontal bars, one row per stage in pipeline order.

/** Stage colors come in phase families; the legend names them. */
const PHASES: { label: string; stages: StageKey[] }[] = [
  { label: "Intake", stages: ["inquiry"] },
  { label: "Design", stages: ["cad"] },
  { label: "Approval", stages: ["approval", "pricing", "finalApproval"] },
  { label: "Production", stages: ["wax", "casting", "assembly", "setting", "polishing"] },
  { label: "Quality", stages: ["qc", "certification"] },
  { label: "Dispatch", stages: ["dispatch", "delivered"] },
];

function StageMetrics({ jobs }: { jobs: Job[] }) {
  const [hover, setHover] = useState<StageKey | null>(null);
  const byStage = useMemo(() => {
    const m = new Map<StageKey, Job[]>(STAGES.map((s) => [s.key, []]));
    for (const j of jobs) m.get(j.stage)?.push(j);
    return m;
  }, [jobs]);
  const max = Math.max(1, ...[...byStage.values()].map((l) => l.length));
  const active = jobs.filter(isActive).length;

  return (
    <Card>
      <CardHeader
        icon={<ChartBar size={18} />}
        title="Stage Metrics"
        subtitle={`Jobs at each of the ${STAGES.length} stages · ${active} active`}
        action={
          <Link href="/production" className="text-sm font-semibold text-accent hover:underline">
            View board
          </Link>
        }
      />
      <div className="px-5 pt-4 pb-5">
        <ul className="flex flex-wrap gap-x-4 gap-y-1.5" aria-label="Phase legend">
          {PHASES.map((p) => (
            <li key={p.label} className="flex items-center gap-1.5 text-xs text-fg-muted">
              <span className="h-2.5 w-3 rounded-[2px]" style={{ background: stageInfo(p.stages[0]).color }} />
              {p.label}
              <span className="font-mono text-fg-faint">
                {p.stages.reduce((n, s) => n + (byStage.get(s)?.length ?? 0), 0)}
              </span>
            </li>
          ))}
        </ul>

        <div className="relative mt-4" role="list" aria-label="Jobs per stage">
          {STAGES.map((s) => {
            const list = byStage.get(s.key) ?? [];
            const pct = (list.length / max) * 100;
            const on = hover === s.key;
            return (
              <div
                key={s.key}
                role="listitem"
                tabIndex={0}
                aria-label={`${s.label}: ${list.length} job${list.length === 1 ? "" : "s"}`}
                onPointerEnter={() => setHover(s.key)}
                onPointerLeave={() => setHover((h) => (h === s.key ? null : h))}
                onFocus={() => setHover(s.key)}
                onBlur={() => setHover((h) => (h === s.key ? null : h))}
                className={cn(
                  "relative grid grid-cols-[96px_1fr] items-center gap-3 rounded-md px-1 outline-none sm:grid-cols-[132px_1fr]",
                  on && "bg-surface-low",
                  "focus-visible:ring-2 focus-visible:ring-accent/40",
                )}
              >
                <span className="truncate py-[7px] text-right text-[13px] text-fg-muted">{s.label}</span>
                <div className="relative flex h-7 items-center border-l border-border-strong">
                  {list.length > 0 && (
                    <span
                      className="h-3.5 rounded-r-[4px] transition-[filter]"
                      style={{ width: `${pct}%`, background: s.color, filter: on ? "brightness(1.08)" : undefined }}
                    />
                  )}
                  <span
                    className={cn(
                      "ml-2 font-mono text-xs tabular-nums",
                      list.length ? "font-semibold text-fg" : "text-fg-faint",
                    )}
                  >
                    {list.length}
                  </span>
                  {on && list.length > 0 && <StageTip jobs={list} label={s.label} color={s.color} pct={pct} />}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </Card>
  );
}

function StageTip({ jobs, label, color, pct }: { jobs: Job[]; label: string; color: string; pct: number }) {
  const right = pct > 55;
  return (
    <div
      role="tooltip"
      className="pointer-events-none absolute top-full z-20 mt-1 w-56 rounded-lg border border-border bg-surface p-3 shadow-xl"
      style={right ? { right: `calc(${100 - pct}% - 24px)` } : { left: `calc(${pct}% + 28px)` }}
    >
      <div className="flex items-baseline gap-2">
        <span className="text-lg font-semibold">{jobs.length}</span>
        <span className="text-xs text-fg-muted">job{jobs.length === 1 ? "" : "s"} in</span>
        <span className="flex items-center gap-1.5 text-xs font-semibold">
          <span className="h-0.5 w-3 rounded-full" style={{ background: color }} />
          {label}
        </span>
      </div>
      <ul className="mt-2 space-y-1">
        {jobs.slice(0, 5).map((j) => (
          <li key={j.id} className="flex gap-2 text-xs">
            <span className="font-mono text-fg-muted">{j.id}</span>
            <span className="truncate text-fg">{j.title}</span>
          </li>
        ))}
        {jobs.length > 5 && <li className="text-xs text-fg-faint">+{jobs.length - 5} more</li>}
      </ul>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Priority orders — near-black card in light, gold-on-navy in dark.

function PriorityOrders({ jobs, days }: { jobs: Job[]; days: number }) {
  const due = useMemo(
    () =>
      jobs
        .filter((j) => isActive(j) && daysUntil(j.dueDate) <= days)
        .sort((a, b) => Date.parse(a.dueDate) - Date.parse(b.dueDate)),
    [jobs, days],
  );

  return (
    <section className="relative overflow-hidden rounded-xl bg-black p-5 text-white shadow-md dark:border dark:border-gold/25 dark:bg-surface-high dark:text-fg">
      <div className="pointer-events-none absolute -top-10 -right-10 size-36 rounded-full bg-white/10 blur-2xl dark:bg-gold/15" />
      <div className="relative flex items-center gap-2">
        <CircleAlert size={20} className="text-[#ffdf9a] dark:text-gold" />
        <h2 className="text-lg font-semibold">Priority Orders</h2>
        <span className="ml-auto font-mono text-[11px] tracking-wider text-white/60 uppercase dark:text-fg-faint">
          Due ≤ {days}d
        </span>
      </div>
      <div className="relative mt-4 flex flex-col gap-3">
        {due.length === 0 && (
          <p className="rounded-lg bg-white/10 px-3 py-4 text-sm text-white/70 dark:bg-surface-highest/60 dark:text-fg-muted">
            Nothing due in the next {days} days.
          </p>
        )}
        {due.map((j) => {
          const d = daysUntil(j.dueDate);
          const urgent = d <= 0;
          return (
            <Link
              key={j.id}
              href={`/jobs/${j.id}`}
              className="block rounded-lg bg-white/10 p-3 transition hover:bg-white/[0.16] dark:bg-surface-highest/60 dark:hover:bg-surface-highest"
            >
              <div className="flex items-start justify-between gap-2">
                <span className="font-mono text-sm font-semibold dark:text-gold">{j.id}</span>
                <span
                  className={cn(
                    "rounded px-2 py-0.5 font-mono text-[10px] font-bold tracking-wider",
                    urgent
                      ? "bg-[#ba1a1a]/40 text-[#ffdad6] dark:bg-danger-soft dark:text-danger"
                      : "bg-[#f7be1d]/15 text-[#ffdf9a] dark:bg-gold-soft dark:text-gold",
                  )}
                >
                  {dueTag(d)}
                </span>
              </div>
              <p className="mt-1 truncate text-sm text-white/80 dark:text-fg">{j.title}</p>
              <div className="mt-3 h-1 overflow-hidden rounded-full bg-white/20 dark:bg-surface">
                <div
                  className={cn("h-full rounded-full", urgent ? "bg-[#ffdad6] dark:bg-danger" : "bg-[#ffdf9a] dark:bg-gold")}
                  style={{ width: `${Math.round(jobProgress(j) * 100)}%` }}
                />
              </div>
              <div className="mt-1.5 flex justify-between font-mono text-[10px] tracking-wider text-white/55 uppercase dark:text-fg-faint">
                <span>{stageInfo(j.stage).label}</span>
                <span>{Math.round(jobProgress(j) * 100)}%</span>
              </div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Action queue

const ACTION_STYLE: Record<ActionKind, { icon: LucideIcon; border: string; chip: string }> = {
  cadReview: { icon: PenTool, border: "border-l-info", chip: "bg-info/10 text-info" },
  pricing: { icon: Banknote, border: "border-l-gold", chip: "bg-gold-soft text-gold" },
  delay: { icon: TriangleAlert, border: "border-l-danger", chip: "bg-danger-soft text-danger" },
  missing: { icon: Gem, border: "border-l-danger", chip: "bg-danger-soft text-danger" },
  certification: { icon: BadgeCheck, border: "border-l-success", chip: "bg-success-soft text-success" },
};

function ActionQueue() {
  const actions = useStore((s) => s.actions);
  const dismissAction = useStore((s) => s.dismissAction);
  const toast = useToast();

  return (
    <Card>
      <CardHeader
        icon={<ListChecks size={18} />}
        title="Action Queue"
        subtitle={actions.length ? `${actions.length} item${actions.length === 1 ? "" : "s"} need attention` : undefined}
      />
      {actions.length === 0 ? (
        <EmptyState icon={<CircleCheck size={28} />} title="All caught up" message="Nothing is waiting on you right now." />
      ) : (
        <ul className="flex flex-col gap-2.5 p-4">
          {actions.map((a) => (
            <ActionRow
              key={a.id}
              action={a}
              onDismiss={() => {
                dismissAction(a.id);
                toast("Action dismissed");
              }}
            />
          ))}
        </ul>
      )}
    </Card>
  );
}

function ActionRow({ action: a, onDismiss }: { action: ActionItem; onDismiss: () => void }) {
  const { icon: Icon, border, chip } = ACTION_STYLE[a.kind] ?? ACTION_STYLE.delay;
  return (
    <li
      className={cn(
        "flex flex-col gap-3 rounded-lg border border-l-4 border-border bg-surface-low p-3.5 transition hover:bg-surface-high sm:flex-row sm:items-center",
        border,
      )}
    >
      <div className="flex min-w-0 flex-1 items-center gap-3.5">
        <span className={cn("flex size-10 shrink-0 items-center justify-center rounded-full", chip)}>
          <Icon size={18} />
        </span>
        <div className="min-w-0">
          <p className="text-sm font-semibold">{a.title}</p>
          <p className="mt-0.5 text-[13px] text-fg-muted">{a.subtitle}</p>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-1.5 pl-[54px] sm:pl-0">
        <Button variant="ghost" size="sm" onClick={onDismiss}>
          Dismiss
        </Button>
        <ButtonLink href={`/jobs/${a.jobId}`} variant="primary" size="sm">
          {a.cta}
        </ButtonLink>
      </div>
    </li>
  );
}

// ---------------------------------------------------------------------------
// Recent activity timeline

function RecentActivity() {
  const activity = useStore((s) => s.activity);
  const [all, setAll] = useState(false);
  const shown = all ? activity : activity.slice(0, 7);

  return (
    <Card className="flex-1">
      <CardHeader icon={<Activity size={18} />} title="Recent Activity" />
      {activity.length === 0 ? (
        <EmptyState title="No activity yet" />
      ) : (
        <div className="px-5 py-5">
          <ol className="relative ml-1.5 flex flex-col gap-5 border-l border-border-strong/60">
            {shown.map((a, i) => (
              <ActivityRow key={a.id} item={a} latest={i === 0} />
            ))}
          </ol>
          {activity.length > 7 && (
            <button
              type="button"
              onClick={() => setAll((v) => !v)}
              className="mt-4 text-sm font-semibold text-accent hover:underline"
            >
              {all ? "Show less" : `Show all ${activity.length}`}
            </button>
          )}
        </div>
      )}
    </Card>
  );
}

function ActivityRow({ item: a, latest }: { item: ActivityItem; latest: boolean }) {
  return (
    <li className="relative pl-5">
      <span
        className={cn(
          "absolute top-1 -left-[6.5px] size-3 rounded-full ring-4 ring-surface",
          latest ? "bg-accent" : "bg-border-strong",
        )}
      />
      <p className="text-sm">
        {a.text}{" "}
        <Link href={`/jobs/${a.jobId}`} className="font-mono text-accent hover:underline">
          {a.jobId}
        </Link>
      </p>
      <p className="mt-0.5 text-xs text-fg-muted">
        {ago(a.time)} · {a.by}
      </p>
    </li>
  );
}
