"use client";

import { ArrowRight, CircleAlert, Eye, EyeOff, Loader2 } from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent, type KeyboardEvent, type ReactNode } from "react";

import { Button, cn, Modal } from "@/components/ui";
import { DEMO_LOGIN } from "@/lib/seed";
import { hasSessionCookie, useHydrated, useStore } from "@/lib/store";

/** Production stages shown in the login hero (HD photos in /images/hero). */
const SLIDES = [
  { stage: 2, name: "CAD Design", line: "Every piece starts as a precise 3D model.", img: "cad_blueprint.jpg" },
  { stage: 6, name: "Wax / 3D Print", line: "Approved designs printed in castable wax.", img: "wax_model_blue.jpg" },
  { stage: 9, name: "Stone Setting", line: "Center and accent stones, set and secured.", img: "ring_diamond_prongs.jpg" },
  { stage: 11, name: "Quality Control", line: "Inspected against the approved CAD.", img: "ring_solitaire_dark.jpg" },
  { stage: 12, name: "Certification", line: "Graded and logged by the gem lab.", img: "gem_diamond.jpg" },
];
const SLIDE_MS = 5500;

export function LoginView() {
  const hydrated = useHydrated();
  const session = useStore((s) => s.session);
  const login = useStore((s) => s.login);
  const logout = useStore((s) => s.logout);
  const theme = useStore((s) => s.settings.theme);
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

  const signIn = (e = email, p = password) => {
    setBusy(true);
    setError(null);
    // Short pause so the loading state reads; the check itself is instant.
    setTimeout(() => {
      const err = login(e, p, remember);
      if (err) {
        setError(err);
        setShake((n) => n + 1);
        setBusy(false);
      } else {
        router.replace("/");
      }
    }, 400);
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

  const onKey = (ev: KeyboardEvent<HTMLInputElement>) => setCaps(ev.getModifierState("CapsLock"));

  return (
    <div className="flex min-h-screen flex-col bg-bg lg:flex-row">
      <Hero />

      <div className="flex flex-1 flex-col">
        <main className="flex flex-1 items-center justify-center px-6 py-10 sm:px-12">
          <div key={shake} className={cn("w-full max-w-[380px] animate-fade-up", shake > 0 && "animate-shake")}>
            <h1 className="text-[28px] leading-tight font-semibold tracking-tight">Welcome back</h1>
            <p className="mt-2 text-fg-muted">Sign in to the DhanaOS admin console.</p>

            <form onSubmit={submit} className="mt-9 space-y-5" noValidate>
              <FieldRow label="Email" htmlFor="email">
                <input
                  id="email"
                  type="email"
                  autoComplete="username"
                  autoFocus
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    setError(null);
                  }}
                  placeholder="you@company.com"
                  className={inputClass(!!error)}
                />
              </FieldRow>

              <FieldRow label="Password" htmlFor="password">
                <div className="relative">
                  <input
                    id="password"
                    type={show ? "text" : "password"}
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => {
                      setPassword(e.target.value);
                      setError(null);
                    }}
                    onKeyDown={onKey}
                    onKeyUp={onKey}
                    placeholder="••••••••"
                    className={cn(inputClass(!!error), "pr-11")}
                  />
                  <button
                    type="button"
                    aria-label={show ? "Hide password" : "Show password"}
                    onClick={() => setShow((v) => !v)}
                    className="absolute top-1/2 right-1.5 inline-flex size-8 -translate-y-1/2 items-center justify-center rounded-md text-fg-faint transition hover:text-fg"
                  >
                    {show ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {caps && <p className="mt-1.5 text-xs font-medium text-warning">Caps Lock is on</p>}
              </FieldRow>

              <div className="flex items-center justify-between text-sm">
                <label className="flex cursor-pointer items-center gap-2 text-fg-muted select-none">
                  <input
                    type="checkbox"
                    checked={remember}
                    onChange={(e) => setRemember(e.target.checked)}
                    className="size-4 rounded border-border-strong accent-[var(--action)]"
                  />
                  Remember me
                </label>
                <button type="button" onClick={() => setForgot(true)} className="font-medium text-fg hover:underline">
                  Forgot password?
                </button>
              </div>

              {error && (
                <p role="alert" className="flex items-center gap-2 text-sm text-danger">
                  <CircleAlert size={15} className="shrink-0" />
                  {error}
                </p>
              )}

              <Button type="submit" className="group h-12 w-full text-[15px]" disabled={!hydrated || busy}>
                {busy ? (
                  <>
                    <Loader2 size={17} className="animate-spin" /> Signing in…
                  </>
                ) : (
                  <>
                    Sign in
                    <ArrowRight size={17} className="transition group-hover:translate-x-0.5" />
                  </>
                )}
              </Button>
            </form>

            <div className="mt-8 border-t border-border pt-6 text-sm text-fg-muted">
              Just exploring?{" "}
              <button
                type="button"
                onClick={useDemo}
                disabled={!hydrated || busy}
                className="font-semibold text-fg underline decoration-border-strong underline-offset-4 transition hover:decoration-fg disabled:opacity-50"
              >
                Use the demo account
              </button>
            </div>
          </div>
        </main>

        <footer className="flex items-center justify-between px-6 py-5 text-xs text-fg-faint sm:px-12">
          <span>© {new Date().getFullYear()} AuraForge India</span>
          <span>DhanaOS Admin</span>
        </footer>
      </div>

      <Modal
        open={forgot}
        onClose={() => setForgot(false)}
        title="Forgot your password?"
        size="sm"
        footer={<Button onClick={() => setForgot(false)}>Got it</Button>}
      >
        <p className="text-sm leading-relaxed text-fg-muted">
          Ask an administrator to reset it from <span className="font-semibold text-fg">Users &amp; Roles</span>. To look
          around, use the demo account ({DEMO_LOGIN.email} / {DEMO_LOGIN.password}).
        </p>
      </Modal>
    </div>
  );
}

