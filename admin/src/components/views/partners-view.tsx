"use client";

import {
  Briefcase,
  Building2,
  LayoutGrid,
  List,
  Mail,
  MapPin,
  Network,
  Pencil,
  Phone,
  Plus,
  Search,
  Star,
  Trash2,
} from "lucide-react";
import Link from "next/link";
import { useMemo, useState, type FormEvent, type ReactNode } from "react";

import { useToast } from "@/components/toast";
import {
  Avatar,
  Badge,
  Button,
  cn,
  ConfirmModal,
  Drawer,
  EmptyState,
  Field,
  IconButton,
  Input,
  Modal,
  PageHeader,
  Segmented,
  Select,
  StageBadge,
  Table,
  TD,
  TH,
  Thumb,
} from "@/components/ui";
import { newId, useStore } from "@/lib/store";
import type { Job, Partner } from "@/lib/types";

// ---------------------------------------------------------------------------
// Partner types are derived from the free-text role.

const TYPES = ["Design", "Casting", "Stones", "Retail", "Lab/QC", "Logistics"] as const;
type PartnerType = (typeof TYPES)[number] | "Other";

const TYPE_RULES: [PartnerType, RegExp][] = [
  ["Lab/QC", /lab|qc|quality|certif|grading/i],
  ["Design", /design|cad/i],
  ["Casting", /cast|foundry|wax|print/i],
  ["Stones", /stone|gem|diamond|setter|setting/i],
  ["Retail", /retail|boutique|store|client/i],
  ["Logistics", /logistic|courier|shipping|transport|dispatch/i],
];

const partnerType = (role: string): PartnerType => TYPE_RULES.find(([, re]) => re.test(role))?.[0] ?? "Other";

const COMMON_ROLES = [
  "Lead Designer",
  "CAD Designer",
  "3D Print Bureau",
  "Casting",
  "Stone Provider",
  "Setter",
  "Bench Jeweler",
  "Polisher",
  "QC Specialist",
  "Gem Lab",
  "Retailer",
  "Courier",
];
const OTHER_ROLE = "__other";

const AVATARS = ["avatar_sarah.jpg", "avatar_patel.jpg", "avatar_ravi.jpg"];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const same = (a?: string | null, b?: string | null) => !!a && !!b && a.trim().toLowerCase() === b.trim().toLowerCase();

/** Jobs that name this partner as assignee or customer. */
const jobsFor = (p: Partner, jobs: Job[]) => jobs.filter((j) => same(j.assignee, p.name) || same(j.customer, p.name));

/** Live count from linked jobs; falls back to the figure reported by the app. */
const activeJobs = (p: Partner, linked: Job[]) =>
  linked.length ? linked.filter((j) => j.stage !== "delivered").length : p.activeJobs;

// ---------------------------------------------------------------------------

