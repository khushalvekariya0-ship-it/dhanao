"use client";

import {
  ArrowRight,
  Boxes,
  CircleAlert,
  Eye,
  EyeOff,
  History,
  Loader2,
  Lock,
  Mail,
  Moon,
  ShieldCheck,
  Sun,
  Workflow,
} from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type FormEvent, type KeyboardEvent, type ReactNode } from "react";

import { Button, cn, Modal } from "@/components/ui";
import { daysUntil, money, setCurrency } from "@/lib/format";
import { DEMO_LOGIN } from "@/lib/seed";
import { STAGES, stageIndex } from "@/lib/stages";
import { hasSessionCookie, useHydrated, useStore } from "@/lib/store";

const GOLD = "#f2ca50";

export function LoginView() {
  const hydrated = useHydrated();
  const session = useStore((s) => s.session);
  const login = useStore((s) => s.login);
  const logout = useStore((s) => s.logout);
  const theme = useStore((s) => s.settings.theme);
  const updateSettings = useStore((s) => s.updateSettings);
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [show, setShow] = useState(false);
  const [caps, setCaps] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [shake, setShake] = useState(0);
  const [busy, setBusy] = useState(false);
  const [forgot, setForgot] = useState(false);

  // Already signed in → dashboard. A stored session without the cookie (browser closed
  // without "remember me") is stale: clear it so the proxy and the page agree.
  useEffect(() => {
    if (!hydrated || !session) return;
    if (hasSessionCookie()) router.replace("/");
    else logout();
  }, [hydrated, session, router, logout]);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
  }, [theme]);

  const signIn = (e?: string, p?: string) => {
    setBusy(true);
    setError(null);
    // Short pause so the button state is visible; the check itself is instant.
    setTimeout(() => {
      const err = login(e ?? email, p ?? password, remember);
      if (err) {
        setError(err);
        setShake((n) => n + 1);
        setBusy(false);
      } else {
        router.replace("/");
      }
    }, 450);
  };

  const submit = (ev: FormEvent) => {
    ev.preventDefault();
    signIn();
  };

  const useDemo = () => {
    setEmail(DEMO_LOGIN.email);
    setPassword(DEMO_LOGIN.password);
    signIn(DEMO_LOGIN.email, DEMO_LOGIN.password);
  };

  const onPasswordKey = (ev: KeyboardEvent<HTMLInputElement>) => setCaps(ev.getModifierState("CapsLock"));

  return (
    <div className="flex min-h-screen bg-bg">
      <BrandPanel hydrated={hydrated} />

      <div className="flex min-h-screen flex-1 flex-col">
        <header className="flex items-center justify-between px-6 py-5 sm:px-10">
          <div className="flex items-center gap-2.5 lg:invisible">
            <Image src="/images/logo.png" alt="" width={32} height={32} className="rounded-lg" />
            <span className="text-lg font-semibold tracking-tight">DhanaOS</span>
          </div>
          <button
            type="button"
            onClick={() => updateSettings({ theme: theme === "dark" ? "light" : "dark" })}
            className="inline-flex h-9 items-center gap-2 rounded-full border border-border px-3 text-xs font-semibold text-fg-muted transition hover:border-border-strong hover:text-fg"
          >
            {theme === "dark" ? <Sun size={14} /> : <Moon size={14} />}
            {theme === "dark" ? "Light" : "Dark"}
          </button>
        </header>

        <main className="flex flex-1 items-center justify-center px-6 pb-10 sm:px-10">
          <div key={shake} className={cn("w-full max-w-[400px] animate-fade-up", shake > 0 && "animate-shake")}>
            <div className="mb-8">
              <div className="mb-5 inline-flex size-12 items-center justify-center rounded-xl border border-border bg-surface shadow-sm">
                <ShieldCheck size={22} className="text-accent" />
              </div>
              <h1 className="text-3xl font-semibold tracking-tight">Welcome back</h1>
              <p className="mt-2 text-fg-muted">Sign in to manage jobs, production and your team.</p>
            </div>

            <form onSubmit={submit} className="space-y-5" noValidate>
              <LabeledInput label="Email address" htmlFor="email">
                <Mail size={17} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-fg-faint" />
                <input
                  id="email"
                  type="email"
                  autoComplete="username"
                  autoFocus
                  required
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    setError(null);
                  }}
                  placeholder="you@company.com"
                  className={inputClass(!!error)}
                />
              </LabeledInput>

              <LabeledInput
                label="Password"
                htmlFor="password"
                aside={
                  <button type="button" onClick={() => setForgot(true)} className="text-xs font-semibold text-accent hover:underline">
                    Forgot password?
                  </button>
                }
              >
                <Lock size={17} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-fg-faint" />
                <input
                  id="password"
                  type={show ? "text" : "password"}
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setError(null);
                  }}
                  onKeyUp={onPasswordKey}
                  onKeyDown={onPasswordKey}
                  placeholder="Enter your password"
                  className={cn(inputClass(!!error), "pr-11")}
                />
                <button
                  type="button"
                  aria-label={show ? "Hide password" : "Show password"}
                  onClick={() => setShow((v) => !v)}
                  className="absolute top-1/2 right-2 inline-flex size-8 -translate-y-1/2 items-center justify-center rounded-md text-fg-faint transition hover:bg-surface-high hover:text-fg"
                >
                  {show ? <EyeOff size={17} /> : <Eye size={17} />}
                </button>
              </LabeledInput>
              {caps && (
                <p className="-mt-3 flex items-center gap-1.5 text-xs font-medium text-warning">
                  <CircleAlert size={13} /> Caps Lock is on
                </p>
              )}

              <label className="flex cursor-pointer items-center gap-2.5 text-sm text-fg-muted select-none">
                <input
                  type="checkbox"
                  checked={remember}
                  onChange={(e) => setRemember(e.target.checked)}
                  className="size-4 rounded border-border-strong accent-[var(--accent)]"
                />
                Keep me signed in for 7 days
              </label>

              {error && (
                <div role="alert" className="flex items-start gap-2.5 rounded-lg border border-danger/30 bg-danger-soft px-3.5 py-3 text-sm text-danger">
                  <CircleAlert size={17} className="mt-px shrink-0" />
                  <span>{error}</span>
                </div>
              )}

              <Button type="submit" className="h-11 w-full text-[15px]" disabled={!hydrated || busy}>
                {busy ? (
                  <>
                    <Loader2 size={17} className="animate-spin" /> Signing in…
                  </>
                ) : (
                  <>
                    Sign in <ArrowRight size={17} />
                  </>
                )}
              </Button>
            </form>

            <div className="my-7 flex items-center gap-3 text-xs text-fg-faint">
              <span className="h-px flex-1 bg-border" />
              OR
              <span className="h-px flex-1 bg-border" />
            </div>

            <button
              type="button"
              onClick={useDemo}
              disabled={!hydrated || busy}
              className="group flex w-full items-center gap-3 rounded-xl border border-dashed border-border-strong bg-surface px-4 py-3 text-left transition hover:border-accent hover:bg-accent-soft/40 disabled:opacity-50"
            >
              <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-high font-mono text-xs font-bold text-fg-muted">
                DA
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-semibold">Continue with demo account</span>
                <span className="block truncate font-mono text-xs text-fg-faint">
                  {DEMO_LOGIN.email} · {DEMO_LOGIN.password}
                </span>
              </span>
              <ArrowRight size={16} className="text-fg-faint transition group-hover:translate-x-0.5 group-hover:text-accent" />
            </button>

            <p className="mt-8 text-center text-xs leading-relaxed text-fg-faint">
              Only Admin and Manufacturing Engineer accounts can sign in.
              <br />
              Access is logged per user.
            </p>
          </div>
        </main>

        <footer className="flex flex-wrap items-center justify-between gap-2 border-t border-border px-6 py-4 text-xs text-fg-faint sm:px-10">
          <span>© {new Date().getFullYear()} AuraForge India</span>
          <span className="inline-flex items-center gap-1.5">
            <ShieldCheck size={13} /> Secure admin access
          </span>
        </footer>
      </div>

      <Modal
        open={forgot}
        onClose={() => setForgot(false)}
        title="Reset your password"
        size="sm"
        footer={<Button onClick={() => setForgot(false)}>Got it</Button>}
      >
        <p className="text-sm leading-relaxed text-fg-muted">
          Passwords are managed by your administrator in <span className="font-semibold text-fg">Users &amp; Roles</span>.
          Ask an admin to reset yours — or use the demo account to explore the panel.
        </p>
      </Modal>
    </div>
  );
}

