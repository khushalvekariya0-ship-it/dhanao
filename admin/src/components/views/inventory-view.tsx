"use client";

import {
  ArrowDownToLine,
  ArrowUpFromLine,
  Boxes,
  Gem,
  Link2,
  MapPin,
  Pencil,
  Plus,
  Search,
  Trash2,
  Unlink,
  X,
} from "lucide-react";
import Link from "next/link";
import { useMemo, useRef, useState, type FormEvent, type ReactNode } from "react";

import { useToast } from "@/components/toast";
import {
  Badge,
  Button,
  cn,
  ConfirmModal,
  EmptyState,
  Field,
  IconButton,
  Input,
  Modal,
  PageHeader,
  Segmented,
  Select,
  StageBadge,
  StatCard,
  Thumb,
  type Tone,
} from "@/components/ui";
import { grams } from "@/lib/format";
import { useStore } from "@/lib/store";
import type { GemStock, Job, MetalStock } from "@/lib/types";

const LOW = 0.25;
const GEM_IMAGES = ["gem_diamond.jpg", "gem_ruby.jpg"];
const METAL_SWATCHES = ["#d4af37", "#e3b866", "#b76e79", "#b8c4d6", "#e5e4e2", "#9ca3af"];
const SPEC_KEYS = ["CARAT", "CTW", "COLOR", "CLARITY", "CUT", "SHAPE", "ORIGIN", "TREATMENT", "CERT"];
const CODE = /^[A-Z0-9][A-Z0-9-]*$/;