export function PartnersView() {
  const partners = useStore((s) => s.partners);
  const jobs = useStore((s) => s.jobs);
  const deletePartner = useStore((s) => s.deletePartner);
  const toast = useToast();

  const [q, setQ] = useState("");
  const [type, setType] = useState<"All" | PartnerType>("All");
  const [view, setView] = useState<"grid" | "table">("grid");
  const [openId, setOpenId] = useState<string | null>(null);
  const [editing, setEditing] = useState<Partner | "new" | null>(null);
  const [deleting, setDeleting] = useState<Partner | null>(null);

  const linked = useMemo(() => new Map(partners.map((p) => [p.id, jobsFor(p, jobs)])), [partners, jobs]);
  const byType = useMemo(() => {
    const out: Record<string, { count: number; jobs: number }> = {};
    for (const p of partners) {
      const t = partnerType(p.role);
      out[t] ??= { count: 0, jobs: 0 };
      out[t].count += 1;
      out[t].jobs += activeJobs(p, linked.get(p.id) ?? []);
    }
    return out;
  }, [partners, linked]);

  const shown = useMemo(() => {
    const t = q.trim().toLowerCase();
    return partners.filter(
      (p) =>
        (type === "All" || partnerType(p.role) === type) &&
        (!t || [p.name, p.role, p.company, p.location, p.phone, p.email].some((v) => v?.toLowerCase().includes(t))),
    );
  }, [partners, q, type]);

  const avgRating = partners.length ? partners.reduce((a, p) => a + p.rating, 0) / partners.length : 0;
  const open = partners.find((p) => p.id === openId);

  return (
    <>
      <PageHeader
        eyebrow="Network hub"
        title="Partners"
        subtitle="Designers, casting houses, stone suppliers, labs, couriers and retailers you work with."
        actions={
          <Button icon={<Plus size={16} />} onClick={() => setEditing("new")}>
            Add Partner
          </Button>
        }
      />

      {/* Stat row: total + by type */}
      <div className="mb-6 grid grid-cols-2 gap-px overflow-hidden rounded-xl border border-border bg-border sm:grid-cols-4 lg:grid-cols-7">
        <div className="col-span-2 bg-surface p-4 lg:col-span-1">
          <div className="label-caps">Total partners</div>
          <div className="mt-2 text-3xl font-semibold tracking-tight">{partners.length}</div>
          <div className="mt-1 flex items-center gap-1 text-xs text-fg-muted">
            <Star size={12} className="fill-gold text-gold" />
            <span className="font-mono">{avgRating.toFixed(1)}</span> avg rating
          </div>
        </div>
        {TYPES.map((t) => (
          <div key={t} className="bg-surface p-4">
            <div className="label-caps">{t}</div>
            <div className="mt-2 text-2xl font-semibold tracking-tight">{byType[t]?.count ?? 0}</div>
            <div className="mt-1 text-xs text-fg-muted">
              <span className="font-mono">{byType[t]?.jobs ?? 0}</span> active jobs
            </div>
          </div>
        ))}
      </div>

      {/* Toolbar */}
      <div className="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center">
        <div className="relative w-full lg:max-w-xs">
          <Search size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, company, location…" className="pl-9" />
        </div>
        <div className="flex flex-1 flex-wrap gap-2">
          {(["All", ...TYPES] as const).map((t) => (
            <Chip key={t} active={type === t} onClick={() => setType(t)}>
              {t}
              <span className="font-mono opacity-70">{t === "All" ? partners.length : (byType[t]?.count ?? 0)}</span>
            </Chip>
          ))}
          {(byType.Other?.count ?? 0) > 0 && (
            <Chip active={type === "Other"} onClick={() => setType("Other")}>
              Other <span className="font-mono opacity-70">{byType.Other.count}</span>
            </Chip>
          )}
        </div>
        <Segmented
          value={view}
          onChange={setView}
          options={[
            { value: "grid", label: <LayoutGrid size={16} aria-label="Grid view" /> },
            { value: "table", label: <List size={16} aria-label="Table view" /> },
          ]}
          className="self-start lg:self-auto"
        />
      </div>

      {shown.length === 0 ? (
        <div className="rounded-xl border border-border bg-surface">
          <EmptyState
            icon={<Network size={32} />}
            title="No partners found"
            message={partners.length ? "Try a different search or type filter." : "Add the studios, suppliers and couriers you work with."}
            action={
              partners.length ? (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setQ("");
                    setType("All");
                  }}
                >
                  Clear filters
                </Button>
              ) : (
                <Button icon={<Plus size={16} />} onClick={() => setEditing("new")}>
                  Add Partner
                </Button>
              )
            }
          />
        </div>
      ) : view === "grid" ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {shown.map((p) => (
            <PartnerCard key={p.id} partner={p} active={activeJobs(p, linked.get(p.id) ?? [])} onOpen={() => setOpenId(p.id)} />
          ))}
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-border bg-surface">
          <Table>
            <thead>
              <tr>
                <TH>Partner</TH>
                <TH>Role</TH>
                <TH>Location</TH>
                <TH>Contact</TH>
                <TH>Rating</TH>
                <TH className="text-right">Active jobs</TH>
                <TH className="w-24" />
              </tr>
            </thead>
            <tbody>
              {shown.map((p) => (
                <tr key={p.id} onClick={() => setOpenId(p.id)} className="cursor-pointer transition hover:bg-surface-low">
                  <TD>
                    <div className="flex items-center gap-3">
                      <Avatar name={p.name} src={p.avatar} size={36} dark />
                      <div className="min-w-0">
                        <div className="font-semibold whitespace-nowrap">{p.name}</div>
                        <div className="text-xs whitespace-nowrap text-fg-muted">{p.company || "—"}</div>
                      </div>
                    </div>
                  </TD>
                  <TD>
                    <RoleText role={p.role} />
                  </TD>
                  <TD className="whitespace-nowrap text-fg-muted">{p.location || "—"}</TD>
                  <TD className="text-xs whitespace-nowrap text-fg-muted">
                    <div>{p.phone || "—"}</div>
                    {p.email && <div>{p.email}</div>}
                  </TD>
                  <TD>
                    <Rating value={p.rating} />
                  </TD>
                  <TD className="text-right font-mono font-semibold">{activeJobs(p, linked.get(p.id) ?? [])}</TD>
                  <TD>
                    <div className="flex justify-end" onClick={(e) => e.stopPropagation()}>
                      <IconButton label={`Edit ${p.name}`} onClick={() => setEditing(p)}>
                        <Pencil size={15} />
                      </IconButton>
                      <IconButton label={`Delete ${p.name}`} onClick={() => setDeleting(p)} className="hover:text-danger">
                        <Trash2 size={15} />
                      </IconButton>
                    </div>
                  </TD>
                </tr>
              ))}
            </tbody>
          </Table>
        </div>
      )}

      {open && (
        <PartnerDrawer
          partner={open}
          jobs={linked.get(open.id) ?? []}
          onClose={() => setOpenId(null)}
          onEdit={() => setEditing(open)}
          onDelete={() => setDeleting(open)}
        />
      )}

      {editing && (
        <PartnerForm
          key={editing === "new" ? "new" : editing.id}
          partner={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
        />
      )}

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        danger
        title="Delete partner?"
        confirmLabel="Delete partner"
        message={
          <>
            <strong className="text-fg">{deleting?.name}</strong> will be removed from your partner network. Jobs that
            mention them keep their history.
          </>
        }
        onConfirm={() => {
          if (!deleting) return;
          deletePartner(deleting.id);
          if (openId === deleting.id) setOpenId(null);
          toast(`${deleting.name} removed from partners`);
        }}
      />
    </>
  );
}

