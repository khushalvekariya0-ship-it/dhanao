"use client";

import {
  Bell,
  Boxes,
  Briefcase,
  FolderOpen,
  LayoutDashboard,
  LogOut,
  Menu,
  Moon,
  Network,
  Search,
  Settings,
  Sun,
  UserCog,
  Workflow,
  X,
} from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import { ago, setCurrency } from "@/lib/format";
import { useHydrated, useStore } from "@/lib/store";
import { Avatar, cn, IconButton } from "./ui";
import { ToastProvider } from "./toast";

export const NAV = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/production", label: "Production", icon: Workflow },
  { href: "/jobs", label: "Jobs", icon: Briefcase },
  { href: "/partners", label: "Partners", icon: Network },
  { href: "/inventory", label: "Inventory", icon: Boxes },
  { href: "/files", label: "Files", icon: FolderOpen },
  { href: "/users", label: "Users & Roles", icon: UserCog },
  { href: "/settings", label: "Settings", icon: Settings },
];

const isActive = (path: string, href: string) => (href === "/" ? path === "/" : path === href || path.startsWith(`${href}/`));

/** Sidebar + top bar frame for every admin page. Redirects to /login without a session. */
export function AdminShell({ children }: { children: ReactNode }) {
  const hydrated = useHydrated();
  const session = useStore((s) => s.session);
  const theme = useStore((s) => s.settings.theme);
  const currency = useStore((s) => s.settings.currency);
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  setCurrency(currency);

  useEffect(() => {
    if (hydrated && !session) {
      // Clear a stale cookie first, otherwise the proxy would bounce /login back here.
      useStore.getState().logout();
      router.replace("/login");
    }
  }, [hydrated, session, router]);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
  }, [theme]);

  if (!hydrated || !session) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="size-8 animate-spin rounded-full border-2 border-border-strong border-t-accent" />
      </div>
    );
  }

  return (
    <ToastProvider>
      <div className="min-h-screen lg:pl-64">
        <Sidebar open={menuOpen} onClose={() => setMenuOpen(false)} />
        <TopBar onMenu={() => setMenuOpen(true)} />
        {/* Keyed by currency so every page re-renders its amounts when it changes. */}
        <main key={currency} className="mx-auto max-w-[1440px] px-4 py-6 sm:px-6 lg:px-10 lg:py-8">
          {children}
        </main>
      </div>
    </ToastProvider>
  );
}

function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const path = usePathname();
  const session = useStore((s) => s.session)!;
  const logout = useStore((s) => s.logout);
  const router = useRouter();
  return (
    <>
      {open && <div className="fixed inset-0 z-40 bg-black/40 lg:hidden" onClick={onClose} />}
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-border bg-surface-low transition-transform lg:translate-x-0",
          open ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="flex items-center gap-3 px-6 py-5">
          <Image src="/images/logo.png" alt="DhanaOS" width={32} height={32} className="rounded-md" />
          <div className="min-w-0 flex-1">
            <div className="text-lg font-semibold tracking-tight">DhanaOS</div>
            <div className="font-mono text-[10px] tracking-widest text-fg-faint">ADMIN PANEL</div>
          </div>
          <IconButton label="Close menu" className="lg:hidden" onClick={onClose}>
            <X size={18} />
          </IconButton>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3">
          {NAV.map(({ href, label, icon: Icon }) => {
            const active = isActive(path, href);
            return (
              <Link
                key={href}
                href={href}
                onClick={onClose}
                className={cn(
                  "flex items-center gap-3 rounded-xl px-4 py-2.5 text-sm font-semibold transition",
                  active ? "bg-nav-active text-on-nav-active" : "text-fg-muted hover:bg-surface-high hover:text-fg",
                )}
              >
                <Icon size={19} />
                {label}
              </Link>
            );
          })}
        </nav>
        <div className="m-3 flex items-center gap-3 rounded-xl border border-border bg-surface p-3">
          <Avatar name={session.name} src={session.name === "Ravi S." ? "avatar_ravi.jpg" : null} size={36} dark />
          <div className="min-w-0 flex-1">
            <div className="truncate text-sm font-semibold">{session.name}</div>
            <div className="truncate text-xs text-fg-muted">{session.role}</div>
          </div>
          <IconButton
            label="Log out"
            onClick={() => {
              logout();
              router.replace("/login");
            }}
          >
            <LogOut size={17} />
          </IconButton>
        </div>
      </aside>
    </>
  );
}

