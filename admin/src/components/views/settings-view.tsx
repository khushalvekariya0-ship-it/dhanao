"use client";

import { AlertTriangle, Bell, Building2, Info, ListChecks, LogOut, Moon, Palette, RotateCcw, Sun, UserRound } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, type FormEvent, type ReactNode } from "react";

import { useToast } from "@/components/toast";
import {
  Avatar,
  Badge,
  Button,
  Card,
  CardHeader,
  cn,
  ConfirmModal,
  Field,
  Input,
  PageHeader,
  Segmented,
  Select,
  Toggle,
} from "@/components/ui";
import { STAGES } from "@/lib/stages";
import { useStore } from "@/lib/store";
import type { AppSettings } from "@/lib/types";

const CURRENCIES = [
  { value: "USD", label: "USD — US Dollar ($)" },
  { value: "INR", label: "INR — Indian Rupee (₹)" },
  { value: "EUR", label: "EUR — Euro (€)" },
];

const TIMEZONES = [
  "Asia/Kolkata",
  "Asia/Dubai",
  "Asia/Singapore",
  "Asia/Hong_Kong",
  "Europe/London",
  "Europe/Brussels",
  "America/New_York",
  "America/Chicago",
  "America/Phoenix",
  "America/Los_Angeles",
  "UTC",
];

const NOTIFICATIONS: { key: "notifyStageChanges" | "notifyDelays" | "notifyApprovals"; label: string; description: string }[] = [
  { key: "notifyStageChanges", label: "Stage changes", description: "When a job moves to the next production stage." },
  { key: "notifyDelays", label: "Delays & risks", description: "When a job is flagged at risk or passes its due date." },
  { key: "notifyApprovals", label: "Approvals", description: "When a CAD design, price or final approval needs a decision." },
];

export function SettingsView() {
  const settings = useStore((s) => s.settings);
  const updateSettings = useStore((s) => s.updateSettings);
  const resetDemo = useStore((s) => s.resetDemo);
  const toast = useToast();
  const [confirmReset, setConfirmReset] = useState(false);

  return (
    <>
      <PageHeader eyebrow="Workspace" title="Settings" subtitle="Company details, appearance, notifications and demo data." />

      {/* Desktop: two columns. Mobile: the long stage list goes last. */}
      <div className="grid grid-cols-1 items-start gap-6 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <CompanyCard settings={settings} />
        </div>

        <div className="space-y-6 xl:col-start-3 xl:row-span-2 xl:row-start-1">
          <AccountCard />

          <Card>
            <CardHeader icon={<Palette size={18} />} title="Appearance" subtitle="Applies to this panel right away." />
            <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
              <span className="text-sm font-semibold">Theme</span>
              <Segmented
                value={settings.theme}
                onChange={(theme) => updateSettings({ theme })}
                options={[
                  {
                    value: "light",
                    label: (
                      <span className="flex items-center gap-1.5">
                        <Sun size={15} /> Light
                      </span>
                    ),
                  },
                  {
                    value: "dark",
                    label: (
                      <span className="flex items-center gap-1.5">
                        <Moon size={15} /> Dark
                      </span>
                    ),
                  },
                ]}
              />
            </div>
          </Card>

          <Card>
            <CardHeader icon={<Bell size={18} />} title="Notifications" subtitle="What shows up in the bell menu." />
            <div className="divide-y divide-border">
              {NOTIFICATIONS.map((n) => (
                <div key={n.key} className="flex items-center justify-between gap-4 px-5 py-4">
                  <div>
                    <div className="text-sm font-semibold">{n.label}</div>
                    <div className="text-xs text-fg-muted">{n.description}</div>
                  </div>
                  <Toggle
                    checked={settings[n.key]}
                    label={n.label}
                    onChange={(v) => {
                      updateSettings({ [n.key]: v });
                      toast(`${n.label} notifications ${v ? "on" : "off"}`);
                    }}
                  />
                </div>
              ))}
            </div>
          </Card>

          <Card className="border-danger/40">
            <div className="flex items-start gap-3 border-b border-danger/20 px-5 py-4">
              <AlertTriangle size={18} className="mt-0.5 text-danger" />
              <div>
                <h2 className="text-base font-semibold text-danger">Danger zone</h2>
                <p className="mt-0.5 text-sm text-fg-muted">Actions here can&apos;t be undone.</p>
              </div>
            </div>
            <div className="space-y-3 px-5 py-4">
              <div>
                <div className="text-sm font-semibold">Reset demo data</div>
                <p className="mt-1 text-sm text-fg-muted">
                  Restores the sample jobs, partners, inventory and users. Your settings and the current sign-in are kept.
                </p>
              </div>
              <Button variant="danger" icon={<RotateCcw size={15} />} onClick={() => setConfirmReset(true)}>
                Reset demo data
              </Button>
            </div>
          </Card>
        </div>

        <div className="xl:col-span-2">
          <StagesCard />
        </div>
      </div>

      <ConfirmModal
        open={confirmReset}
        onClose={() => setConfirmReset(false)}
        danger
        title="Reset demo data?"
        confirmLabel="Reset data"
        message="Jobs, partners, inventory and users go back to the sample data, and any changes you made to them are lost. Company settings, appearance, notifications and your session stay as they are."
        onConfirm={() => {
          resetDemo();
          toast("Demo data restored");
        }}
      />
    </>
  );
}