// ---------------------------------------------------------------------------
// Pieces

function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        "inline-flex h-8 items-center gap-1.5 rounded-lg border px-3 text-xs font-semibold transition",
        active
          ? "border-transparent bg-nav-active text-on-nav-active"
          : "border-border bg-surface text-fg-muted hover:border-border-strong hover:text-fg",
      )}
    >
      {children}
    </button>
  );
}

function RoleText({ role }: { role: string }) {
  return <span className="font-mono text-[11px] font-bold tracking-wider whitespace-nowrap text-accent uppercase">{role}</span>;
}

function Rating({ value }: { value: number }) {
  return (
    <span className="inline-flex items-center gap-1" title={`Rated ${value.toFixed(1)} of 5`}>
      <Star size={13} className="fill-gold text-gold" />
      <span className="font-mono text-sm font-semibold">{value.toFixed(1)}</span>
    </span>
  );
}

function ContactLine({ icon, children }: { icon: ReactNode; children: ReactNode }) {
  return (
    <div className="flex min-w-0 items-center gap-2">
      <span className="shrink-0 text-fg-faint">{icon}</span>
      <span className="truncate">{children}</span>
    </div>
  );
}

function PartnerCard({ partner: p, active, onOpen }: { partner: Partner; active: number; onOpen: () => void }) {
  const hasContact = p.location || p.phone || p.email;
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onOpen}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen();
        }
      }}
      className="flex cursor-pointer flex-col rounded-xl border border-border bg-surface p-5 text-left transition outline-none hover:border-border-strong focus-visible:ring-2 focus-visible:ring-accent/40"
    >
      <div className="flex items-start gap-4">
        <Avatar name={p.name} src={p.avatar} size={52} dark />
        <div className="min-w-0 flex-1">
          <div className="truncate font-semibold">{p.name}</div>
          <RoleText role={p.role} />
          <div className="mt-0.5 truncate text-sm text-fg-muted">{p.company || "Independent"}</div>
        </div>
        <Rating value={p.rating} />
      </div>
      <div className="mt-4 flex-1 space-y-1.5 text-sm text-fg-muted">
        {p.location && <ContactLine icon={<MapPin size={14} />}>{p.location}</ContactLine>}
        {p.phone && <ContactLine icon={<Phone size={14} />}>{p.phone}</ContactLine>}
        {p.email && <ContactLine icon={<Mail size={14} />}>{p.email}</ContactLine>}
        {!hasContact && <p className="text-fg-faint">No contact details yet.</p>}
      </div>
      <div className="mt-4 flex items-center justify-between border-t border-border pt-3">
        <span className="label-caps">Active jobs</span>
        <span className={cn("font-mono text-lg font-semibold", active > 0 ? "text-fg" : "text-fg-faint")}>{active}</span>
      </div>
    </div>
  );
}

