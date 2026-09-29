"use client";

import { Check, Diamond, ImagePlus, Images, Ruler, Send, Truck, Upload, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useMemo, useRef, useState, type FormEvent, type ReactNode } from "react";

import { useToast } from "@/components/toast";
import {
  Button,
  ButtonLink,
  Card,
  CardHeader,
  Field,
  Input,
  Modal,
  PageHeader,
  Segmented,
  Select,
  Textarea,
  Thumb,
  cn,
} from "@/components/ui";
import { fromDateInput, toDateInput } from "@/lib/format";
import { useStore } from "@/lib/store";
import type { Priority } from "@/lib/types";

// Shared with the job edit drawer.
export const PRODUCT_TYPES = ["Ring", "Engagement Ring", "Earrings", "Necklace", "Pendant", "Bracelet", "Bangle", "Brooch", "Other"];
export const METALS = ["18K Yellow Gold", "18K White Gold", "14K White Gold", "14K Rose Gold", "Platinum 950", "925 Silver"];
export const RING_SIZES = Array.from({ length: 21 }, (_, i) => `US ${3 + i / 2}`);
export const PRIORITY_OPTIONS: { value: Priority; label: string }[] = [
  { value: "standard", label: "Standard" },
  { value: "high", label: "High" },
  { value: "rush", label: "Rush" },
  { value: "critical", label: "Critical" },
];
export const isRing = (type: string) => /ring/i.test(type) && !/earring/i.test(type);

/** Reference images that ship with the panel (public/images). */
const LIBRARY = [
  "ring_gold_solitaire.jpg",
  "ring_gold_solitaire_2.jpg",
  "ring_oval_halo.jpg",
  "ring_halo_v1.jpg",
  "ring_halo_v2.jpg",
  "ring_emerald_cut_white.jpg",
  "ring_emerald_cut_dark.jpg",
  "ring_diamond_prongs.jpg",
  "ring_platinum_bench.jpg",
  "ring_solitaire_dark.jpg",
  "ring_gold_render.jpg",
  "cad_ring_monitor.jpg",
  "cad_pendant_sapphire.jpg",
  "cad_wireframe_halo.jpg",
  "cad_wireframe_green.jpg",
  "cad_mesh_green.jpg",
  "cad_halo_closeup.jpg",
  "cad_solitaire_screen.jpg",
  "cad_hand_view.jpg",
  "cad_blueprint.jpg",
  "wax_model_blue.jpg",
  "wax_model_signet.jpg",
  "gem_diamond.jpg",
  "gem_ruby.jpg",
];

/** Reads an image file as a data URL, scaled down so it fits comfortably in localStorage. */
export function readImage(file: File, max = 1280): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error);
    reader.onload = () => {
      const src = reader.result as string;
      const img = document.createElement("img");
      img.onerror = () => resolve(src);
      img.onload = () => {
        const k = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
        if (k === 1 && file.size < 400_000) return resolve(src);
        const canvas = document.createElement("canvas");
        canvas.width = Math.round(img.naturalWidth * k);
        canvas.height = Math.round(img.naturalHeight * k);
        canvas.getContext("2d")?.drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL("image/jpeg", 0.85));
      };
      img.src = src;
    };
    reader.readAsDataURL(file);
  });
}

interface Draft {
  title: string;
  customer: string;
  productType: string;
  metal: string;
  customMetal: boolean;
  centerStone: string;
  settingStyle: string;
  ringSize: string;
  weight: string;
  quantity: string;
  value: string;
  due: string;
  priority: Priority;
  image: string | null;
  notes: string;
}

const EMPTY: Draft = {
  title: "",
  customer: "",
  productType: "Ring",
  metal: METALS[0],
  customMetal: false,
  centerStone: "",
  settingStyle: "",
  ringSize: "",
  weight: "",
  quantity: "1",
  value: "",
  due: "",
  priority: "standard",
  image: null,
  notes: "",
};

type Errors = Partial<Record<"title" | "customer" | "due" | "value" | "metal", string>>;

function validate(d: Draft): Errors {
  const e: Errors = {};
  if (!d.title.trim()) e.title = "Give the piece a name.";
  if (!d.customer.trim()) e.customer = "Who is this for?";
  if (!d.due) e.due = "Pick a delivery date.";
  if (!(Number(d.value) > 0)) e.value = "Enter a target value above $0.";
  if (!d.metal.trim()) e.metal = "Enter the metal.";
  return e;
}

