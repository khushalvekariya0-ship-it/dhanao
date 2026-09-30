"use client";

import { CircleAlert, Eye, EyeOff, Loader2 } from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent, type KeyboardEvent, type ReactNode } from "react";

import { Button, cn, Modal } from "@/components/ui";
import { DEMO_LOGIN } from "@/lib/seed";
import { hasSessionCookie, useHydrated, useStore } from "@/lib/store";

/** Minimal centred sign-in card. */
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
    <div className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-bg px-5 py-12">
      {/* Fine dot grid that fades out towards the edges */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-70"
        style={{
          backgroundImage: "radial-gradient(var(--border-strong) 1px, transparent 1px)",
          backgroundSize: "22px 22px",
          maskImage: "radial-gradient(ellipse 60% 55% at 50% 45%, black 20%, transparent 75%)",
          WebkitMaskImage: "radial-gradient(ellipse 60% 55% at 50% 45%, black 20%, transparent 75%)",
        }}
      />

      <div className="relative w-full max-w-[400px] animate-fade-up">
        <div className="mb-8 flex flex-col items-center text-center">
          <Image
            src="/images/logo.png"
            alt="DhanaOS"
            width={48}
            height={48}
            priority
            className="rounded-xl shadow-sm ring-1 ring-border"
          />
          <h1 className="mt-6 text-2xl font-semibold tracking-tight">Sign in to DhanaOS</h1>
          <p className="mt-1.5 text-sm text-fg-muted">Welcome back. Enter your details to continue.</p>
        </div>

        <div
          key={shake}
          className={cn(
            "rounded-2xl border border-border bg-surface p-7 shadow-[0_1px_2px_rgb(15_23_42/0.04),0_12px_40px_-12px_rgb(15_23_42/0.16)] sm:p-8",
            shake > 0 && "animate-shake",
          )}
        >
          <form onSubmit={submit} className="space-y-5" noValidate>
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

            <Button type="submit" className="h-11 w-full text-[15px]" disabled={!hydrated || busy}>
              {busy ? (
                <>
                  <Loader2 size={17} className="animate-spin" /> Signing in…
                </>
              ) : (
                "Sign in"
              )}
            </Button>
          </form>
        </div>

        <p className="mt-6 text-center text-sm text-fg-muted">
          Just exploring?{" "}
          <button
            type="button"
            onClick={useDemo}
            disabled={!hydrated || busy}
            className="font-semibold text-fg underline decoration-border-strong underline-offset-4 transition hover:decoration-fg disabled:opacity-50"
          >
            Use the demo account
          </button>
        </p>
      </div>

      <p className="absolute bottom-6 text-xs text-fg-faint">© {new Date().getFullYear()} AuraForge India · DhanaOS Admin</p>

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

function inputClass(invalid: boolean) {
  return cn(
    "h-11 w-full rounded-lg border bg-surface px-3.5 text-[15px] text-fg outline-none transition placeholder:text-fg-faint",
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