function PartnerDrawer({
  partner: p,
  jobs,
  onClose,
  onEdit,
  onDelete,
}: {
  partner: Partner;
  jobs: Job[];
  onClose: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const active = activeJobs(p, jobs);
  const contact: { icon: ReactNode; label: string; value?: string | null; href?: string }[] = [
    { icon: <Building2 size={16} />, label: "Company", value: p.company },
    { icon: <MapPin size={16} />, label: "Location", value: p.location },
    { icon: <Phone size={16} />, label: "Phone", value: p.phone, href: p.phone ? `tel:${p.phone.replace(/[^\d+]/g, "")}` : undefined },
    { icon: <Mail size={16} />, label: "Email", value: p.email, href: p.email ? `mailto:${p.email}` : undefined },
  ];
  return (
    <Drawer
      open
      onClose={onClose}
      title={p.name}
      subtitle={<RoleText role={p.role} />}
      width={520}
      footer={
        <>
          <Button variant="danger" icon={<Trash2 size={15} />} onClick={onDelete}>
            Delete
          </Button>
          <Button icon={<Pencil size={15} />} onClick={onEdit}>
            Edit partner
          </Button>
        </>
      }
    >
      <div className="flex items-center gap-4">
        <Avatar name={p.name} src={p.avatar} size={64} dark />
        <div className="min-w-0">
          <div className="text-lg font-semibold">{p.company && !same(p.company, p.name) ? p.company : p.location || p.name}</div>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <Badge tone="accent">{partnerType(p.role)}</Badge>
            <Rating value={p.rating} />
          </div>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-3 gap-3">
        {[
          { label: "Active jobs", value: active },
          { label: "Linked jobs", value: jobs.length },
          { label: "Rating", value: p.rating.toFixed(1) },
        ].map((s) => (
          <div key={s.label} className="rounded-lg border border-border bg-surface p-3">
            <div className="label-caps text-[10px]">{s.label}</div>
            <div className="mt-1 font-mono text-xl font-semibold">{s.value}</div>
          </div>
        ))}
      </div>

      <h3 className="label-caps mt-6 mb-2">Contact</h3>
      <div className="divide-y divide-border rounded-lg border border-border bg-surface">
        {contact.map((c) => (
          <div key={c.label} className="flex items-center gap-3 px-4 py-3">
            <span className="text-fg-faint">{c.icon}</span>
            <span className="w-20 shrink-0 text-xs text-fg-muted">{c.label}</span>
            {c.value ? (
              c.href ? (
                <a href={c.href} className="min-w-0 truncate text-sm font-semibold text-accent hover:underline">
                  {c.value}
                </a>
              ) : (
                <span className="min-w-0 truncate text-sm font-semibold">{c.value}</span>
              )
            ) : (
              <span className="text-sm text-fg-faint">Not provided</span>
            )}
          </div>
        ))}
      </div>

      <h3 className="label-caps mt-6 mb-2">Jobs ({jobs.length})</h3>
      {jobs.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border-strong px-4 py-6 text-center text-sm text-fg-muted">
          No jobs name {p.name} as assignee or customer.
          {p.activeJobs > 0 && (
            <span className="mt-1 block text-xs text-fg-faint">The mobile app reports {p.activeJobs} active jobs for this partner.</span>
          )}
        </div>
      ) : (
        <div className="space-y-2">
          {jobs.map((j) => (
            <Link
              key={j.id}
              href={`/jobs/${j.id}`}
              className="flex items-center gap-3 rounded-lg border border-border bg-surface p-3 transition hover:border-border-strong"
            >
              <Thumb src={j.image} alt={j.title} className="size-11 shrink-0" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs font-semibold text-accent">{j.id}</span>
                  <span className="text-[10px] font-semibold tracking-wide text-fg-faint uppercase">
                    {same(j.assignee, p.name) ? "Assignee" : "Customer"}
                  </span>
                </div>
                <div className="truncate text-sm font-semibold">{j.title}</div>
              </div>
              <StageBadge stage={j.stage} />
            </Link>
          ))}
        </div>
      )}
      {jobs.length > 0 && (
        <p className="mt-3 flex items-center gap-1.5 text-xs text-fg-faint">
          <Briefcase size={12} /> Jobs are matched on the partner name.
        </p>
      )}
    </Drawer>
  );
}