export function NewJobView() {
  const router = useRouter();
  const toast = useToast();
  const addJob = useStore((s) => s.addJob);
  const partners = useStore((s) => s.partners);
  const jobs = useStore((s) => s.jobs);
  const [d, setD] = useState<Draft>(EMPTY);
  const [tried, setTried] = useState(false);
  const [picker, setPicker] = useState(false);
  const [today] = useState(() => toDateInput(new Date().toISOString()));
  const fileRef = useRef<HTMLInputElement>(null);

  const errors = tried ? validate(d) : {};
  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((p) => ({ ...p, [k]: v }));

  const customers = useMemo(
    () =>
      [...new Set([...partners.filter((p) => p.role === "Retailer").map((p) => p.name), ...jobs.map((j) => j.customer)])].sort(),
    [partners, jobs],
  );

  const upload = async (file?: File) => {
    if (!file) return;
    if (!file.type.startsWith("image/")) return toast("Choose an image file (JPEG, PNG, WebP)");
    set("image", await readImage(file));
  };

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (Object.keys(validate(d)).length) {
      requestAnimationFrame(() => document.querySelector<HTMLElement>("[aria-invalid=true]")?.focus());
      return;
    }
    const ring = isRing(d.productType);
    const id = addJob({
      title: d.title.trim(),
      customer: d.customer.trim(),
      productType: d.productType,
      metal: d.metal.trim(),
      dueDate: fromDateInput(d.due),
      value: Number(d.value),
      priority: d.priority,
      centerStone: d.centerStone.trim() || "—",
      settingStyle: d.settingStyle.trim() || "—",
      ringSize: ring && d.ringSize ? d.ringSize : null,
      weightGrams: Number(d.weight) > 0 ? Number(d.weight) : null,
      quantity: Math.max(1, parseInt(d.quantity, 10) || 1),
      notes: d.notes.trim() || null,
      image: d.image,
    });
    toast(`${id} created — now at Inquiry`);
    router.push(`/jobs/${id}`);
  };

  return (
    <form id="new-job" onSubmit={submit} noValidate>
      <PageHeader
        eyebrow={<span className="text-accent">New Job Order · Drafting</span>}
        title="New Inquiry"
        subtitle="Capture the customer's brief. The job starts at Inquiry and moves through the 14-stage pipeline."
        actions={
          <>
            <ButtonLink href="/jobs" variant="secondary">
              Cancel
            </ButtonLink>
            <Button type="submit" icon={<Send size={16} />}>
              Create Job
            </Button>
          </>
        }
      />

      <div className="grid gap-6 lg:grid-cols-12">
        <div className="min-w-0 space-y-6 lg:col-span-7">
          <Card>
            <CardHeader
              title="Piece & Customer"
              subtitle="What is being made, and for whom."
              action={<span className="rounded bg-surface-high px-2 py-1 font-mono text-xs text-fg-muted">01/REQ</span>}
            />
            <div className="grid gap-4 p-5 sm:grid-cols-2">
              <Field label="Piece name *" className="sm:col-span-2">
                <Input
                  value={d.title}
                  onChange={(e) => set("title", e.target.value)}
                  placeholder="e.g. Solitaire Crown Ring"
                  aria-invalid={!!errors.title}
                  className={cn(errors.title && "ring-1 ring-danger")}
                />
                <FieldError msg={errors.title} />
              </Field>
              <Field label="Customer *" className="sm:col-span-2">
                <Input
                  value={d.customer}
                  onChange={(e) => set("customer", e.target.value)}
                  list="customer-options"
                  placeholder="Retailer or private client"
                  aria-invalid={!!errors.customer}
                  className={cn(errors.customer && "ring-1 ring-danger")}
                />
                <datalist id="customer-options">
                  {customers.map((c) => (
                    <option key={c} value={c} />
                  ))}
                </datalist>
                <FieldError msg={errors.customer} />
              </Field>
              <Field label="Product type">
                <Select value={d.productType} onChange={(e) => set("productType", e.target.value)}>
                  {PRODUCT_TYPES.map((t) => (
                    <option key={t}>{t}</option>
                  ))}
                </Select>
              </Field>
              <Field label="Quantity">
                <Input type="number" min={1} step={1} value={d.quantity} onChange={(e) => set("quantity", e.target.value)} className="font-mono" />
              </Field>
              <Field label="Briefing notes" className="sm:col-span-2">
                <Textarea
                  value={d.notes}
                  onChange={(e) => set("notes", e.target.value)}
                  placeholder="Design intent, references, anything the CAD designer and bench should know…"
                />
              </Field>
            </div>
          </Card>

          <Card>
            <CardHeader title="Reference Image" subtitle="Pick from the library or upload a sketch / photo." icon={<Images size={20} />} />
            <div className="grid gap-4 p-5 sm:grid-cols-2">
              <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-border bg-surface-low">
                {d.image ? (
                  <>
                    <Thumb src={d.image} alt="Reference" className="size-full" />
                    <button
                      type="button"
                      aria-label="Remove image"
                      onClick={() => set("image", null)}
                      className="absolute top-3 right-3 flex size-8 items-center justify-center rounded-full bg-danger text-white shadow-lg transition hover:opacity-90"
                    >
                      <X size={16} />
                    </button>
                  </>
                ) : (
                  <div className="flex size-full flex-col items-center justify-center gap-2 text-fg-faint">
                    <Diamond size={32} strokeWidth={1.5} />
                    <span className="text-sm">No reference yet</span>
                  </div>
                )}
              </div>
              <div className="grid gap-3">
                <button
                  type="button"
                  onClick={() => setPicker(true)}
                  className="flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border-strong bg-surface-low px-4 py-6 text-center transition hover:border-accent hover:bg-accent-soft/40"
                >
                  <span className="flex size-10 items-center justify-center rounded-lg bg-surface shadow-sm">
                    <Images size={19} />
                  </span>
                  <span className="text-sm font-semibold">Choose from library</span>
                  <span className="text-xs text-fg-muted">{LIBRARY.length} renders & bench photos</span>
                </button>
                <button
                  type="button"
                  onClick={() => fileRef.current?.click()}
                  className="flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border-strong bg-surface-low px-4 py-6 text-center transition hover:border-accent hover:bg-accent-soft/40"
                >
                  <span className="flex size-10 items-center justify-center rounded-lg bg-surface shadow-sm">
                    <ImagePlus size={19} />
                  </span>
                  <span className="text-sm font-semibold">Upload sketch</span>
                  <span className="text-xs text-fg-muted">JPEG, PNG or WebP</span>
                </button>
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  hidden
                  onChange={(e) => {
                    upload(e.target.files?.[0]);
                    e.target.value = "";
                  }}
                />
              </div>
            </div>
          </Card>
        </div>

        <div className="min-w-0 space-y-6 lg:col-span-5">
          <Card>
            <CardHeader title="Technical Specs" subtitle="Metal, stones and fit." />
            <div className="space-y-5 p-5">
              <div>
                <Label icon={<Ruler size={15} />}>Metal type</Label>
                <div className="flex flex-wrap gap-2">
                  {METALS.map((m) => (
                    <Chip key={m} on={!d.customMetal && d.metal === m} onClick={() => setD((p) => ({ ...p, metal: m, customMetal: false }))}>
                      {m}
                    </Chip>
                  ))}
                  <Chip on={d.customMetal} onClick={() => setD((p) => ({ ...p, metal: "", customMetal: true }))}>
                    Custom…
                  </Chip>
                </div>
                {d.customMetal && (
                  <div className="mt-3">
                    <Input
                      autoFocus
                      value={d.metal}
                      onChange={(e) => set("metal", e.target.value)}
                      placeholder="e.g. 22K Yellow Gold, Palladium 950"
                      aria-invalid={!!errors.metal}
                      className={cn(errors.metal && "ring-1 ring-danger")}
                    />
                    <FieldError msg={errors.metal} />
                  </div>
                )}
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Center stone">
                  <Input value={d.centerStone} onChange={(e) => set("centerStone", e.target.value)} placeholder="e.g. 2.4ct Lab Diamond" />
                </Field>
                <Field label="Setting style">
                  <Input value={d.settingStyle} onChange={(e) => set("settingStyle", e.target.value)} placeholder="e.g. 6-Prong Crown" />
                </Field>
                {isRing(d.productType) && (
                  <Field label="Ring size">
                    <Select value={d.ringSize} onChange={(e) => set("ringSize", e.target.value)}>
                      <option value="">Not specified</option>
                      {RING_SIZES.map((s) => (
                        <option key={s}>{s}</option>
                      ))}
                    </Select>
                  </Field>
                )}
                <Field label="Target weight (g)">
                  <Input
                    type="number"
                    min={0}
                    step={0.1}
                    value={d.weight}
                    onChange={(e) => set("weight", e.target.value)}
                    placeholder="e.g. 14.2"
                    className="font-mono"
                  />
                </Field>
              </div>
            </div>
          </Card>

          <Card className="border-t-2 border-t-accent">
            <CardHeader title="Logistics" subtitle="Budget, delivery and urgency." icon={<Truck size={20} />} />
            <div className="grid gap-4 p-5 sm:grid-cols-2">
              <Field label="Target value ($) *">
                <div className="relative">
                  <span className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 font-mono text-sm text-fg-faint">$</span>
                  <Input
                    type="number"
                    min={0}
                    step={50}
                    value={d.value}
                    onChange={(e) => set("value", e.target.value)}
                    placeholder="2500"
                    aria-invalid={!!errors.value}
                    className={cn("pl-7 font-mono", errors.value && "ring-1 ring-danger")}
                  />
                </div>
                <FieldError msg={errors.value} />
              </Field>
              <Field label="Due date *">
                <Input
                  type="date"
                  min={today}
                  value={d.due}
                  onChange={(e) => set("due", e.target.value)}
                  aria-invalid={!!errors.due}
                  className={cn("font-mono", errors.due && "ring-1 ring-danger")}
                />
                <FieldError msg={errors.due} />
              </Field>
              <div className="sm:col-span-2">
                <Label>Priority</Label>
                <Segmented options={PRIORITY_OPTIONS} value={d.priority} onChange={(v) => set("priority", v)} className="flex w-full [&>button]:flex-1" />
              </div>
            </div>
          </Card>

          <div className="flex gap-2">
            <ButtonLink href="/jobs" variant="secondary" className="flex-1">
              Cancel
            </ButtonLink>
            <Button type="submit" icon={<Send size={16} />} className="flex-[2]">
              Create Job
            </Button>
          </div>
          {tried && Object.keys(errors).length > 0 && (
            <p className="text-center text-sm text-danger">Fix the highlighted fields to create the job.</p>
          )}
        </div>
      </div>

      <Modal
        open={picker}
        onClose={() => setPicker(false)}
        title="Reference library"
        subtitle="Renders, CAD screens and bench photos. Or upload your own."
        size="lg"
        footer={
          <>
            <Button
              variant="secondary"
              icon={<Upload size={16} />}
              onClick={() => {
                setPicker(false);
                fileRef.current?.click();
              }}
            >
              Upload instead
            </Button>
            <Button onClick={() => setPicker(false)}>Done</Button>
          </>
        }
      >
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
          {LIBRARY.map((img) => {
            const on = d.image === img;
            return (
              <button
                key={img}
                type="button"
                onClick={() => {
                  set("image", img);
                  setPicker(false);
                }}
                className={cn(
                  "group relative overflow-hidden rounded-lg border-2 transition",
                  on ? "border-accent" : "border-transparent hover:border-border-strong",
                )}
                title={img}
              >
                <Thumb src={img} alt={img} className="aspect-square w-full" />
                {on && (
                  <span className="absolute top-1.5 right-1.5 flex size-6 items-center justify-center rounded-full bg-accent text-on-accent">
                    <Check size={14} />
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </Modal>
    </form>
  );
}

function FieldError({ msg }: { msg?: string }) {
  return msg ? <span className="mt-1 block text-xs font-semibold text-danger">{msg}</span> : null;
}

function Label({ icon, children }: { icon?: ReactNode; children: ReactNode }) {
  return (
    <div className="mb-2 flex items-center gap-2">
      {icon && <span className="text-fg-muted">{icon}</span>}
      <span className="label-caps">{children}</span>
    </div>
  );
}

function Chip({ on, onClick, children }: { on: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={on}
      className={cn(
        "rounded-lg border px-3 py-2 text-sm font-semibold transition",
        on ? "border-action bg-action text-on-action" : "border-border bg-surface text-fg hover:border-border-strong",
      )}
    >
      {children}
    </button>
  );
}