/** Full-bleed photo slideshow of production stages (a short band on mobile). */
function Hero() {
  const [i, setI] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => setI((n) => (n + 1) % SLIDES.length), SLIDE_MS);
    return () => clearTimeout(t);
  }, [i]);

  const slide = SLIDES[i];
  return (
    <section className="relative h-64 shrink-0 overflow-hidden bg-[#041329] text-white sm:h-80 lg:h-auto lg:min-h-screen lg:w-[55%]">
      {SLIDES.map((s, n) => (
        <div
          key={s.img}
          aria-hidden={n !== i}
          className={cn("absolute inset-0 transition-opacity duration-[1400ms] ease-out", n === i ? "opacity-100" : "opacity-0")}
        >
          <Image
            // Restart the slow zoom each time this slide becomes active.
            key={n === i ? `on-${i}` : "off"}
            src={`/images/hero/${s.img}`}
            alt={n === i ? `${s.name} stage` : ""}
            fill
            priority={n === 0}
            sizes="(min-width: 1024px) 55vw, 100vw"
            className={cn("object-cover", n === i && "motion-safe:animate-kenburns")}
          />
        </div>
      ))}

      {/* Legibility gradients */}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-2/3 bg-gradient-to-t from-[#020a17]/95 via-[#020a17]/50 to-transparent" />
      <div className="pointer-events-none absolute inset-x-0 top-0 h-40 bg-gradient-to-b from-[#020a17]/60 to-transparent" />

      <div className="relative flex h-full flex-col justify-between p-6 sm:p-10 lg:p-14">
        <div className="flex items-center gap-3">
          <Image src="/images/logo.png" alt="" width={36} height={36} className="rounded-lg ring-1 ring-white/15" />
          <span className="text-lg font-semibold tracking-tight">DhanaOS</span>
        </div>

        <div>
          <div key={i} className="animate-fade-up">
            <div className="font-mono text-[11px] font-bold tracking-[0.25em] text-[#f2ca50]">
              STAGE {String(slide.stage).padStart(2, "0")} / 14
            </div>
            <div className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl lg:text-5xl">{slide.name}</div>
            <p className="mt-2 hidden max-w-md text-white/70 sm:block lg:text-lg">{slide.line}</p>
          </div>

          <div className="mt-6 flex max-w-md gap-2 lg:mt-10">
            {SLIDES.map((s, n) => (
              <button
                key={s.img}
                type="button"
                aria-label={`Show ${s.name}`}
                onClick={() => setI(n)}
                className="group h-5 flex-1"
              >
                <span className="block h-[3px] overflow-hidden rounded-full bg-white/20 transition group-hover:bg-white/35">
                  <span
                    key={n === i ? `bar-${i}` : n}
                    className={cn("block h-full rounded-full bg-[#f2ca50]", n < i && "w-full", n > i && "w-0", n === i && "animate-grow")}
                  />
                </span>
              </button>
            ))}
          </div>
          <p className="mt-4 hidden text-sm text-white/45 lg:block">From inquiry to delivery — every job, every stage.</p>
        </div>
      </div>
    </section>
  );
}

function inputClass(invalid: boolean) {
  return cn(
    "h-12 w-full rounded-lg border bg-surface px-3.5 text-[15px] text-fg outline-none transition placeholder:text-fg-faint",
    "focus:ring-4",
    invalid
      ? "border-danger/70 focus:border-danger focus:ring-danger/15"
      : "border-border-strong/70 hover:border-border-strong focus:border-fg focus:ring-fg/10",
  );
}

function FieldRow({ label, htmlFor, children }: { label: string; htmlFor: string; children: ReactNode }) {
  return (
    <div>
      <label htmlFor={htmlFor} className="mb-1.5 block text-sm font-medium">
        {label}
      </label>
      {children}
    </div>
  );
}