function TopBar({ onMenu }: { onMenu: () => void }) {
  const router = useRouter();
  const jobs = useStore((s) => s.jobs);
  const actions = useStore((s) => s.actions);
  const activity = useStore((s) => s.activity);
  const theme = useStore((s) => s.settings.theme);
  const updateSettings = useStore((s) => s.updateSettings);
  const [q, setQ] = useState("");
  const [focus, setFocus] = useState(false);
  const [bell, setBell] = useState(false);

  const results = useMemo(() => {
    const t = q.trim().toLowerCase();
    if (!t) return [];
    return jobs
      .filter((j) => [j.id, j.title, j.customer, j.assignee ?? ""].some((v) => v.toLowerCase().includes(t)))
      .slice(0, 8);
  }, [q, jobs]);

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-border bg-bg/85 px-4 backdrop-blur-xl sm:px-6 lg:px-10">
      <IconButton label="Open menu" className="lg:hidden" onClick={onMenu}>
        <Menu size={20} />
      </IconButton>
      <div className="relative max-w-md flex-1">
        <Search size={17} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onFocus={() => setFocus(true)}
          onBlur={() => setTimeout(() => setFocus(false), 150)}
          placeholder="Job ID, customer, or specialist"
          className="h-10 w-full rounded-full border border-border bg-surface-low pr-4 pl-9 text-sm outline-none focus:border-accent"
        />
        {focus && q && (
          <div className="absolute top-12 left-0 w-full overflow-hidden rounded-xl border border-border bg-surface shadow-xl">
            {results.length === 0 && <div className="px-4 py-3 text-sm text-fg-muted">No jobs match “{q}”.</div>}
            {results.map((j) => (
              <button
                key={j.id}
                type="button"
                onMouseDown={() => {
                  router.push(`/jobs/${j.id}`);
                  setQ("");
                }}
                className="flex w-full items-center gap-3 px-4 py-2.5 text-left hover:bg-surface-low"
              >
                <span className="font-mono text-xs text-fg-muted">{j.id}</span>
                <span className="min-w-0 flex-1 truncate text-sm">{j.title}</span>
                <span className="truncate text-xs text-fg-faint">{j.customer}</span>
              </button>
            ))}
          </div>
        )}
      </div>
      <div className="ml-auto flex items-center gap-1">
        <IconButton
          label={theme === "dark" ? "Light mode" : "Dark mode"}
          onClick={() => updateSettings({ theme: theme === "dark" ? "light" : "dark" })}
        >
          {theme === "dark" ? <Sun size={19} /> : <Moon size={19} />}
        </IconButton>
        <div className="relative">
          <IconButton label="Notifications" onClick={() => setBell((v) => !v)}>
            <Bell size={19} />
            {actions.length > 0 && <span className="absolute top-1.5 right-1.5 size-2 rounded-full bg-danger" />}
          </IconButton>
          {bell && (
            <>
              <div className="fixed inset-0 z-30" onClick={() => setBell(false)} />
              <div className="absolute top-11 right-0 z-40 w-80 overflow-hidden rounded-xl border border-border bg-surface shadow-xl">
                <div className="flex items-center justify-between border-b border-border px-4 py-3">
                  <span className="font-semibold">Notifications</span>
                  <IconButton label="Close" onClick={() => setBell(false)}>
                    <X size={16} />
                  </IconButton>
                </div>
                <div className="max-h-96 overflow-y-auto">
                  <div className="label-caps px-4 pt-3">Needs action</div>
                  {actions.map((a) => (
                    <Link
                      key={a.id}
                      href={`/jobs/${a.jobId}`}
                      onClick={() => setBell(false)}
                      className="block px-4 py-2.5 hover:bg-surface-low"
                    >
                      <div className="text-sm font-semibold">{a.title}</div>
                      <div className="text-xs text-fg-muted">{a.subtitle}</div>
                    </Link>
                  ))}
                  <div className="label-caps px-4 pt-3">Recent activity</div>
                  {activity.slice(0, 6).map((a) => (
                    <Link
                      key={a.id}
                      href={`/jobs/${a.jobId}`}
                      onClick={() => setBell(false)}
                      className="block px-4 py-2.5 hover:bg-surface-low"
                    >
                      <div className="text-sm">
                        {a.text} <span className="font-mono text-accent">{a.jobId}</span>
                      </div>
                      <div className="text-xs text-fg-faint">
                        {ago(a.time)} · {a.by}
                      </div>
                    </Link>
                  ))}
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