const num = (v: number) => v.toLocaleString("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 2 });
const ratio = (m: MetalStock) => (m.capacityGrams > 0 ? m.grams / m.capacityGrams : 0);
const isLow = (m: MetalStock) => ratio(m) < LOW;
const tagTone = (tag: string): Tone => (/cert/i.test(tag) ? "success" : "neutral");
const activeJobs = (jobs: Job[]) => jobs.filter((j) => j.stage !== "delivered");
const invalidCls = (error?: string) => (error ? "border-danger focus:border-danger focus:ring-danger/20" : undefined);

type Show = "all" | "metals" | "gems";
type GemFilter = "all" | "available" | "assigned";

export function InventoryView() {
  const metals = useStore((s) => s.metals);
  const gems = useStore((s) => s.gems);
  const jobs = useStore((s) => s.jobs);
  const assignGem = useStore((s) => s.assignGem);
  const deleteMetal = useStore((s) => s.deleteMetal);
  const deleteGem = useStore((s) => s.deleteGem);
  const toast = useToast();

  const [show, setShow] = useState<Show>("all");
  const [q, setQ] = useState("");
  const [gemFilter, setGemFilter] = useState<GemFilter>("all");
  const [move, setMove] = useState<{ metal: MetalStock; dir: "in" | "out" } | null>(null);
  const [metalEdit, setMetalEdit] = useState<MetalStock | "new" | null>(null);
  const [metalDelete, setMetalDelete] = useState<MetalStock | null>(null);
  const [assigning, setAssigning] = useState<GemStock | null>(null);
  const [gemEdit, setGemEdit] = useState<GemStock | "new" | null>(null);
  const [gemDelete, setGemDelete] = useState<GemStock | null>(null);

  const term = q.trim().toLowerCase();
  const shownMetals = useMemo(
    () => metals.filter((m) => !term || [m.code, m.name].some((v) => v.toLowerCase().includes(term))),
    [metals, term],
  );
  const searchedGems = useMemo(
    () =>
      gems.filter(
        (g) =>
          !term ||
          [g.id, g.name, g.tag, g.location, g.assignedJobId ?? "", ...Object.values(g.specs)].some((v) =>
            v.toLowerCase().includes(term),
          ),
      ),
    [gems, term],
  );
  const shownGems = searchedGems.filter((g) =>
    gemFilter === "all" ? true : gemFilter === "assigned" ? !!g.assignedJobId : !g.assignedJobId,
  );

  const totalGrams = metals.reduce((a, m) => a + m.grams, 0);
  const totalCapacity = metals.reduce((a, m) => a + m.capacityGrams, 0);
  const lowMetals = metals.filter(isLow);
  const available = gems.filter((g) => !g.assignedJobId);
  const assigned = gems.length - available.length;
  const assignedJobs = new Set(gems.map((g) => g.assignedJobId).filter(Boolean)).size;

  return (
    <>
      <PageHeader
        eyebrow="Vault & stock"
        title="Inventory"
        subtitle="Metals on hand and loose stones, ready to issue to production."
        actions={
          <>
            <Button variant="secondary" icon={<Plus size={16} />} onClick={() => setMetalEdit("new")}>
              Add Metal
            </Button>
            <Button icon={<Plus size={16} />} onClick={() => setGemEdit("new")}>
              Add Gem
            </Button>
          </>
        }
      />

      <div className="mb-6 grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard
          label="Metal on hand"
          value={<span className="font-mono">{grams(totalGrams, 0)}</span>}
          hint={`${metals.length} alloys · ${totalCapacity ? Math.round((totalGrams / totalCapacity) * 100) : 0}% of capacity`}
          icon={<Boxes size={16} />}
        />
        <StatCard
          label="Low stock"
          value={lowMetals.length}
          tone={lowMetals.length ? "danger" : "neutral"}
          hint={lowMetals.length ? lowMetals.map((m) => m.code).join(", ") : "All metals above 25%"}
        />
        <StatCard
          label="Stones available"
          value={available.length}
          tone="success"
          icon={<Gem size={16} />}
          hint={<span className="font-mono">{available.reduce((a, g) => a + g.carat, 0).toFixed(2)} ct total</span>}
        />
        <StatCard label="Stones assigned" value={assigned} hint={`to ${assignedJobs} job${assignedJobs === 1 ? "" : "s"}`} />
      </div>

      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center">
        <Segmented
          value={show}
          onChange={setShow}
          options={[
            { value: "all", label: "All" },
            { value: "metals", label: "Metals" },
            { value: "gems", label: "Gems" },
          ]}
          className="self-start"
        />
        <div className="relative w-full sm:max-w-sm">
          <Search size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search inventory ID, type, location…" className="pl-9" />
        </div>
      </div>

      {show !== "gems" && (
        <section className="mb-10">
          <SectionHeader title="Raw Materials" meta="Metals (g)">
            {lowMetals.length > 0 && (
              <Badge tone="danger" dot>
                {lowMetals.length} below 25%
              </Badge>
            )}
          </SectionHeader>
          {shownMetals.length === 0 ? (
            <Empty
              icon={<Boxes size={30} />}
              title={metals.length ? "No metals match your search" : "No metals in stock"}
              message={metals.length ? undefined : "Add the alloys you keep in the vault."}
            />
          ) : (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
              {shownMetals.map((m) => (
                <MetalCard
                  key={m.code}
                  metal={m}
                  onMove={(dir) => setMove({ metal: m, dir })}
                  onEdit={() => setMetalEdit(m)}
                  onDelete={() => setMetalDelete(m)}
                />
              ))}
            </div>
          )}
        </section>
      )}

      {show !== "metals" && (
        <section>
          <SectionHeader title="Gemstone Inventory" meta="Active stock">
            <Segmented
              value={gemFilter}
              onChange={setGemFilter}
              options={[
                { value: "all", label: `All ${searchedGems.length}` },
                { value: "available", label: `Available ${searchedGems.filter((g) => !g.assignedJobId).length}` },
                { value: "assigned", label: `Assigned ${searchedGems.filter((g) => g.assignedJobId).length}` },
              ]}
            />
          </SectionHeader>
          {shownGems.length === 0 ? (
            <Empty
              icon={<Gem size={30} />}
              title={gems.length ? "No stones match" : "No stones in stock"}
              message={gems.length ? "Try another search or status filter." : "Add loose stones to track where they are and which job they belong to."}
            />
          ) : (
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2 2xl:grid-cols-3">
              {shownGems.map((g) => (
                <GemCard
                  key={g.id}
                  gem={g}
                  job={jobs.find((j) => j.id === g.assignedJobId)}
                  onAssign={() => setAssigning(g)}
                  onUnassign={() => {
                    assignGem(g.id, null);
                    toast(`${g.id} released from ${g.assignedJobId}`);
                  }}
                  onEdit={() => setGemEdit(g)}
                  onDelete={() => setGemDelete(g)}
                />
              ))}
            </div>
          )}
        </section>
      )}

      {move && <StockMoveModal key={move.metal.code + move.dir} {...move} onClose={() => setMove(null)} />}
      {metalEdit && (
        <MetalForm key={metalEdit === "new" ? "new" : metalEdit.code} metal={metalEdit === "new" ? null : metalEdit} onClose={() => setMetalEdit(null)} />
      )}
      {assigning && <AssignModal key={assigning.id} gem={assigning} onClose={() => setAssigning(null)} />}
      {gemEdit && <GemForm key={gemEdit === "new" ? "new" : gemEdit.id} gem={gemEdit === "new" ? null : gemEdit} onClose={() => setGemEdit(null)} />}

      <ConfirmModal
        open={!!metalDelete}
        onClose={() => setMetalDelete(null)}
        danger
        title="Delete metal?"
        confirmLabel="Delete metal"
        message={
          <>
            <strong className="text-fg">
              {metalDelete?.name} ({metalDelete?.code})
            </strong>{" "}
            and its {metalDelete ? grams(metalDelete.grams) : ""} balance will be removed from inventory.
          </>
        }
        onConfirm={() => {
          if (!metalDelete) return;
          deleteMetal(metalDelete.code);
          toast(`${metalDelete.name} removed from inventory`);
        }}
      />
      <ConfirmModal
        open={!!gemDelete}
        onClose={() => setGemDelete(null)}
        danger
        title="Delete stone?"
        confirmLabel="Delete stone"
        message={
          <>
            <strong className="text-fg">{gemDelete?.name}</strong> <span className="font-mono">({gemDelete?.id})</span> will be
            removed from inventory
            {gemDelete?.assignedJobId ? ` and unlinked from ${gemDelete.assignedJobId}` : ""}.
          </>
        }
        onConfirm={() => {
          if (!gemDelete) return;
          deleteGem(gemDelete.id);
          toast(`${gemDelete.id} removed from inventory`);
        }}
      />
    </>
  );
}

// ---------------------------------------------------------------------------
// Layout pieces

function SectionHeader({ title, meta, children }: { title: string; meta: string; children?: ReactNode }) {
  return (
    <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
      <div className="flex items-baseline gap-3">
        <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
        <span className="label-caps text-fg-faint">{meta}</span>
      </div>
      {children}
    </div>
  );
}

function Empty(props: { icon: ReactNode; title: string; message?: string }) {
  return (
    <div className="rounded-xl border border-dashed border-border-strong bg-surface">
      <EmptyState {...props} />
    </div>
  );
}

function MetalCard({
  metal: m,
  onMove,
  onEdit,
  onDelete,
}: {
  metal: MetalStock;
  onMove: (dir: "in" | "out") => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const r = ratio(m);
  const low = isLow(m);
  return (
    <div className={cn("flex flex-col rounded-xl border bg-surface p-5", low ? "border-danger/40" : "border-border")}>
      <div className="flex items-center justify-between gap-2">
        <span className="font-mono text-xs font-semibold tracking-wider text-fg-faint">{m.code}</span>
        <div className="-mr-2 flex">
          <IconButton label={`Edit ${m.name}`} className="size-8!" onClick={onEdit}>
            <Pencil size={14} />
          </IconButton>
          <IconButton label={`Delete ${m.name}`} className="size-8! hover:text-danger" onClick={onDelete}>
            <Trash2 size={14} />
          </IconButton>
        </div>
      </div>
      <div className="flex min-w-0 items-center gap-2.5">
        <span className="size-3 shrink-0 rounded-full ring-2 ring-surface-high" style={{ background: m.color }} />
        <span className="truncate font-semibold">{m.name}</span>
      </div>
      <div className="mt-4 flex items-baseline gap-1.5">
        <span className="font-mono text-3xl font-semibold tracking-tight">{num(m.grams)}</span>
        <span className="font-mono text-sm text-fg-faint">g</span>
        {low && (
          <Badge tone="danger" className="ml-auto self-center">
            Low
          </Badge>
        )}
      </div>
      <div
        className="mt-3 h-1.5 overflow-hidden rounded-full bg-surface-highest"
        role="meter"
        aria-label={`${m.name} stock`}
        aria-valuemin={0}
        aria-valuemax={m.capacityGrams}
        aria-valuenow={m.grams}
      >
        <div
          className="h-full rounded-full"
          style={{ width: `${Math.min(100, r * 100)}%`, background: low ? "var(--danger)" : m.color }}
        />
      </div>
      <div className="mt-2 flex justify-between gap-2 text-xs text-fg-muted">
        <span className={cn(low && "font-semibold text-danger")}>{Math.round(r * 100)}% of capacity</span>
        <span className="font-mono">{grams(m.capacityGrams, 0)}</span>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-2 border-t border-border pt-4">
        <Button size="sm" variant="secondary" icon={<ArrowDownToLine size={14} />} onClick={() => onMove("in")}>
          Receive
        </Button>
        <Button size="sm" variant="secondary" icon={<ArrowUpFromLine size={14} />} disabled={m.grams <= 0} onClick={() => onMove("out")}>
          Issue
        </Button>
      </div>
    </div>
  );
}

function GemCard({
  gem: g,
  job,
  onAssign,
  onUnassign,
  onEdit,
  onDelete,
}: {
  gem: GemStock;
  job?: Job;
  onAssign: () => void;
  onUnassign: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const specs = Object.entries(g.specs);
  return (
    <div className="flex flex-col rounded-xl border border-border bg-surface">
      <div className="flex flex-1 gap-4 p-5">
        <Thumb src={g.image} alt={g.name} className="size-20 shrink-0 sm:size-24" />
        <div className="min-w-0 flex-1">
          <div className="flex items-start gap-2">
            <h3 className="min-w-0 flex-1 leading-snug font-semibold">{g.name}</h3>
            {g.tag && (
              <Badge tone={tagTone(g.tag)} mono={false}>
                {g.tag}
              </Badge>
            )}
          </div>
          <div className="mt-1 font-mono text-xs text-fg-muted">
            ID: {g.id} · {g.carat.toFixed(2)} ct
          </div>
          {specs.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-1.5">
              {specs.map(([k, v]) => (
                <span key={k} className="inline-flex items-center gap-1.5 rounded border border-border bg-surface-low px-2 py-1">
                  <span className="font-mono text-[10px] font-bold tracking-wider text-fg-faint uppercase">{k}</span>
                  <span className="font-mono text-xs font-semibold">{v}</span>
                </span>
              ))}
            </div>
          )}
          <div className="mt-3 text-sm">
            {g.assignedJobId ? (
              <Link
                href={`/jobs/${g.assignedJobId}`}
                title={job?.title}
                className="inline-flex max-w-full items-center gap-1.5 font-semibold text-accent hover:underline"
              >
                <Link2 size={14} className="shrink-0" />
                <span className="truncate">
                  Assigned → <span className="font-mono">{g.assignedJobId}</span>
                  {job && <span className="font-normal text-fg-muted"> · {job.title}</span>}
                </span>
              </Link>
            ) : (
              <Badge tone="success" dot>
                Available
              </Badge>
            )}
          </div>
        </div>
      </div>
      <div className="flex flex-col gap-2 border-t border-border px-5 py-3 sm:flex-row sm:items-center sm:gap-3">
        <span className="flex min-w-0 flex-1 items-center gap-1.5 font-mono text-xs text-fg-muted">
          <MapPin size={13} className="shrink-0 text-fg-faint" />
          <span className="truncate">Loc: {g.location}</span>
        </span>
        <div className="flex items-center justify-end gap-1">
          <IconButton label={`Edit ${g.id}`} className="size-8!" onClick={onEdit}>
            <Pencil size={14} />
          </IconButton>
          <IconButton label={`Delete ${g.id}`} className="size-8! hover:text-danger" onClick={onDelete}>
            <Trash2 size={14} />
          </IconButton>
          {g.assignedJobId ? (
            <>
              <Button size="sm" variant="ghost" onClick={onAssign}>
                Reassign
              </Button>
              <Button size="sm" variant="secondary" icon={<Unlink size={14} />} onClick={onUnassign}>
                Unassign
              </Button>
            </>
          ) : (
            <Button size="sm" variant="accent" icon={<Link2 size={14} />} onClick={onAssign}>
              Assign
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Metal modals

function StockMoveModal({ metal, dir, onClose }: { metal: MetalStock; dir: "in" | "out"; onClose: () => void }) {
  const jobs = useStore((s) => s.jobs);
  const adjustMetal = useStore((s) => s.adjustMetal);
  const toast = useToast();
  const [amount, setAmount] = useState("");
  const [jobId, setJobId] = useState("");
  const [note, setNote] = useState("");
  const [tried, setTried] = useState(false);

  const receiving = dir === "in";
  const g = Number(amount);
  const valid = amount.trim() !== "" && Number.isFinite(g) && g > 0;
  const error = !valid
    ? "Enter a weight greater than 0."
    : !receiving && g > metal.grams
      ? `Only ${grams(metal.grams)} on hand.`
      : undefined;
  const after = metal.grams + (valid ? (receiving ? g : -g) : 0);
  const over = receiving && after > metal.capacityGrams;

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (error) return;
    const memo = [jobId && `Job ${jobId}`, note.trim()].filter(Boolean).join(" — ");
    adjustMetal(metal.code, receiving ? g : -g, memo || undefined);
    toast(
      receiving
        ? `Received ${grams(g, 2)} of ${metal.name}`
        : `Issued ${grams(g, 2)} of ${metal.name}${jobId ? ` to ${jobId}` : ""}`,
    );
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      size="sm"
      title={receiving ? `Receive ${metal.name}` : `Issue ${metal.name}`}
      subtitle={receiving ? "Add metal delivered to the vault." : "Take metal out of the vault for production."}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="stock-move" icon={receiving ? <ArrowDownToLine size={16} /> : <ArrowUpFromLine size={16} />}>
            {receiving ? "Receive" : "Issue"}
          </Button>
        </>
      }
    >
      <form id="stock-move" onSubmit={submit} noValidate className="space-y-4">
        <div className="flex items-center gap-3 rounded-lg border border-border bg-surface-low px-4 py-3">
          <span className="size-3 rounded-full" style={{ background: metal.color }} />
          <span className="font-mono text-xs font-semibold text-fg-muted">{metal.code}</span>
          <span className="ml-auto text-right">
            <span className="label-caps block text-[10px]">On hand → after</span>
            <span className="font-mono text-sm font-semibold">
              {num(metal.grams)} → <span className={cn(over && "text-warning")}>{num(Math.max(0, after))}</span> g
            </span>
          </span>
        </div>
        <Field
          label="Weight (grams) *"
          hint={
            tried && error ? (
              <span className="text-danger">{error}</span>
            ) : over ? (
              <span className="text-warning">Above the {grams(metal.capacityGrams, 0)} vault capacity.</span>
            ) : undefined
          }
        >
          <Input
            type="number"
            inputMode="decimal"
            min={0}
            step={0.1}
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
            autoFocus
            className={cn("font-mono", invalidCls(tried ? error : undefined))}
          />
        </Field>
        {!receiving && (
          <Field label="Issue to job" hint="Optional — which job the metal is for.">
            <Select value={jobId} onChange={(e) => setJobId(e.target.value)}>
              <option value="">No job (general use)</option>
              {activeJobs(jobs).map((j) => (
                <option key={j.id} value={j.id}>
                  {j.id} · {j.title}
                </option>
              ))}
            </Select>
          </Field>
        )}
        <Field label="Note">
          <Input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={receiving ? "e.g. Supplier invoice #4471" : "e.g. Casting batch 12"}
          />
        </Field>
      </form>
    </Modal>
  );
}

function MetalForm({ metal, onClose }: { metal: MetalStock | null; onClose: () => void }) {
  const metals = useStore((s) => s.metals);
  const saveMetal = useStore((s) => s.saveMetal);
  const toast = useToast();
  const [code, setCode] = useState(metal?.code ?? "");
  const [name, setName] = useState(metal?.name ?? "");
  const [onHand, setOnHand] = useState(metal ? String(metal.grams) : "0");
  const [capacity, setCapacity] = useState(metal ? String(metal.capacityGrams) : "1000");
  const [color, setColor] = useState(metal?.color ?? METAL_SWATCHES[0]);
  const [tried, setTried] = useState(false);

  const c = code.trim().toUpperCase();
  const g = Number(onHand);
  const cap = Number(capacity);
  const errors: Partial<Record<"code" | "name" | "grams" | "capacity", string>> = {};
  if (!c) errors.code = "Code is required.";
  else if (!CODE.test(c)) errors.code = "Use letters, numbers and dashes (e.g. AU-750).";
  else if (metals.some((m) => m.code === c && m.code !== metal?.code)) errors.code = "Another metal already uses this code.";
  if (!name.trim()) errors.name = "Name is required.";
  if (onHand.trim() === "" || !Number.isFinite(g) || g < 0) errors.grams = "Enter 0 or more grams.";
  if (!Number.isFinite(cap) || cap <= 0) errors.capacity = "Capacity must be greater than 0.";
  const err = (k: keyof typeof errors) => (tried ? errors[k] : undefined);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (Object.keys(errors).length) return;
    saveMetal({ code: c, name: name.trim(), grams: +g.toFixed(2), capacityGrams: cap, color }, metal?.code);
    toast(metal ? `${name.trim()} updated` : `${name.trim()} added to inventory`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={metal ? "Edit metal" : "Add metal"}
      subtitle={metal ? `${metal.name} · ${metal.code}` : "A new alloy kept in the vault."}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="metal-form">
            {metal ? "Save changes" : "Add metal"}
          </Button>
        </>
      }
    >
      <form id="metal-form" onSubmit={submit} noValidate className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="Code *" hint={<Err>{err("code")}</Err>}>
          <Input
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            placeholder="AU-750"
            autoFocus
            className={cn("font-mono", invalidCls(err("code")))}
          />
        </Field>
        <Field label="Name *" hint={<Err>{err("name")}</Err>}>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="18K Gold" className={invalidCls(err("name"))} />
        </Field>
        <Field label="On hand (g) *" hint={<Err>{err("grams")}</Err>}>
          <Input
            type="number"
            min={0}
            step={0.1}
            value={onHand}
            onChange={(e) => setOnHand(e.target.value)}
            className={cn("font-mono", invalidCls(err("grams")))}
          />
        </Field>
        <Field label="Capacity (g) *" hint={<Err>{err("capacity")}</Err>}>
          <Input
            type="number"
            min={1}
            step={1}
            value={capacity}
            onChange={(e) => setCapacity(e.target.value)}
            className={cn("font-mono", invalidCls(err("capacity")))}
          />
        </Field>
        <div className="sm:col-span-2">
          <span className="label-caps mb-1.5 block">Color</span>
          <div className="flex flex-wrap items-center gap-2">
            {METAL_SWATCHES.map((s) => (
              <button
                key={s}
                type="button"
                title={s}
                aria-label={`Color ${s}`}
                aria-pressed={color === s}
                onClick={() => setColor(s)}
                className={cn("rounded-full p-0.5 ring-2 transition", color === s ? "ring-accent" : "ring-transparent hover:ring-border-strong")}
              >
                <span className="block size-7 rounded-full" style={{ background: s }} />
              </button>
            ))}
            <label className="ml-1 flex items-center gap-2 text-xs text-fg-muted">
              <input
                type="color"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                className="size-8 cursor-pointer rounded border border-border bg-surface"
              />
              <span className="font-mono">{color}</span>
            </label>
          </div>
        </div>
      </form>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Gem modals

function AssignModal({ gem, onClose }: { gem: GemStock; onClose: () => void }) {
  const jobs = useStore((s) => s.jobs);
  const gems = useStore((s) => s.gems);
  const assignGem = useStore((s) => s.assignGem);
  const toast = useToast();
  const [jobId, setJobId] = useState(gem.assignedJobId ?? "");
  const [tried, setTried] = useState(false);
  const job = jobs.find((j) => j.id === jobId);
  const alsoOnJob = gems.filter((g) => g.id !== gem.id && g.assignedJobId && g.assignedJobId === jobId);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (!jobId) return;
    assignGem(gem.id, jobId);
    toast(`${gem.id} assigned to ${jobId}`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={gem.assignedJobId ? "Reassign stone" : "Assign stone to job"}
      subtitle="Reserve this stone for a job in production."
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="assign-gem" variant="accent" icon={<Link2 size={16} />}>
            Assign
          </Button>
        </>
      }
    >
      <form id="assign-gem" onSubmit={submit} className="space-y-4">
        <div className="flex items-center gap-3 rounded-lg border border-border bg-surface-low p-3">
          <Thumb src={gem.image} alt={gem.name} className="size-12 shrink-0" />
          <div className="min-w-0">
            <div className="truncate font-semibold">{gem.name}</div>
            <div className="font-mono text-xs text-fg-muted">
              {gem.id} · {gem.carat.toFixed(2)} ct
            </div>
          </div>
        </div>
        <Field label="Job *" hint={tried && !jobId ? <span className="text-danger">Choose a job.</span> : undefined}>
          <Select value={jobId} onChange={(e) => setJobId(e.target.value)} autoFocus className={invalidCls(tried && !jobId ? "x" : undefined)}>
            <option value="">Select an active job…</option>
            {activeJobs(jobs).map((j) => (
              <option key={j.id} value={j.id}>
                {j.id} · {j.title} ({j.customer})
              </option>
            ))}
          </Select>
        </Field>
        {job && (
          <div className="rounded-lg border border-border p-3">
            <div className="flex items-center gap-3">
              <Thumb src={job.image} alt={job.title} className="size-12 shrink-0" />
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-semibold">{job.title}</div>
                <div className="truncate text-xs text-fg-muted">
                  {job.customer} · Center stone: {job.centerStone}
                </div>
              </div>
              <StageBadge stage={job.stage} />
            </div>
            {alsoOnJob.length > 0 && (
              <p className="mt-2 text-xs text-fg-muted">
                Already reserved for this job: <span className="font-mono">{alsoOnJob.map((g) => g.id).join(", ")}</span>
              </p>
            )}
          </div>
        )}
      </form>
    </Modal>
  );
}

interface SpecRow {
  id: number;
  key: string;
  value: string;
}

function GemForm({ gem, onClose }: { gem: GemStock | null; onClose: () => void }) {
  const gems = useStore((s) => s.gems);
  const saveGem = useStore((s) => s.saveGem);
  const toast = useToast();
  const initialSpecs = Object.entries(gem?.specs ?? { CARAT: "", COLOR: "", CLARITY: "" });
  const nextId = useRef(initialSpecs.length);
  const [id, setId] = useState(gem?.id ?? "");
  const [name, setName] = useState(gem?.name ?? "");
  const [tag, setTag] = useState(gem?.tag ?? "");
  const [carat, setCarat] = useState(gem ? String(gem.carat) : "");
  const [location, setLocation] = useState(gem?.location ?? "");
  const [image, setImage] = useState<string | null>(gem?.image ?? null);
  const [specs, setSpecs] = useState<SpecRow[]>(initialSpecs.map(([key, value], i) => ({ id: i, key, value })));
  const [tried, setTried] = useState(false);

  const gid = id.trim().toUpperCase();
  const ct = Number(carat);
  // Rows without a value are dropped; a value without a name is an error.
  const filled = specs.filter((s) => s.value.trim());
  const keys = filled.map((s) => s.key.trim().toUpperCase());
  const errors: Partial<Record<"id" | "name" | "carat" | "location" | "specs", string>> = {};
  if (!gid) errors.id = "ID is required.";
  else if (!CODE.test(gid)) errors.id = "Use letters, numbers and dashes (e.g. DIA-9982-A).";
  else if (gems.some((g) => g.id === gid && g.id !== gem?.id)) errors.id = "Another stone already uses this ID.";
  if (!name.trim()) errors.name = "Name is required.";
  if (carat.trim() === "" || !Number.isFinite(ct) || ct <= 0) errors.carat = "Carat must be greater than 0.";
  if (!location.trim()) errors.location = "Where is it stored?";
  if (filled.some((s) => !s.key.trim())) errors.specs = "Every spec needs a name.";
  else if (new Set(keys).size !== keys.length) errors.specs = "Spec names must be unique.";
  const err = (k: keyof typeof errors) => (tried ? errors[k] : undefined);

  const setSpec = (rowId: number, patch: Partial<SpecRow>) => setSpecs((l) => l.map((s) => (s.id === rowId ? { ...s, ...patch } : s)));
  const addSpec = () => {
    nextId.current += 1;
    const rowId = nextId.current;
    setSpecs((l) => [...l, { id: rowId, key: "", value: "" }]);
  };

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (Object.keys(errors).length) return;
    saveGem(
      {
        id: gid,
        name: name.trim(),
        tag: tag.trim(),
        carat: ct,
        location: location.trim(),
        image,
        specs: Object.fromEntries(filled.map((s) => [s.key.trim().toUpperCase(), s.value.trim()])),
        assignedJobId: gem?.assignedJobId ?? null,
      },
      gem?.id,
    );
    toast(gem ? `${gid} updated` : `${gid} added to inventory`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={gem ? "Edit stone" : "Add stone"}
      subtitle={gem ? `${gem.name} · ${gem.id}` : "A loose stone or parcel kept in the vault."}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="gem-form">
            {gem ? "Save changes" : "Add stone"}
          </Button>
        </>
      }
    >
      <form id="gem-form" onSubmit={submit} noValidate className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="Stock ID *" hint={<Err>{err("id")}</Err>}>
          <Input
            value={id}
            onChange={(e) => setId(e.target.value.toUpperCase())}
            placeholder="DIA-0000-A"
            autoFocus
            className={cn("font-mono", invalidCls(err("id")))}
          />
        </Field>
        <Field label="Name *" hint={<Err>{err("name")}</Err>}>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Round Brilliant Diamond" className={invalidCls(err("name"))} />
        </Field>
        <Field label="Tag" hint="Certificate or treatment, e.g. GIA Cert, Unheated.">
          <Input value={tag} onChange={(e) => setTag(e.target.value)} placeholder="GIA Cert" />
        </Field>
        <Field label="Carat *" hint={<Err>{err("carat")}</Err>}>
          <Input
            type="number"
            min={0}
            step={0.01}
            value={carat}
            onChange={(e) => setCarat(e.target.value)}
            placeholder="1.00"
            className={cn("font-mono", invalidCls(err("carat")))}
          />
        </Field>
        <Field label="Location *" hint={<Err>{err("location")}</Err>} className="sm:col-span-2">
          <Input value={location} onChange={(e) => setLocation(e.target.value)} placeholder="Vault A, Tray 4" className={invalidCls(err("location"))} />
        </Field>

        <div className="sm:col-span-2">
          <div className="mb-1.5 flex items-center justify-between">
            <span className="label-caps">Specs</span>
            <Button size="sm" variant="ghost" icon={<Plus size={14} />} onClick={addSpec}>
              Add spec
            </Button>
          </div>
          <datalist id="spec-keys">
            {SPEC_KEYS.map((k) => (
              <option key={k} value={k} />
            ))}
          </datalist>
          <div className="space-y-2">
            {specs.map((s) => (
              <div key={s.id} className="flex items-center gap-2">
                <div className="w-28 shrink-0 sm:w-40">
                  <Input
                    list="spec-keys"
                    value={s.key}
                    onChange={(e) => setSpec(s.id, { key: e.target.value.toUpperCase() })}
                    placeholder="COLOR"
                    aria-label="Spec name"
                    className="font-mono text-xs"
                  />
                </div>
                <div className="min-w-0 flex-1">
                  <Input
                    value={s.value}
                    onChange={(e) => setSpec(s.id, { value: e.target.value })}
                    placeholder="Value"
                    aria-label="Spec value"
                    className="font-mono text-xs"
                  />
                </div>
                <IconButton label="Remove spec" onClick={() => setSpecs((l) => l.filter((x) => x.id !== s.id))}>
                  <X size={16} />
                </IconButton>
              </div>
            ))}
            {specs.length === 0 && <p className="text-sm text-fg-faint">No specs. Add carat, color, clarity, origin…</p>}
          </div>
          {err("specs") && <p className="mt-1 text-xs text-danger">{err("specs")}</p>}
        </div>

        <div className="sm:col-span-2">
          <span className="label-caps mb-1.5 block">Photo</span>
          <div className="flex flex-wrap gap-3">
            {[null, ...GEM_IMAGES].map((img) => (
              <button
                key={img ?? "none"}
                type="button"
                onClick={() => setImage(img)}
                aria-pressed={image === img}
                title={img ?? "No photo"}
                className={cn("rounded-xl p-0.5 ring-2 transition", image === img ? "ring-accent" : "ring-transparent hover:ring-border-strong")}
              >
                <Thumb src={img} alt={img ?? "No photo"} className="size-16" />
              </button>
            ))}
          </div>
        </div>
      </form>
    </Modal>
  );
}

function Err({ children }: { children?: string }) {
  return children ? <span className="text-danger">{children}</span> : null;
}