// ---------------------------------------------------------------------------

type CompanyForm = Pick<AppSettings, "companyName" | "currency" | "timezone"> & { dueSoonDays: string };

const toForm = (s: AppSettings): CompanyForm => ({
  companyName: s.companyName,
  currency: s.currency,
  timezone: s.timezone,
  dueSoonDays: String(s.dueSoonDays),
});

function CompanyCard({ settings }: { settings: AppSettings }) {
  const updateSettings = useStore((s) => s.updateSettings);
  const toast = useToast();
  const [form, setForm] = useState<CompanyForm>(() => toForm(settings));
  const saved = toForm(settings);
  const dirty = (Object.keys(form) as (keyof CompanyForm)[]).some((k) => form[k] !== saved[k]);

  const days = Number(form.dueSoonDays);
  const errors: Partial<Record<"companyName" | "dueSoonDays", string>> = {};
  if (!form.companyName.trim()) errors.companyName = "Company name is required.";
  if (!Number.isInteger(days) || days < 1 || days > 60) errors.dueSoonDays = "Enter a whole number from 1 to 60.";

  const set = <K extends keyof CompanyForm>(k: K, v: CompanyForm[K]) => setForm((f) => ({ ...f, [k]: v }));
  const timezones = TIMEZONES.includes(form.timezone) ? TIMEZONES : [form.timezone, ...TIMEZONES];

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (Object.keys(errors).length) return;
    updateSettings({
      companyName: form.companyName.trim(),
      currency: form.currency,
      timezone: form.timezone,
      dueSoonDays: days,
    });
    setForm((f) => ({ ...f, companyName: f.companyName.trim() }));
    toast("Company settings saved");
  };

  return (
    <Card>
      <CardHeader icon={<Building2 size={18} />} title="Company" subtitle="Shown on new jobs and used for dates and due-soon alerts." />
      <form onSubmit={submit} noValidate>
        <div className="grid grid-cols-1 gap-4 px-5 py-5 sm:grid-cols-2">
          <Field label="Company name" className="sm:col-span-2" hint={<Err>{errors.companyName}</Err>}>
            <Input
              value={form.companyName}
              onChange={(e) => set("companyName", e.target.value)}
              className={cn(errors.companyName && "border-danger focus:border-danger focus:ring-danger/20")}
            />
          </Field>
          <Field label="Currency">
            <Select value={form.currency} onChange={(e) => set("currency", e.target.value)}>
              {CURRENCIES.map((c) => (
                <option key={c.value} value={c.value}>
                  {c.label}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Timezone">
            <Select value={form.timezone} onChange={(e) => set("timezone", e.target.value)}>
              {timezones.map((t) => (
                <option key={t} value={t}>
                  {t.replace(/_/g, " ")}
                </option>
              ))}
            </Select>
          </Field>
          <Field
            label="Due soon (days)"
            hint={errors.dueSoonDays ? <Err>{errors.dueSoonDays}</Err> : "Jobs due within this many days are flagged as due soon."}
          >
            <Input
              type="number"
              min={1}
              max={60}
              step={1}
              value={form.dueSoonDays}
              onChange={(e) => set("dueSoonDays", e.target.value)}
              className={cn("font-mono", errors.dueSoonDays && "border-danger focus:border-danger focus:ring-danger/20")}
            />
          </Field>
        </div>
        <div className="flex items-center justify-end gap-2 border-t border-border px-5 py-3">
          {dirty && <span className="mr-auto text-xs text-fg-muted">Unsaved changes</span>}
          <Button variant="ghost" disabled={!dirty} onClick={() => setForm(toForm(settings))}>
            Discard
          </Button>
          <Button type="submit" disabled={!dirty || Object.keys(errors).length > 0}>
            Save changes
          </Button>
        </div>
      </form>
    </Card>
  );
}

function StagesCard() {
  return (
    <Card>
      <CardHeader
        icon={<ListChecks size={18} />}
        title="Production stages"
        subtitle={`${STAGES.length} stages from inquiry to delivery.`}
        action={<Badge>Read-only</Badge>}
      />
      <div className="flex items-start gap-2.5 border-b border-border bg-surface-low px-5 py-3 text-sm text-fg-muted">
        <Info size={16} className="mt-0.5 shrink-0 text-accent" />
        Stages are defined by the mobile app. Their owners and checklists are shown here for reference.
      </div>
      <ol className="divide-y divide-border">
        {STAGES.map((s) => (
          <li key={s.key} className="flex items-center gap-4 px-5 py-3">
            <span className="w-6 shrink-0 font-mono text-xs text-fg-faint">{String(s.index + 1).padStart(2, "0")}</span>
            <span className="size-2.5 shrink-0 rounded-full" style={{ background: s.color }} />
            <div className="min-w-0 flex-1">
              <div className="text-sm font-semibold">{s.label}</div>
              <div className="truncate text-xs text-fg-muted sm:hidden">{s.owner}</div>
              <div className="hidden truncate text-xs text-fg-faint sm:block">{s.summary}</div>
            </div>
            <span className="hidden w-52 shrink-0 truncate text-sm text-fg-muted sm:block">{s.owner}</span>
            <span
              className="shrink-0 font-mono text-xs whitespace-nowrap text-fg-muted"
              title={s.checklist.map((c) => `• ${c}`).join("\n")}
            >
              {s.checklist.length} checks
            </span>
          </li>
        ))}
      </ol>
    </Card>
  );
}

function AccountCard() {
  const session = useStore((s) => s.session);
  const user = useStore((s) => s.users.find((u) => u.id === s.session?.userId));
  const logout = useStore((s) => s.logout);
  const router = useRouter();
  if (!session) return null;

  return (
    <Card>
      <CardHeader icon={<UserRound size={18} />} title="Account" subtitle="You're signed in as" />
      <div className="flex items-center gap-4 px-5 py-4">
        <Avatar name={session.name} src={user?.avatar} size={48} dark />
        <div className="min-w-0 flex-1">
          <div className="truncate font-semibold">{session.name}</div>
          <div className="truncate text-sm text-fg-muted">{session.email}</div>
          <div className="mt-1.5">
            <Badge tone="accent" mono={false}>
              {session.role}
            </Badge>
          </div>
        </div>
      </div>
      <Row label="Access">Admin panel & mobile app</Row>
      <div className="border-t border-border px-5 py-4">
        <Button
          variant="secondary"
          className="w-full"
          icon={<LogOut size={15} />}
          onClick={() => {
            logout();
            router.replace("/login");
          }}
        >
          Sign out
        </Button>
      </div>
    </Card>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 border-t border-border px-5 py-3 text-sm">
      <span className="label-caps">{label}</span>
      <span className="text-right text-fg-muted">{children}</span>
    </div>
  );
}

function Err({ children }: { children?: string }) {
  return children ? <span className="text-danger">{children}</span> : null;
}