function inputClass(invalid: boolean) {
  return cn(
    "h-12 w-full rounded-xl border bg-surface pl-11 pr-4 text-[15px] text-fg outline-none transition placeholder:text-fg-faint",
    "focus:ring-4",
    invalid
      ? "border-danger/60 focus:border-danger focus:ring-danger/15"
      : "border-border hover:border-border-strong focus:border-accent focus:ring-accent/15",
  );
}

function LabeledInput({
  label,
  htmlFor,
  aside,
  children,
}: {
  label: string;
  htmlFor: string;
  aside?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <label htmlFor={htmlFor} className="text-sm font-semibold">
          {label}
        </label>
        {aside}
      </div>
      <div className="relative">{children}</div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Brand panel (always dark, like the app's splash)

function BrandPanel({ hydrated }: { hydrated: boolean }) {
  const jobs = useStore((s) => s.jobs);
  setCurrency(useStore((s) => s.settings.currency));
  const stats = useMemo(() => {
    const active = jobs.filter((j) => j.stage !== "delivered");
    return {
      active: active.length,
      atRisk: active.filter((j) => j.atRisk || daysUntil(j.dueDate) < 0).length,
      value: active.reduce((sum, j) => sum + j.value, 0),
    };
  }, [jobs]);
  const featured = jobs.find((j) => j.id === "DH-1048") ?? jobs[0];
  const done = featured ? stageIndex(featured.stage) : 0;

  return (
    <aside className="relative hidden w-[46%] max-w-[720px] flex-col overflow-hidden bg-[#041329] text-white lg:flex">
      {/* grid + glows */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.06]"
        style={{
          backgroundImage: `linear-gradient(${GOLD} 1px, transparent 1px), linear-gradient(90deg, ${GOLD} 1px, transparent 1px)`,
          backgroundSize: "32px 32px",
        }}
      />
      <div className="pointer-events-none absolute -top-40 -right-40 size-[520px] rounded-full bg-[#f2ca50]/15 blur-[120px]" />
      <div className="pointer-events-none absolute -bottom-48 -left-32 size-[480px] rounded-full bg-[#4648d4]/25 blur-[120px]" />

      <div className="relative flex flex-1 flex-col px-12 py-10 xl:px-16">
        <div className="flex items-center gap-3">
          <Image src="/images/logo.png" alt="DhanaOS" width={40} height={40} className="rounded-lg ring-1 ring-white/10" />
          <span className="text-xl font-semibold tracking-tight">DhanaOS</span>
          <span className="rounded border border-[#f2ca50]/40 px-1.5 py-0.5 font-mono text-[10px] font-bold tracking-widest text-[#f2ca50]">
            ADMIN
          </span>
        </div>

        <div className="my-auto py-12">
          <div className="font-mono text-xs font-bold tracking-[0.3em] text-[#f2ca50]">JEWELRY PRODUCTION OS</div>
          <h2 className="mt-5 max-w-lg text-[44px] leading-[1.08] font-semibold tracking-tight">
            Every job, from inquiry to delivery.
          </h2>
          <p className="mt-5 max-w-md text-[15px] leading-relaxed text-white/60">
            The control room for the DhanaOS app — production floor, the 14-stage process, partners, inventory and people.
          </p>

          {/* Live preview card */}
          {featured && (
            <div className="mt-10 max-w-md rounded-2xl border border-white/10 bg-white/[0.04] p-5 shadow-2xl backdrop-blur-md">
              <div className="flex items-center justify-between">
                <span className="font-mono text-xs text-white/50">{featured.id}</span>
                <span className="inline-flex items-center gap-1.5 rounded-full bg-[#f2ca50]/15 px-2.5 py-1 font-mono text-[10px] font-bold tracking-wider text-[#f2ca50]">
                  <span className="size-1.5 animate-pulse rounded-full bg-[#f2ca50]" />
                  {STAGES[done].label.toUpperCase()}
                </span>
              </div>
              <div className="mt-2 text-lg font-semibold">{featured.title}</div>
              <div className="text-sm text-white/50">{featured.customer}</div>
              <div className="mt-4 flex gap-1">
                {STAGES.map((s) => (
                  <span
                    key={s.key}
                    title={s.label}
                    className="h-1.5 flex-1 rounded-full"
                    style={{
                      background: s.index < done ? GOLD : s.index === done ? `${GOLD}99` : "rgb(255 255 255 / 0.12)",
                    }}
                  />
                ))}
              </div>
              <div className="mt-2 flex justify-between font-mono text-[10px] tracking-wider text-white/40">
                <span>INQUIRY</span>
                <span>
                  STAGE {done + 1}/{STAGES.length}
                </span>
                <span>DELIVERED</span>
              </div>
              <div className="mt-5 grid grid-cols-3 divide-x divide-white/10 border-t border-white/10 pt-4">
                <Stat label="Active" value={hydrated ? String(stats.active) : "—"} />
                <Stat label="At risk" value={hydrated ? String(stats.atRisk) : "—"} warn />
                <Stat label="In production" value={hydrated ? compactMoney(stats.value) : "—"} />
              </div>
            </div>
          )}

          <ul className="mt-10 grid max-w-md gap-4 text-sm text-white/70">
            <Feature icon={<Workflow size={16} />} text="Live production floor with drag-and-drop stages" />
            <Feature icon={<History size={16} />} text="Stage-by-stage record: who, when and what happened" />
            <Feature icon={<Boxes size={16} />} text="Partners, inventory, users and roles in one place" />
          </ul>
        </div>

        <div className="font-mono text-[11px] tracking-wider text-white/35">AURAFORGE INDIA · MUMBAI</div>
      </div>
    </aside>
  );
}

function Stat({ label, value, warn }: { label: string; value: string; warn?: boolean }) {
  return (
    <div className="px-3 first:pl-0 last:pr-0">
      <div className={cn("font-mono text-xl font-semibold", warn && value !== "0" ? "text-[#ffb4ab]" : "text-white")}>{value}</div>
      <div className="mt-0.5 text-[11px] text-white/45">{label}</div>
    </div>
  );
}

function Feature({ icon, text }: { icon: ReactNode; text: string }) {
  return (
    <li className="flex items-center gap-3">
      <span className="inline-flex size-8 shrink-0 items-center justify-center rounded-lg border border-white/10 bg-white/5 text-[#f2ca50]">
        {icon}
      </span>
      {text}
    </li>
  );
}

/** $65.9k style for the preview card. */
function compactMoney(v: number) {
  const m = money(0).replace(/0$/, "");
  if (v >= 1_000_000) return `${m}${(v / 1_000_000).toFixed(1)}M`;
  if (v >= 1_000) return `${m}${(v / 1_000).toFixed(1)}k`;
  return money(v);
}
