"use client";

import { Eye, EyeOff, Lock, Mail } from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";

import { Button, Field, Input } from "@/components/ui";
import { DEMO_LOGIN } from "@/lib/seed";
import { useHydrated, useStore } from "@/lib/store";

export function LoginView() {
  const hydrated = useHydrated();
  const session = useStore((s) => s.session);
  const login = useStore((s) => s.login);
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (hydrated && session) router.replace("/");
  }, [hydrated, session, router]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const err = login(email, password);
    if (err) setError(err);
    else router.replace("/");
  };

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      {/* Brand panel */}
      <div className="relative hidden flex-col justify-between overflow-hidden bg-[#041329] p-12 text-white lg:flex">
        <div
          className="pointer-events-none absolute inset-0 opacity-[0.07]"
          style={{
            backgroundImage:
              "linear-gradient(#f2ca50 1px, transparent 1px), linear-gradient(90deg, #f2ca50 1px, transparent 1px)",
            backgroundSize: "24px 24px",
          }}
        />
        <div className="relative flex items-center gap-3">
          <Image src="/images/logo.png" alt="" width={40} height={40} className="rounded-lg" />
          <span className="text-xl font-semibold">DhanaOS</span>
        </div>
        <div className="relative">
          <div className="font-mono text-xs tracking-[0.3em] text-[#f2ca50]">JEWELRY PRODUCTION OS</div>
          <h1 className="mt-4 max-w-md text-4xl leading-tight font-semibold">
            Manage every job from inquiry to delivery.
          </h1>
          <p className="mt-4 max-w-md text-white/60">
            Jobs, the 14-stage production process, partners, inventory and users — the control room for the DhanaOS app.
          </p>
        </div>
        <div className="relative font-mono text-xs text-white/40">AuraForge India · Admin</div>
      </div>

      {/* Form */}
      <div className="flex items-center justify-center p-6">
        <form onSubmit={submit} className="w-full max-w-sm">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <Image src="/images/logo.png" alt="" width={36} height={36} className="rounded-lg" />
            <span className="text-lg font-semibold">DhanaOS</span>
          </div>
          <h2 className="text-2xl font-semibold tracking-tight">Sign in to Admin</h2>
          <p className="mt-1 text-sm text-fg-muted">Use an Admin or Manufacturing Engineer account.</p>

          <div className="mt-8 space-y-4">
            <Field label="Email">
              <div className="relative">
                <Mail size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
                <Input
                  type="email"
                  autoComplete="username"
                  required
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    setError(null);
                  }}
                  placeholder="you@company.com"
                  className="pl-9"
                />
              </div>
            </Field>
            <Field label="Password">
              <div className="relative">
                <Lock size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
                <Input
                  type={show ? "text" : "password"}
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setError(null);
                  }}
                  placeholder="••••••••"
                  className="pr-10 pl-9"
                />
                <button
                  type="button"
                  aria-label={show ? "Hide password" : "Show password"}
                  onClick={() => setShow((v) => !v)}
                  className="absolute top-1/2 right-3 -translate-y-1/2 text-fg-faint hover:text-fg"
                >
                  {show ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </Field>
            {error && <p className="rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger">{error}</p>}
            <Button type="submit" className="w-full" disabled={!hydrated}>
              Sign in
            </Button>
          </div>

          <div className="mt-8 rounded-xl border border-dashed border-border-strong bg-surface-low p-4 text-sm">
            <div className="label-caps">Demo account</div>
            <div className="mt-2 font-mono text-xs">
              {DEMO_LOGIN.email}
              <br />
              {DEMO_LOGIN.password}
            </div>
            <button
              type="button"
              onClick={() => {
                setEmail(DEMO_LOGIN.email);
                setPassword(DEMO_LOGIN.password);
                setError(null);
              }}
              className="mt-2 text-xs font-semibold text-accent hover:underline"
            >
              Fill demo credentials
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