// ---------------------------------------------------------------------------
// Add / edit form

type Errors = Partial<Record<"name" | "role" | "email" | "phone" | "rating", string>>;

function PartnerForm({ partner, onClose }: { partner: Partner | null; onClose: () => void }) {
  const partners = useStore((s) => s.partners);
  const savePartner = useStore((s) => s.savePartner);
  const toast = useToast();

  const knownRole = !partner || COMMON_ROLES.includes(partner.role);
  const [name, setName] = useState(partner?.name ?? "");
  const [roleChoice, setRoleChoice] = useState(partner ? (knownRole ? partner.role : OTHER_ROLE) : COMMON_ROLES[0]);
  const [customRole, setCustomRole] = useState(knownRole ? "" : (partner?.role ?? ""));
  const [company, setCompany] = useState(partner?.company ?? "");
  const [location, setLocation] = useState(partner?.location ?? "");
  const [phone, setPhone] = useState(partner?.phone ?? "");
  const [email, setEmail] = useState(partner?.email ?? "");
  const [rating, setRating] = useState(String(partner?.rating ?? 5));
  const [avatar, setAvatar] = useState<string | null>(partner?.avatar ?? null);
  const [tried, setTried] = useState(false);

  const role = (roleChoice === OTHER_ROLE ? customRole : roleChoice).trim();
  const r = Number(rating);
  const errors: Errors = {};
  if (!name.trim()) errors.name = "Name is required.";
  else if (partners.some((p) => p.id !== partner?.id && same(p.name, name))) errors.name = "A partner with this name already exists.";
  if (!role) errors.role = "Enter a role.";
  if (email.trim() && !EMAIL.test(email.trim())) errors.email = "Enter a valid email address.";
  if (phone.trim() && !/^\+?[\d\s().-]{6,}$/.test(phone.trim())) errors.phone = "Enter a valid phone number.";
  if (rating.trim() === "" || Number.isNaN(r) || r < 0 || r > 5) errors.rating = "Rating must be between 0 and 5.";
  const err = (k: keyof Errors) => (tried ? errors[k] : undefined);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (Object.keys(errors).length) return;
    savePartner({
      id: partner?.id ?? newId("p"),
      name: name.trim(),
      role,
      company: company.trim() || null,
      location: location.trim() || null,
      phone: phone.trim() || null,
      email: email.trim() || null,
      rating: Math.round(r * 10) / 10,
      avatar,
      activeJobs: partner?.activeJobs ?? 0,
    });
    toast(partner ? `${name.trim()} updated` : `${name.trim()} added to partners`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={partner ? "Edit partner" : "Add partner"}
      subtitle={partner ? partner.name : "Studios, suppliers, labs, couriers or retailers."}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="partner-form">
            {partner ? "Save changes" : "Add partner"}
          </Button>
        </>
      }
    >
      <form id="partner-form" onSubmit={submit} noValidate className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="Name *" hint={<ErrorText>{err("name")}</ErrorText>} className="sm:col-span-2">
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Patel Casting Works" autoFocus aria-invalid={!!err("name")} className={invalidCls(err("name"))} />
        </Field>
        <Field label="Role *" hint={<ErrorText>{err("role")}</ErrorText>} className={cn(roleChoice !== OTHER_ROLE && "sm:col-span-2")}>
          <Select value={roleChoice} onChange={(e) => setRoleChoice(e.target.value)}>
            {COMMON_ROLES.map((x) => (
              <option key={x} value={x}>
                {x}
              </option>
            ))}
            <option value={OTHER_ROLE}>Other (type a role)…</option>
          </Select>
        </Field>
        {roleChoice === OTHER_ROLE && (
          <Field label="Custom role *">
            <Input value={customRole} onChange={(e) => setCustomRole(e.target.value)} placeholder="e.g. Engraver" aria-invalid={!!err("role")} className={invalidCls(err("role"))} />
          </Field>
        )}
        <Field label="Company">
          <Input value={company} onChange={(e) => setCompany(e.target.value)} placeholder="Company name" />
        </Field>
        <Field label="Location">
          <Input value={location} onChange={(e) => setLocation(e.target.value)} placeholder="City, Country" />
        </Field>
        <Field label="Phone" hint={<ErrorText>{err("phone")}</ErrorText>}>
          <Input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+91 98200 11223" aria-invalid={!!err("phone")} className={invalidCls(err("phone"))} />
        </Field>
        <Field label="Email" hint={<ErrorText>{err("email")}</ErrorText>}>
          <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@company.com" aria-invalid={!!err("email")} className={invalidCls(err("email"))} />
        </Field>
        <Field label="Rating (0–5)" hint={<ErrorText>{err("rating")}</ErrorText>}>
          <Input type="number" min={0} max={5} step={0.1} value={rating} onChange={(e) => setRating(e.target.value)} aria-invalid={!!err("rating")} className={invalidCls(err("rating"))} />
        </Field>
        <div className="sm:col-span-2">
          <span className="label-caps mb-1.5 block">Avatar</span>
          <div className="flex flex-wrap gap-3">
            {[null, ...AVATARS].map((a) => (
              <button
                key={a ?? "none"}
                type="button"
                onClick={() => setAvatar(a)}
                aria-pressed={avatar === a}
                title={a ?? "Initials"}
                className={cn(
                  "rounded-full p-0.5 ring-2 transition",
                  avatar === a ? "ring-accent" : "ring-transparent hover:ring-border-strong",
                )}
              >
                <Avatar name={name || "?"} src={a} size={44} dark />
              </button>
            ))}
          </div>
          <span className="mt-1 block text-xs text-fg-faint">Pick a photo or use initials.</span>
        </div>
      </form>
    </Modal>
  );
}

function ErrorText({ children }: { children?: string }) {
  return children ? <span className="text-danger">{children}</span> : null;
}

const invalidCls = (error?: string) => (error ? "border-danger focus:border-danger focus:ring-danger/20" : undefined);
